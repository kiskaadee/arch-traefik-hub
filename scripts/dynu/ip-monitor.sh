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

set -euo pipefail

# --- configuration ---
STATE_DIR="${STATE_DIRECTORY:-/var/lib/dynu}"
LAST_IP_FILE="$STATE_DIR/last_ip"

DIG_CMD=$(command -v dig || true)               # optional
CURL_CMD=$(command -v curl) || { echo "curl not found"; exit 1; }
MKDIR_CMD=$(command -v mkdir) || { echo "mkdir not found"; exit 1; }

"$MKDIR_CMD" -p "$STATE_DIR"

# --- environment validation (fail fast) ---
: "${DYNU_HOST:?missing}"
: "${DYNU_USER:?missing}"
: "${DYNU_PASSWORD:?missing}"

# --- logging ---
# Single-line structured logs for journald
log() {
    printf '%s dynu-monitor %s\n' "$(date -Iseconds)" "$*"
}

# --- concurrency control ---
# Prevent overlapping executions (e.g., slow runs or manual triggers)
exec 9>"$STATE_DIR/lock"
flock -n 9 || { log "event=skip reason=lock_held"; exit 0; }

# --- validation ---
# Strict IPv4 validation (format + numeric bounds)
is_valid_ipv4() {
    local ip=$1
    local a b c d

    [[ $ip =~ ^((0|[1-9][0-9]{0,2})\.){3}(0|[1-9][0-9]{0,2})$ ]] || return 1
    IFS='.' read -r a b c d <<< "$ip"
    (( 10#$a <= 255 && 10#$b <= 255 && 10#$c <= 255 && 10#$d <= 255 ))
}

# --- providers ---
# DNS-based IP discovery (fast, optional)
get_ip_from_dns() {
    "$DIG_CMD" +short +time=2 +tries=1 myip.opendns.com @resolver1.opendns.com \
        | head -n1 | tr -d '[:space:]'
}

# HTTP-based IP discovery (fallback, reliable)
get_ip_from_http() {
    "$CURL_CMD" -s --fail --max-time 5 https://ifconfig.me \
        | head -n1 | tr -d '[:space:]'
}

# --- discovery ---
RAW_IP=""
SOURCE="dns"

# Attempt DNS if available
if [[ -n "$DIG_CMD" ]]; then
    if RAW_IP="$(get_ip_from_dns 2>/dev/null)"; then
        log "event=attempt source=dns value='$RAW_IP'"
    else
        log "event=error source=dns reason=command_failed"
        RAW_IP=""
    fi
else
    log "event=skip source=dns reason=missing_dependency"
fi

# Fallback to HTTP if DNS result is invalid or missing
if ! is_valid_ipv4 "$RAW_IP"; then
    log "event=fallback from=dns reason=invalid_or_missing_response value='$RAW_IP'"

    SOURCE="http"
    if RAW_IP="$(get_ip_from_http 2>/dev/null)"; then
        log "event=attempt source=http value='$RAW_IP'"
    else
        log "event=error source=http reason=command_failed"
        RAW_IP=""
    fi
fi

# --- final validation (critical invariant) ---
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
UPDATE_RESPONSE="$(
    "$CURL_CMD" -s --fail --max-time 5 \
    "https://api.dynu.com/nic/update?hostname=${DYNU_HOST}&username=${DYNU_USER}&password=${DYNU_PASSWORD}&myip=${CURRENT_IP}" \
    || true
)"

log "event=update_response response='$UPDATE_RESPONSE'"

# --- response validation ---
if [[ -z "$UPDATE_RESPONSE" ]]; then
    log "event=error reason=empty_update_response"
    exit 1
fi

# Dynu success responses:
#   good <ip>   → updated
#   nochg <ip>  → already current
if [[ "$UPDATE_RESPONSE" == good* || "$UPDATE_RESPONSE" == nochg* ]]; then
    TMP_FILE=$(mktemp -p "$STATE_DIR" last_ip.XXXXXX)

    echo "$CURRENT_IP" > "$TMP_FILE"
    mv "$TMP_FILE" "$LAST_IP_FILE"

    log "event=state_updated ip=$CURRENT_IP"
else
    log "event=update_failed response='$UPDATE_RESPONSE'"
    exit 1
fi