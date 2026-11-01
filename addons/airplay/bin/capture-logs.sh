#!/bin/bash
# Persist only HTPlay-1 Shairport Sync and NQPTP journal output.
set -euo pipefail

ADDON_DIR="/var/lib/olympia/addons/airplay2"
LOG_DIR="$ADDON_DIR/logs"
UPLOAD="$ADDON_DIR/bin/upload-logs.sh"
mkdir -p "$LOG_DIR"
touch "$LOG_DIR/airplay2.log" "$LOG_DIR/nqptp-airplay2.log"
chmod 600 "$LOG_DIR"/*.log

# Upload logs left by the previous run before collecting this run.
# A NAS outage must not prevent AirPlay services from starting.
if command -v timeout >/dev/null 2>&1; then
  timeout 15 "$UPLOAD" --all || true
else
  "$UPLOAD" --all || true
fi

journalctl -f -n 0 -u airplay2.service -o short-iso >> "$LOG_DIR/airplay2.log" 2>&1 &
AIRPLAY_PID=$!
journalctl -f -n 0 -u nqptp-airplay2.service -o short-iso >> "$LOG_DIR/nqptp-airplay2.log" 2>&1 &
NQPTP_PID=$!

stop_capture() {
  kill "$AIRPLAY_PID" "$NQPTP_PID" 2>/dev/null || true
  wait "$AIRPLAY_PID" "$NQPTP_PID" 2>/dev/null || true
}
trap stop_capture EXIT
trap 'exit 0' INT TERM

while true; do
  sleep 60
  "$UPLOAD" --incremental || true
done
