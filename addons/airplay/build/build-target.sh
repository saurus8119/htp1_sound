
#!/bin/sh
set -eu

OUT=/out
WORK=/work

SHAIRPORT_VERSION=5.6.1
NQPTP_VERSION=1.2.9
LIBPLIST_VERSION=2.3.0

mkdir -p "$OUT" "$WORK/src" "$WORK/stage-nqptp" "$WORK/stage-shairport"
cd "$WORK"

fetch() {
  url=$1
  file=$2
  [ -s "$file" ] || curl -fL --retry 3 --connect-timeout 20 "$url" -o "$file"
}

# Pinned source versions.
fetch "https://github.com/mikebrady/shairport-sync/archive/refs/tags/${SHAIRPORT_VERSION}.tar.gz" "shairport-sync-${SHAIRPORT_VERSION}.tar.gz"
fetch "https://github.com/mikebrady/nqptp/archive/refs/tags/${NQPTP_VERSION}.tar.gz" "nqptp-${NQPTP_VERSION}.tar.gz"
fetch "https://github.com/libimobiledevice/libplist/archive/refs/tags/${LIBPLIST_VERSION}.tar.gz" "libplist-${LIBPLIST_VERSION}.tar.gz"

# Extract source archives.
for item in \
  "libplist-${LIBPLIST_VERSION} libplist-${LIBPLIST_VERSION}.tar.gz" \
  "nqptp-${NQPTP_VERSION} nqptp-${NQPTP_VERSION}.tar.gz" \
  "shairport-sync-${SHAIRPORT_VERSION} shairport-sync-${SHAIRPORT_VERSION}.tar.gz"
do
  set -- $item
  if [ ! -d "src/$1" ]; then
    mkdir -p "src/$1"
    tar -xzf "$2" --strip-components=1 -C "src/$1"
  fi
done

# Build and install libplist.
cd "$WORK/src/libplist-${LIBPLIST_VERSION}"
echo "$LIBPLIST_VERSION" > .tarball-version
./autogen.sh --prefix=/usr/local --without-cython
make -j2
make install

cd "$WORK"
ldconfig

# Build and stage NQPTP.
cd "$WORK/src/nqptp-${NQPTP_VERSION}"
autoreconf -fi
./configure --prefix=/usr
make -j2
DESTDIR="$WORK/stage-nqptp" make install

# Debian Stretch ships an older libuuid without uuid_generate_sha1.
# Compile the compatibility implementation supplied in the Docker image.
gcc -Wall -Wextra -Werror -c \
  /usr/local/src/uuid-generate-sha1-compat.c \
  -o "$WORK/uuid-generate-sha1-compat.o"

# Generate the Shairport Sync build system and configure AirPlay 2 support.
cd "$WORK/src/shairport-sync-${SHAIRPORT_VERSION}"
autoreconf -fi

PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:/usr/local/lib/arm-linux-gnueabihf/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}" \
  LIBS="$WORK/uuid-generate-sha1-compat.o -lcrypto -Wl,-Bstatic -lsodium -lconfig -Wl,-Bdynamic" \
  ./configure \
    --prefix=/usr \
    --sysconfdir=/etc \
    --with-alsa \
    --with-avahi \
    --with-ssl=openssl \
    --with-pipe \
    --with-airplay-2

make -j2
DESTDIR="$WORK/stage-shairport" make install

cd "$WORK"

# Stage Shairport Sync executable.
install -m 0755 \
  "$WORK/stage-shairport/usr/bin/shairport-sync" \
  "$OUT/shairport-sync"

# Locate and stage the NQPTP executable.
NQPTP_BIN="$WORK/stage-nqptp/usr/bin/nqptp"

if [ ! -x "$NQPTP_BIN" ]; then
  NQPTP_BIN=$(find "$WORK/stage-nqptp" -type f -name nqptp -perm /111 | head -n 1)
fi

if [ -z "$NQPTP_BIN" ] || [ ! -x "$NQPTP_BIN" ]; then
  echo "Could not find built nqptp executable" >&2
  exit 1
fi

install -m 0755 "$NQPTP_BIN" "$OUT/nqptp"

# Bundle libplist shared objects.
mkdir -p "$OUT/lib"
cp -a /usr/local/lib/libplist-2.0.so* "$OUT/lib/"

if ! ls "$OUT"/lib/libplist-2.0.so* >/dev/null 2>&1; then
  echo "Bundled libplist shared objects are missing" >&2
  exit 1
fi

# Verify binary architecture.
file "$OUT/shairport-sync" > "$OUT/shairport-file.txt"
file "$OUT/nqptp" > "$OUT/nqptp-file.txt"
cat "$OUT/shairport-file.txt" "$OUT/nqptp-file.txt" > "$OUT/file-report.txt"
cat "$OUT/file-report.txt"

if ! grep -q 'ARM' "$OUT/shairport-file.txt"; then
  echo "Shairport Sync binary is not ARM" >&2
  exit 1
fi

if ! grep -q 'ARM' "$OUT/nqptp-file.txt"; then
  echo "NQPTP binary is not ARM" >&2
  exit 1
fi

# Check shared-library resolution in the build container.
LD_LIBRARY_PATH="$OUT/lib" ldd "$OUT/shairport-sync" > "$OUT/shairport-ldd.txt"
ldd "$OUT/nqptp" > "$OUT/nqptp-ldd.txt"

cat "$OUT/shairport-ldd.txt"
cat "$OUT/nqptp-ldd.txt"

if grep -q 'not found' "$OUT/shairport-ldd.txt" "$OUT/nqptp-ldd.txt"; then
  echo "One or more shared-library dependencies are missing in the build container" >&2
  exit 1
fi

if grep -Eq 'lib(config|sodium)\.so' "$OUT/shairport-ldd.txt"; then
  echo "libconfig/libsodium should be statically linked for HTP-1 compatibility" >&2
  exit 1
fi

if ! grep -Fq "$OUT/lib/libplist-2.0.so" "$OUT/shairport-ldd.txt"; then
  echo "Shairport Sync is not resolving libplist from the staged addon library directory" >&2
  exit 1
fi

# Check executable startup and report versions.
LD_LIBRARY_PATH="$OUT/lib" "$OUT/shairport-sync" -V > "$OUT/shairport-version.txt"
LD_LIBRARY_PATH="$OUT/lib" "$OUT/nqptp" -V > "$OUT/nqptp-version.txt"

cat "$OUT/shairport-version.txt"
cat "$OUT/nqptp-version.txt"

if ! grep -qi 'smi11' "$OUT/shairport-version.txt"; then
  echo "Shairport Sync does not report smi11" >&2
  exit 1
fi

if ! grep -qi 'smi11' "$OUT/nqptp-version.txt"; then
  echo "NQPTP does not report smi11" >&2
  exit 1
fi

# Stage the two Debian 9 ARMHF packages needed to run Avahi for AirPlay 2.
mkdir -p "$OUT/debs"
cp -a /opt/htp1-debs/avahi-daemon_*.deb /opt/htp1-debs/libavahi-core7_*.deb "$OUT/debs/"

for deb in "$OUT"/debs/*.deb; do
  [ -f "$deb" ] || { echo "Missing required Avahi package: $deb" >&2; exit 1; }
  dpkg-deb -f "$deb" Package Architecture
done

# Record checks. Physical HTP-1 playback is not tested by this build.
{
  echo "result=PASS: build, architecture, dynamic-link and version checks passed"
  echo "runtime_htp1_shared_libraries=NOT_VERIFIED"
  echo "runtime_smi_handshake=NOT_VERIFIED"
  echo "physical_htp1_playback=NOT_VERIFIED"
  echo "shairport_sync_source=${SHAIRPORT_VERSION}"
  echo "nqptp_source=${NQPTP_VERSION}"
  echo "shared_memory_interface=smi11"
  echo "libplist_source=${LIBPLIST_VERSION}"
  echo "avahi_runtime_packages=avahi-daemon,libavahi-core7"
  echo "target=armhf / Debian 9 / glibc 2.24 baseline"
  echo "configure_flags=--with-alsa --with-avahi --with-ssl=openssl --with-pipe --with-airplay-2"
  sha256sum "$OUT/shairport-sync" "$OUT/nqptp"
} > "$OUT/BUILD-REPORT.txt"
