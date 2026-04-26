#!/bin/bash
# Dynu DDNS IP monitor and updater

# Design notes:
#   - Execution is periodic (systemd timer), not continuous: this is a probe, not a daemon
#   - Discovery and update are intentionally coupled to guarantee consistency:
#       we only persist state after a successful external sync
#   - Failure is classified:
#       * degraded → partial failure with fallback (DNS → HTTP, provider errors)
#       * error → no valid IP or API failure (no state mutation allowed)
#   - Logs are structured for journald filtering (event=, reason=, cause=)

set -euo pipefail

# --- invariants ---
: "${STATE_DIRECTORY:?must be run via systemd (StateDirectory missing)}"
: "${DYNU_HOST:?missing}"
: "${DYNU_USER:?missing}"
: "${DYNU_PASSWORD:?missing}"

STATE_DIR="$STATE_DIRECTORY"
LAST_IP_FILE="$STATE_DIR/last_ip"

# --- logging ---
# Logging strategy:
#   - Only log meaningful transitions:
#       * discovery
#       * degradation
#       * change
#       * failure
#   - Suppress noise (e.g., no_change)
#   - Structured logs for journald filtering
log() {
    printf '%s dynu-monitor %s\n' "$(date -Iseconds)" "$*"
}

# --- dependencies checks ---
# Hard dependency validation:
#   curl → required for all network operations
#   md5sum → required because Dynu rejects plain-text passwords in practice
# We fail early here to avoid partial execution later
CURL_CMD="$(command -v curl)" || {
    log "event=error reason=dependency_check cause=missing_tool tool=curl"
    exit 1
}

MD5_CMD="$(command -v md5sum)" || {
    log "event=error reason=dependency_check cause=missing_tool tool=md5sum"
    exit 1
}

# dig remains optional but tracked (used as fast-path provider)
DIG_CMD="$(command -v dig || true)"

# --- concurrency control ---
# Concurrency control:
#   Non-blocking lock ensures idempotent timer behavior.
#   If a previous run overlaps, we skip instead of queueing.
exec 9>"$STATE_DIR/lock"
flock -n 9 || {
    log "event=skip reason=concurrency_check cause=lock_held"
    exit 0
}

# --- validation ---
is_valid_ipv4() {
    local ip=$1
    [[ $ip =~ ^((0|[1-9][0-9]{0,2})\.){3}(0|[1-9][0-9]{0,2})$ ]] || return 1
    local IFS='.'
    read -r a b c d <<< "$ip"
    (( 10#$a <= 255 && 10#$b <= 255 && 10#$c <= 255 && 10#$d <= 255 ))
}

is_public_ipv4() {
    local ip=$1 a b
    local IFS='.'
    read -r a b _ <<< "$ip"

    # Reject RFC1918 + CGNAT ranges
    if (( a == 10 )) || \
       (( a == 192 && b == 168 )) || \
       (( a == 172 && b >= 16 && b <= 31 )) || \
       (( a == 100 && b >= 64 && b <= 127 )); then
        return 1
    fi

    return 0
}

# --- providers ---
get_ip_from_dns() {
    "$DIG_CMD" +short +time=2 +tries=1 myip.opendns.com @resolver1.opendns.com \
        | head -n1 | tr -d '[:space:]'
}

get_ip_from_http() {
    local providers=(
        "https://api.ipify.org"
        "https://ifconfig.me"
        "https://wtfismyip.com/text"
    )

    for url in "${providers[@]}"; do
        local ip err_file
        err_file=$(mktemp)

        if ip="$("$CURL_CMD" -s --fail --max-time 2 "$url" 2>"$err_file")"; then
            ip="$(head -n1 <<< "$ip" | tr -d '[:space:]')"
            rm -f "$err_file"

            # Provider validation tightened:
            #   Reject invalid or private IPs before accepting
            if is_valid_ipv4 "$ip" && is_public_ipv4 "$ip"; then
                echo "$ip"
                return 0
            else
                log "event=degraded reason=http_provider_rejected cause=invalid_or_private source=http url='$url' value='$ip'"
            fi
        else
            local exit_code=$? err
            err="$(head -c 120 "$err_file")"
            log "event=degraded reason=http_provider_failed source=http url='$url' exit_code=$exit_code err='${err:-none}'"
            rm -f "$err_file"
        fi
    done

    return 1
}

# --- discovery ---
RAW_IP=""
SOURCE="dns"
DNS_UNUSABLE=false

# DNS evaluation is explicit:
#   classify DNS as usable/unusable instead of implicit fallback
if [[ -z "$DIG_CMD" ]]; then
    log "event=degraded reason=dns_unavailable fallback=http"
    DNS_UNUSABLE=true
else
    DNS_ERR_FILE=$(mktemp)
    if ! RAW_IP="$(get_ip_from_dns 2>"$DNS_ERR_FILE")"; then
        DNS_EXIT=$?
        DNS_ERR="$(head -c 120 "$DNS_ERR_FILE")"
        log "event=degraded reason=dns_provider_failed fallback=http source=dns exit_code=$DNS_EXIT err='${DNS_ERR:-none}'"
        DNS_UNUSABLE=true
    fi
    rm -f "$DNS_ERR_FILE"
fi

# Validate DNS result before accepting
if [[ "$DNS_UNUSABLE" == "false" ]]; then
    if ! is_valid_ipv4 "$RAW_IP"; then
        log "event=degraded reason=dns_unusable fallback=http cause=invalid_format"
        DNS_UNUSABLE=true
    elif ! is_public_ipv4 "$RAW_IP"; then
        log "event=degraded reason=dns_unusable fallback=http cause=private_address"
        DNS_UNUSABLE=true
    fi
fi

# Fallback to HTTP providers if DNS is unusable
if [[ "$DNS_UNUSABLE" == "true" ]]; then
    SOURCE="http"
    if ! RAW_IP="$(get_ip_from_http)"; then
        log "event=error reason=all_providers_failed source=http"
        exit 1
    fi
fi

# --- final validation ---
# Final validation is repeated intentionally as a safety gate
if ! is_valid_ipv4 "$RAW_IP"; then
    log "event=error reason=validation_failed cause=invalid_format source=$SOURCE value='$RAW_IP'"
    exit 1
elif ! is_public_ipv4 "$RAW_IP"; then
    log "event=error reason=validation_failed cause=private_address source=$SOURCE value='$RAW_IP'"
    exit 1
fi

CURRENT_IP="$RAW_IP"
log "event=discovered source=$SOURCE ip=$CURRENT_IP"

# --- state load ---
# State invariant:
#   last_ip is only updated after successful external sync
LAST_IP=""
if [[ -f "$LAST_IP_FILE" ]]; then
    LAST_IP="$(tr -d '[:space:]' < "$LAST_IP_FILE" || true)"
    if ! is_valid_ipv4 "$LAST_IP"; then
        log "event=degraded reason=state_load_failed cause=invalid_format value='$LAST_IP'"
        LAST_IP=""
    fi
fi

# --- compare ---
if [[ "$CURRENT_IP" == "$LAST_IP" ]]; then
    exit 0
fi

log "event=change old_ip=${LAST_IP:-none} new_ip=$CURRENT_IP"

# --- credentials preparation ---
# Deferred hashing:
#   Only compute hash if an update is actually needed
if [[ "$DYNU_PASSWORD" =~ ^[a-fA-F0-9]{32}$ ]]; then
    DYNU_PASSWORD_HASH="$DYNU_PASSWORD"
else
    DYNU_PASSWORD_HASH="$(printf '%s' "$DYNU_PASSWORD" | "$MD5_CMD" | awk '{print $1}')"
fi

# --- update Dynu ---
RESP_FILE=$(mktemp)

HTTP_CODE="$(
  "$CURL_CMD" -s --max-time 2 \
  -w "%{http_code}" \
  -o "$RESP_FILE" \
  "https://api.dynu.com/nic/update?hostname=${DYNU_HOST}&username=${DYNU_USER}&password=${DYNU_PASSWORD_HASH}&myip=${CURRENT_IP}" \
  || echo "000"
)"

# Response normalization:
#   - strip CRLF
#   - normalize case
UPDATE_RESPONSE="$(head -c 200 "$RESP_FILE" 2>/dev/null | tr -d '\r\n' | tr '[:upper:]' '[:lower:]' || true)"
rm -f "$RESP_FILE"

# Transport layer validation
if [[ "$HTTP_CODE" != "200" ]]; then
    log "event=error reason=api_transport_failed cause=http_transport_error code=$HTTP_CODE response='$UPDATE_RESPONSE'"
    exit 1
fi

# Semantic layer validation
if [[ "$UPDATE_RESPONSE" == good* || "$UPDATE_RESPONSE" == nochg* ]]; then
    TMP_FILE=$(mktemp -p "$STATE_DIR" last_ip.XXXXXX)

    printf '%s\n' "$CURRENT_IP" > "$TMP_FILE"
    mv "$TMP_FILE" "$LAST_IP_FILE"

    log "event=state_updated ip=$CURRENT_IP"
else
    log "event=error reason=api_semantic_failed cause=invalid_response response='$UPDATE_RESPONSE'"
    exit 1
fi
