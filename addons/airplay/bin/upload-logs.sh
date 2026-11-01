#!/bin/bash
# Upload HTPlay-1 service logs only. Local logs are retained after upload.
set -euo pipefail

SMB_SERVER="truenas.local"
SMB_SHARE="mnt"
SMB_FOLDER="Apps"
ADDON_DIR="/var/lib/olympia/addons/airplay2"
LOG_DIR="$ADDON_DIR/logs"
CONFIG_FILE="$ADDON_DIR/etc/htplay1.conf"
MODE="${1:---all}"
case "$MODE" in
  --all|--incremental) ;;
  *) echo "Usage: $0 [--all|--incremental]" >&2; exit 2 ;;
esac

WORK_DIR="$(mktemp -d /tmp/htplay1-logs.XXXXXX)"
STAMP="$(date -u +%Y%m%d-%H%M%S)"
HOST="$(hostname 2>/dev/null || echo htp1)"
ARCHIVE="/tmp/HTPlay-1-logs-${HOST}-${STAMP}.tar.gz"
AUTH_FILE=""
declare -A NEW_OFFSETS

cleanup() {
  rm -rf "$WORK_DIR"
  [ -z "$AUTH_FILE" ] || rm -f "$AUTH_FILE"
  rm -f "$ARCHIVE"
}
trap cleanup EXIT

if [ "$(id -u)" -ne 0 ]; then
  echo "Run this script as root." >&2
  exit 1
fi
command -v smbclient >/dev/null 2>&1 || {
  echo "smbclient is not installed." >&2
  exit 1
}
[ -r "$CONFIG_FILE" ] || {
  echo "Missing $CONFIG_FILE." >&2
  exit 1
}

# Read key=value settings without sourcing or executing the config file.
read_setting() {
  awk -v key="$1" '
    {
      separator = index($0, "=")
      if (!separator) next
      name = substr($0, 1, separator - 1)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", name)
      if (name != key) next
      value = substr($0, separator + 1)
      sub(/^[[:space:]]+/, "", value)
      sub(/[[:space:]]+$/, "", value)
      sub(/^"/, "", value)
      sub(/"$/, "", value)
      sub(/[[:space:]]+#.*$/, "", value)
      print value
      exit
    }
  ' "$CONFIG_FILE"
}

SMB_USER="$(read_setting audio)"
SMB_PASS="$(read_setting video)"
if [ -z "$SMB_USER" ] || [ -z "$SMB_PASS" ] ||
   [ "$SMB_USER" = "CHANGE_ME" ] || [ "$SMB_PASS" = "CHANGE_ME" ]; then
  echo "Set both SMB settings in $CONFIG_FILE before uploading." >&2
  exit 1
fi

mkdir -p "$LOG_DIR" "$WORK_DIR"
for unit in airplay2.service nqptp-airplay2.service; do
  systemctl status "$unit" --no-pager > "$WORK_DIR/${unit}.status.txt" 2>&1 || true
done

if [ -r "$ADDON_DIR/addon.json" ]; then
  cp "$ADDON_DIR/addon.json" "$WORK_DIR/addon.json"
fi
if [ -r "$ADDON_DIR/etc/shairport-sync.conf" ]; then
  sed -E \
    -e '/^[[:space:]]*(password|mdns_backend|username)[[:space:]]*=/I s/(=[[:space:]]*).*/= "[REDACTED]";/' \
    "$ADDON_DIR/etc/shairport-sync.conf" > "$WORK_DIR/shairport-sync.conf"
fi

{
  echo "HTPlay-1 diagnostic bundle"
  echo "Collected UTC: $(date -u)"
  echo "Upload mode: $MODE"
  echo "Scope: HTPlay-1 Shairport Sync and NQPTP add-on services only."
  echo "No HTP-1 platform logs, kernel logs, Avahi logs, or general system inventory."
  echo "Log files are retained locally after upload."
} > "$WORK_DIR/README.txt"

# Startup sends complete existing local logs. Periodic uploads send only bytes
# appended since the last successful upload; offsets advance only after SMB succeeds.
for name in airplay2 nqptp-airplay2; do
  source_file="$LOG_DIR/$name.log"
  offset_file="$LOG_DIR/.uploaded-$name.offset"
  [ -f "$source_file" ] || touch "$source_file"
  size="$(wc -c < "$source_file" | tr -d ' ')"
  offset=0
  if [ "$MODE" = "--incremental" ] && [ -r "$offset_file" ]; then
    read -r offset < "$offset_file" || offset=0
    case "$offset" in ''|*[!0-9]*) offset=0 ;; esac
  fi
  if [ "$offset" -gt "$size" ]; then offset=0; fi
  if [ "$MODE" = "--incremental" ] && [ "$size" -eq "$offset" ]; then
    continue
  fi
  tail -c "+$((offset + 1))" "$source_file" > "$WORK_DIR/$name.log"
  NEW_OFFSETS["$name"]="$size"
done

if [ "$MODE" = "--incremental" ] && [ "${#NEW_OFFSETS[@]}" -eq 0 ]; then
  echo "No new HTPlay-1 log entries; nothing to upload."
  exit 0
fi

tar -czf "$ARCHIVE" -C "$WORK_DIR" .
AUTH_FILE="$(mktemp /tmp/htplay1-smb-auth.XXXXXX)"
chmod 600 "$AUTH_FILE"
{
  printf 'username = %s\n' "$SMB_USER"
  printf 'password = %s\n' "$SMB_PASS"
} > "$AUTH_FILE"
unset SMB_PASS

smbclient "//${SMB_SERVER}/${SMB_SHARE}" -A "$AUTH_FILE" \
  -c "cd ${SMB_FOLDER}; put ${ARCHIVE} ${ARCHIVE##*/}"

for name in "${!NEW_OFFSETS[@]}"; do
  printf '%s\n' "${NEW_OFFSETS[$name]}" > "$LOG_DIR/.uploaded-$name.offset.tmp"
  mv "$LOG_DIR/.uploaded-$name.offset.tmp" "$LOG_DIR/.uploaded-$name.offset"
done

echo "Uploaded HTPlay-1 log archive: //${SMB_SERVER}/${SMB_SHARE}/${SMB_FOLDER}/${ARCHIVE##*/}"
