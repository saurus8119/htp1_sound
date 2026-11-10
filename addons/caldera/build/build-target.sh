#!/bin/bash
set -euo pipefail

OUT=${OUT:-/out}
CALDERA_USER=caldera
CALDERA_HOME=/home/caldera
mkdir -p "$OUT" /usr/local/libexec/caldera-build-shims

echo "Target architecture: $(uname -m)"
echo "Target libc: $(getconf GNU_LIBC_VERSION)"

# Caldera's official installer downloads and installs the daemon, then registers
# a systemd user service. The HTP-1 addon manager owns the eventual system
# service, so suppress only those two user-session registration commands here.
cat > /usr/local/libexec/caldera-build-shims/loginctl <<'SH'
#!/bin/sh
if [ "$#" -eq 2 ] && [ "$1" = enable-linger ]; then
  echo "BUILD: skipped loginctl enable-linger (HTP-1 addon lifecycle owns startup)"
  exit 0
fi
exec /usr/bin/loginctl "$@"
SH
cat > /usr/local/libexec/caldera-build-shims/systemctl <<'SH'
#!/bin/sh
if [ "${1:-}" = --user ]; then
  echo "BUILD: skipped systemctl --user $* (HTP-1 addon lifecycle owns startup)"
  exit 0
fi
exec /usr/bin/systemctl "$@"
SH
chmod 0755 /usr/local/libexec/caldera-build-shims/loginctl /usr/local/libexec/caldera-build-shims/systemctl

echo "Running the official Caldera installer unchanged; only user-service registration is bypassed."
runuser -u "$CALDERA_USER" -- env \
  HOME="$CALDERA_HOME" USER="$CALDERA_USER" LOGNAME="$CALDERA_USER" \
  PATH="/usr/local/libexec/caldera-build-shims:$PATH" \
  bash -c '
    set -euo pipefail
    curl -fsSL https://releases.caldera.homes/music/headless/install.sh -o /tmp/caldera-install.sh
    bash /tmp/caldera-install.sh
  '

INSTALL_DIR="$CALDERA_HOME/caldera-music"
BINARY="$INSTALL_DIR/caldera-music"
if [[ ! -x "$BINARY" ]]; then
  echo "Installer completed but expected executable was not found: $BINARY" >&2
  find "$CALDERA_HOME" -maxdepth 5 -type f -print >&2 || true
  exit 1
fi

file "$BINARY" | tee "$OUT/binary-file.txt"
readelf -h "$BINARY" > "$OUT/binary-elf-header.txt"
ldd "$BINARY" > "$OUT/binary-ldd.txt" 2>&1 || true
runuser -u "$CALDERA_USER" -- env HOME="$CALDERA_HOME" "$BINARY" --help > "$OUT/binary-help.txt" 2>&1 || true

tar -C "$CALDERA_HOME" -czf "$OUT/caldera-music-armv7.tar.gz" caldera-music
sha256sum "$OUT/caldera-music-armv7.tar.gz" > "$OUT/caldera-music-armv7.tar.gz.sha256"
echo "Installer output captured. Runtime service packaging is a separate validation step."
