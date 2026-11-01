#!/bin/bash
# Collect HTPlay-1 add-on diagnostics only and upload them to TrueNAS.
# Run as root on the HTP-1:
#   /var/lib/olympia/addons/airplay2/bin/upload-logs.sh

set -euo pipefail

SMB_SERVER="truenas.local"
SMB_SHARE="mnt"
SMB_FOLDER="Apps"
ADDON_DIR="/var/lib/olympia/addons/airplay2"
WORK_DIR="$(mktemp -d /tmp/htplay1-logs.XXXXXX)"
STAMP="$(date -u +%Y%m%d-%H%M%S)"
HOST="$(hostname 2>/dev/null || echo htp1)"
ARCHIVE="/tmp/HTPlay-1-logs-${HOST}-${STAMP}.tar.gz"
AUTH_FILE=""

cleanup() {
  rm -rf "$WORK_DIR"
  [ -z "$AUTH_FILE" ] || rm -f "$AUTH_FILE"
}
trap cleanup EXIT

if [ "$(id -u)" -ne 0 ]; then
  echo "Run this script as root." >&2
  exit 1
fi

if ! command -v smbclient >/dev/null 2>&1; then
  echo "smbclient is not installed; the bundled add-on dependency may not have installed correctly." >&2
  exit 1
fi

mkdir -p "$WORK_DIR"

# Record add-on identity and the active configuration only.
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
  echo "Collected UTC: $(date -u -Iseconds 2>/dev/null || date -u)"
  echo "Addon version: $(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\\([^"]*\\)".*/\\1/p' "$WORK_DIR/addon.json" 2>/dev/null | head -n 1)"
  echo
  echo "Scope: HTPlay-1 add-on services only."
  echo "No HTP-1 platform logs, kernel logs, Avahi logs, or general system inventory are collected."
} > "$WORK_DIR/README.txt"

for unit in airplay2.service nqptp-airplay2.service; do
  systemctl status "$unit" --no-pager > "$WORK_DIR/${unit}.status.txt" 2>&1 || true
  journalctl -u "$unit" --since "24 hours ago" --no-pager -o short-iso \
    > "$WORK_DIR/${unit}.log" 2>&1 || true
done

tar -czf "$ARCHIVE" -C "$WORK_DIR" .
echo "Created HTPlay-1 diagnostic archive: $ARCHIVE"

printf 'TrueNAS SMB username (leave blank for guest access): '
IFS= read -r SMB_USER

if [ -n "$SMB_USER" ]; then
  printf 'SMB password: '
  IFS= read -r -s SMB_PASS
  printf '\n'
  AUTH_FILE="$(mktemp /tmp/htplay1-smb-auth.XXXXXX)"
  chmod 600 "$AUTH_FILE"
  {
    printf 'username = %s\n' "$SMB_USER"
    printf 'password = %s\n' "$SMB_PASS"
  } > "$AUTH_FILE"
  unset SMB_PASS
  smbclient "//${SMB_SERVER}/${SMB_SHARE}" -A "$AUTH_FILE" \
    -c "cd ${SMB_FOLDER}; put ${ARCHIVE} ${ARCHIVE##*/}"
else
  smbclient "//${SMB_SERVER}/${SMB_SHARE}" -N \
    -c "cd ${SMB_FOLDER}; put ${ARCHIVE} ${ARCHIVE##*/}"
fi < /dev/null

echo "Upload completed: //${SMB_SERVER}/${SMB_SHARE}/${SMB_FOLDER}/${ARCHIVE##*/}"
