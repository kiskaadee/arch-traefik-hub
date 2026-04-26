#!/usr/bin/env bash
set -euo pipefail

# --- argument parsing ---
DYNU_HOST=""
DYNU_USER=""
DYNU_PASSWORD=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --host) DYNU_HOST="$2"; shift 2 ;;
        --user) DYNU_USER="$2"; shift 2 ;;
        --password) DYNU_PASSWORD="$2"; shift 2 ;;
        *)
            echo "Unknown argument: $1"
            exit 1
            ;;
    esac
done

# --- validation ---
: "${DYNU_HOST:?--host required}"
: "${DYNU_USER:?--user required}"
: "${DYNU_PASSWORD:?--password required}"

# --- root check ---
if [[ $EUID -ne 0 ]]; then
    echo "Run as root"
    exit 1
fi

# --- paths ---
BIN_PATH="/usr/local/bin/ip-monitor.sh"
SERVICE_PATH="/etc/systemd/system/dynu.service"
TIMER_PATH="/etc/systemd/system/dynu.timer"
ENV_PATH="/etc/conf.d/dynu-environment"

# --- install files ---
install -m 755 ip-monitor.sh "$BIN_PATH"
install -m 644 dynu.service "$SERVICE_PATH"
install -m 644 dynu.timer "$TIMER_PATH"

# --- write env file atomically ---
TMP_ENV=$(mktemp)

cat > "$TMP_ENV" <<EOF
DYNU_HOST=$DYNU_HOST
DYNU_USER=$DYNU_USER
DYNU_PASSWORD=$DYNU_PASSWORD
EOF

install -m 600 "$TMP_ENV" "$ENV_PATH"
rm -f "$TMP_ENV"

# --- systemd reload ---
systemctl daemon-reload

# --- enable + start timer  ---
systemctl enable --now dynu.timer

echo "Installation complete"
echo "Check logs with: journalctl -u dynu.service -f"

