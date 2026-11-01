#!/bin/bash
# Create a diagnostic bundle and upload it to the TrueNAS SMB share.
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

cleanup() {
  rm -rf "$WORK_DIR"
  rm -f "${AUTH_FILE:-}"
}
trap cleanup EXIT

if [ "$(id -u)" -ne 0 ]; then
  echo "Run this script as root (for example, with sudo)." >&2
  exit 1
fi

if ! command -v smbclient >/dev/null 2>&1; then
  echo "smbclient is not installed on the HTP-1; cannot upload to SMB." >&2
  echo "No audio settings or services have been changed." >&2
  exit 1
fi

mkdir -p "$WORK_DIR"

{
  echo "HTPlay-1 diagnostic bundle"
  echo "Collected UTC: $(date -u -Iseconds 2>/dev/null || date -u)"
  echo "Hostname: $HOST"
  echo
  echo "=== OS ==="
  uname -a
  cat /etc/debian_version 2>/dev/null || true
  echo
  echo "=== Uptime and memory ==="
  uptime
  free -m 2>/dev/null || true
  echo
  echo "=== Filesystems ==="
  df -h
} > "$WORK_DIR/system-info.txt" 2>&1

for unit in airplay2.service nqptp-airplay2.service avahi-daemon.service; do
  systemctl status "$unit" --no-pager > "$WORK_DIR/${unit}.status.txt" 2>&1 || true
  journalctl -u "$unit" --since "24 hours ago" --no-pager -o short-iso \
    > "$WORK_DIR/${unit}.log" 2>&1 || true
done

dmesg > "$WORK_DIR/dmesg.txt" 2>&1 || true

# Include the active Shairport configuration, masking any password setting.
if [ -r "$ADDON_DIR/etc/shairport-sync.conf" ]; then
  sed -E '/^[[:space:]]*password[[:space:]]*=/I s/(=[[:space:]]*).*/= "[REDACTED]";/' \
    "$ADDON_DIR/etc/shairport-sync.conf" > "$WORK_DIR/shairport-sync.conf"
fi

tar -czf "$ARCHIVE" -C "$WORK_DIR" .
echo "Created diagnostic archive: $ARCHIVE"

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
