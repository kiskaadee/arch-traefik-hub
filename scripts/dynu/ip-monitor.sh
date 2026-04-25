#!/bin/bash
# Dynu DDNS IP monitor and updater
#
# Purpose:
#   Detect current public IPv4 address and update Dynu DDNS record if it changed.
#
# Design:
#   - Two independent IP sources:
#       1. DNS (dig) → fast, preferred, optional
#       2. HTTP (curl) → reliable fallback, required
#   - Strict validation before any state mutation
#   - Atomic state updates
#   - Structured logging (journald-friendly)
#   - Concurrency control via flock
#
# Execution model:
#   systemd timer → service → this script
#
# Failure philosophy:
#   - Fail fast on misconfiguration
#   - Never persist invalid state
#   - Prefer fallback over retry loops
#   - Always log observable events

#!/bin/bash
set -euo pipefail

# --- invariants ---
: "${STATE_DIRECTORY:?must be run via systemd (StateDirectory missing)}"
: "${DYNU_HOST:?missing}"
: "${DYNU_USER:?missing}"
: "${DYNU_PASSWORD:?missing}"

STATE_DIR="$STATE_DIRECTORY"
LAST_IP_FILE="$STATE_DIR/last_ip"

DIG_CMD="$(command -v dig || true)"
CURL_CMD="$(command -v curl)" || { echo "curl not found"; exit 1; }

mkdir -p "$STATE_DIR"

# --- logging ---
log() {
    printf '%s dynu-monitor %s\n' "$(date -Iseconds)" "$*"
}

# --- concurrency control ---
exec 9>"$STATE_DIR/lock"
flock -n 9 || { log "event=skip reason=lock_held"; exit 0; }

# --- validation ---
is_valid_ipv4() {
    local ip=$1 a b c d
    [[ $ip =~ ^((0|[1-9][0-9]{0,2})\.){3}(0|[1-9][0-9]{0,2})$ ]] || return 1
    IFS='.' read -r a b c d <<< "$ip"
    (( 10#$a <= 255 && 10#$b <= 255 && 10#$c <= 255 && 10#$d <= 255 ))
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
        local ip err_file exit_code
        err_file=$(mktemp)

        if ip="$("$CURL_CMD" -s --fail --max-time 5 "$url" 2>"$err_file")"; then
            ip="$(echo "$ip" | head -n1 | tr -d '[:space:]')"
            log "event=attempt source=http url='$url' value='$ip'"

            rm -f "$err_file"

            if is_valid_ipv4 "$ip"; then
                echo "$ip"
                return 0
            fi
        else
            exit_code=$?
            local err
            err="$(head -c 120 "$err_file")"
            log "event=error source=http url='$url' exit_code=$exit_code err='${err:-none}'"
            rm -f "$err_file"
        fi
    done

    return 1
}

# --- discovery ---
RAW_IP=""
SOURCE="dns"

if [[ -n "$DIG_CMD" ]]; then
    DNS_ERR_FILE=$(mktemp)
    if ! RAW_IP="$(get_ip_from_dns 2>"$DNS_ERR_FILE")"; then
        DNS_EXIT=$?
        DNS_ERR="$(head -c 120 "$DNS_ERR_FILE")"
        log "event=error source=dns exit_code=$DNS_EXIT err='${DNS_ERR:-none}'"
        RAW_IP=""
    else
        log "event=attempt source=dns value='$RAW_IP'"
    fi
    rm -f "$DNS_ERR_FILE"
else
    log "event=skip source=dns reason=missing_dependency"
fi

if ! is_valid_ipv4 "$RAW_IP"; then
    log "event=fallback from=dns reason=invalid_or_missing_response value='$RAW_IP'"
    SOURCE="http"

    if ! RAW_IP="$(get_ip_from_http)"; then
        log "event=error source=http reason=all_providers_failed"
        RAW_IP=""
    fi
fi

# --- final validation ---
if ! is_valid_ipv4 "$RAW_IP"; then
    log "event=error reason=invalid_ip source=$SOURCE value='$RAW_IP'"
    exit 1
fi

CURRENT_IP="$RAW_IP"
log "event=discovered source=$SOURCE ip=$CURRENT_IP"

# --- state load ---
LAST_IP=""
if [[ -f "$LAST_IP_FILE" ]]; then
    LAST_IP="$(tr -d '[:space:]' < "$LAST_IP_FILE" || true)"
    if ! is_valid_ipv4 "$LAST_IP"; then
        log "event=warning reason=invalid_last_ip value='$LAST_IP'"
        LAST_IP=""
    fi
fi

# --- compare ---
if [[ "$CURRENT_IP" == "$LAST_IP" ]]; then
    log "event=no_change ip=$CURRENT_IP"
    exit 0
fi

log "event=change old_ip=${LAST_IP:-none} new_ip=$CURRENT_IP"

# --- update Dynu ---
RESP_FILE=$(mktemp)

HTTP_CODE="$(
  "$CURL_CMD" -s --max-time 5 \
  -w "%{http_code}" \
  -o "$RESP_FILE" \
  "https://api.dynu.com/nic/update?hostname=${DYNU_HOST}&username=${DYNU_USER}&password=${DYNU_PASSWORD}&myip=${CURRENT_IP}" \
  || echo "000"
)"

UPDATE_RESPONSE="$(head -c 200 "$RESP_FILE" 2>/dev/null || true)"
rm -f "$RESP_FILE"

log "event=update_response http_code=$HTTP_CODE response='$UPDATE_RESPONSE'"

if [[ "$HTTP_CODE" != "200" ]]; then
    log "event=error reason=http_failure code=$HTTP_CODE"
    exit 1
fi

if [[ "$UPDATE_RESPONSE" == good* || "$UPDATE_RESPONSE" == nochg* ]]; then
    TMP_FILE=$(mktemp -p "$STATE_DIR" last_ip.XXXXXX)

    printf '%s\n' "$CURRENT_IP" > "$TMP_FILE"
    sync -f "$TMP_FILE" 2>/dev/null || true
    mv "$TMP_FILE" "$LAST_IP_FILE"

    log "event=state_updated ip=$CURRENT_IP"
else
    log "event=update_failed response='$UPDATE_RESPONSE'"
    exit 1
fi