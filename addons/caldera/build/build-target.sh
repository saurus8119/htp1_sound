#!/bin/bash
set -euo pipefail

OUT=${OUT:-/out}
mkdir -p "$OUT"

echo "Target architecture: $(uname -m)"
echo "Target libc: $(getconf GNU_LIBC_VERSION)"
echo "Running Caldera's official ARM auto-detecting installer."

curl -fsSL https://releases.caldera.homes/music/headless/install.sh -o /tmp/caldera-install.sh
bash /tmp/caldera-install.sh

INSTALL_DIR="$HOME/caldera-music"
BINARY="$INSTALL_DIR/caldera-music"

if [[ ! -x "$BINARY" ]]; then
  echo "Installer completed but expected executable was not found: $BINARY" >&2
  echo "Installer directory contents:" >&2
  find "$HOME" -maxdepth 4 -type f -printf '%p\n' >&2 || true
  exit 1
fi

file "$BINARY" | tee "$OUT/binary-file.txt"
"$BINARY" --help > "$OUT/binary-help.txt" 2>&1 || true

tar -C "$HOME" -czf "$OUT/caldera-music-armv7.tar.gz" caldera-music
sha256sum "$OUT/caldera-music-armv7.tar.gz" > "$OUT/caldera-music-armv7.tar.gz.sha256"

echo "Caldera ARMv7 installation captured in $OUT/caldera-music-armv7.tar.gz"
