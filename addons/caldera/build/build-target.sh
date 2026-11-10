#!/bin/bash
set -euo pipefail

OUT=${OUT:-/out}
CALDERA_USER=caldera
CALDERA_HOME=/home/caldera
CALDERA_UID=1000
mkdir -p "$OUT"

echo "Target architecture: $(uname -m)"
echo "Target libc: $(getconf GNU_LIBC_VERSION)"

# The official installer enables and starts a systemd --user service.
# Run it under a real systemd PID 1 and user manager, not a fake systemctl.
echo "Enabling lingering for $CALDERA_USER."
loginctl enable-linger "$CALDERA_USER"
systemctl start "user@${CALDERA_UID}.service"

RUNTIME_DIR="/run/user/${CALDERA_UID}"
for attempt in $(seq 1 30); do
  if [[ -S "$RUNTIME_DIR/bus" ]]; then
    break
  fi
  sleep 1
done
if [[ ! -S "$RUNTIME_DIR/bus" ]]; then
  echo "systemd user bus did not become available at $RUNTIME_DIR/bus" >&2
  systemctl status "user@${CALDERA_UID}.service" --no-pager || true
  exit 1
fi

echo "Running Caldera's official ARM auto-detecting installer as $CALDERA_USER."
runuser -u "$CALDERA_USER" -- env \
  HOME="$CALDERA_HOME" \
  USER="$CALDERA_USER" \
  LOGNAME="$CALDERA_USER" \
  XDG_RUNTIME_DIR="$RUNTIME_DIR" \
  DBUS_SESSION_BUS_ADDRESS="unix:path=$RUNTIME_DIR/bus" \
  bash -c '
    set -euo pipefail
    curl -fsSL https://releases.caldera.homes/music/headless/install.sh -o /tmp/caldera-install.sh
    bash /tmp/caldera-install.sh
  '

INSTALL_DIR="$CALDERA_HOME/caldera-music"
BINARY="$INSTALL_DIR/caldera-music"

if [[ ! -x "$BINARY" ]]; then
  echo "Installer completed but expected executable was not found: $BINARY" >&2
  echo "Installer directory contents:" >&2
  find "$CALDERA_HOME" -maxdepth 4 -type f -printf '%p\\n' >&2 || true
  exit 1
fi

file "$BINARY" | tee "$OUT/binary-file.txt"
runuser -u "$CALDERA_USER" -- env HOME="$CALDERA_HOME" "$BINARY" --help > "$OUT/binary-help.txt" 2>&1 || true

tar -C "$CALDERA_HOME" -czf "$OUT/caldera-music-armv7.tar.gz" caldera-music
sha256sum "$OUT/caldera-music-armv7.tar.gz" > "$OUT/caldera-music-armv7.tar.gz.sha256"

echo "Caldera ARMv7 installation captured in $OUT/caldera-music-armv7.tar.gz"
