#!/bin/bash
set -euo pipefail

OUT=${OUT:-/out}
CALDERA_USER=caldera
CALDERA_HOME=/home/caldera
mkdir -p "$OUT" /usr/local/libexec/caldera-build-shims

echo "Target architecture: $(uname -m)"
echo "Installer environment libc: $(getconf GNU_LIBC_VERSION)"

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
LAUNCHER="$INSTALL_DIR/caldera-music"
if [[ ! -x "$LAUNCHER" ]]; then
  echo "Installer completed but expected launcher was not found: $LAUNCHER" >&2
  find "$CALDERA_HOME" -maxdepth 6 -type f -print >&2 || true
  exit 1
fi

# Bundle a self-consistent ARMHF GLIBC + libstdc++ runtime from Debian Bullseye.
RUNTIME_LIB="$INSTALL_DIR/lib"
mkdir -p "$RUNTIME_LIB"
cp -a /opt/caldera-runtime/lib/arm-linux-gnueabihf/. "$RUNTIME_LIB/"
cp -a /opt/caldera-runtime/usr/lib/arm-linux-gnueabihf/. "$RUNTIME_LIB/"
cp -L /opt/caldera-runtime/lib/ld-linux-armhf.so.3 "$RUNTIME_LIB/ld-linux-armhf.so.3"
chmod 0755 "$RUNTIME_LIB/ld-linux-armhf.so.3"

file "$LAUNCHER" | tee "$OUT/launcher-file.txt"
cp "$LAUNCHER" "$OUT/caldera-music-launcher.sh"
sed -n '1,240p' "$LAUNCHER" > "$OUT/launcher-contents.txt"
find "$INSTALL_DIR" -type f -exec file {} \; > "$OUT/install-files.txt"

: > "$OUT/binary-elf-header.txt"
: > "$OUT/binary-ldd.txt"
ELF_COUNT=0
while IFS= read -r -d '' candidate; do
  description=$(file -b "$candidate" 2>/dev/null || true)
  if [[ "$description" == *ELF* ]]; then
    ELF_COUNT=$((ELF_COUNT + 1))
    {
      echo "===== $candidate ====="
      echo "$description"
      readelf -h "$candidate" || true
    } >> "$OUT/binary-elf-header.txt"

    # Only ET_EXEC/PIE programs have a PT_INTERP and can be checked with --list.
    if readelf -l "$candidate" 2>/dev/null | grep -q 'Requesting program interpreter'; then
      {
        echo "===== $candidate (bundled loader) ====="
        "$RUNTIME_LIB/ld-linux-armhf.so.3" --library-path "$RUNTIME_LIB" --list "$candidate" 2>&1 || true
      } >> "$OUT/binary-ldd.txt"
      if "$RUNTIME_LIB/ld-linux-armhf.so.3" --library-path "$RUNTIME_LIB" --list "$candidate" 2>&1 | grep -q 'not found'; then
        echo "Unresolved shared library for $candidate" >&2
        exit 1
      fi
    fi
  fi
done < <(find "$INSTALL_DIR" -type f -print0)

echo "ELF payloads found: $ELF_COUNT"
if [[ "$ELF_COUNT" -eq 0 ]]; then
  echo "No ELF payload found beneath $INSTALL_DIR; launcher and full file inventory are included for diagnosis."
fi

"$RUNTIME_LIB/ld-linux-armhf.so.3" --library-path "$RUNTIME_LIB" \
  "$INSTALL_DIR/bin/caldera-music" --help > "$OUT/launcher-help.txt" 2>&1 || true

tar -C "$CALDERA_HOME" -czf "$OUT/caldera-music-armv7.tar.gz" caldera-music
sha256sum "$OUT/caldera-music-armv7.tar.gz" > "$OUT/caldera-music-armv7.tar.gz.sha256"
echo "Installer output captured and archived with the bundled ARMHF runtime."
