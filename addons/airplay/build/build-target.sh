
#!/bin/sh
set -eu

OUT=/out
WORK=/work

mkdir -p "$OUT" "$WORK/src" "$WORK/stage-nqptp" "$WORK/stage-shairport"
cd "$WORK"

fetch() {
  url=$1
  file=$2
  [ -s "$file" ] || curl -fL --retry 3 --connect-timeout 20 "$url" -o "$file"
}

# Pinned source versions.
fetch https://github.com/mikebrady/shairport-sync/archive/refs/tags/5.6.1.tar.gz shairport-sync-5.6.1.tar.gz
fetch https://github.com/mikebrady/nqptp/archive/refs/tags/1.2.9.tar.gz nqptp-1.2.9.tar.gz
fetch https://github.com/libimobiledevice/libplist/archive/refs/tags/2.3.0.tar.gz libplist-2.3.0.tar.gz

# Extract source archives.
for item in \
  'libplist-2.3.0 libplist-2.3.0.tar.gz' \
  'nqptp-1.2.9 nqptp-1.2.9.tar.gz' \
  'shairport-sync-5.6.1 shairport-sync-5.6.1.tar.gz'
do
  set -- $item
  if [ ! -d "src/$1" ]; then
    mkdir -p "src/$1"
    tar -xzf "$2" --strip-components=1 -C "src/$1"
  fi
done

# Build and install libplist.
cd "$WORK/src/libplist-2.3.0"
echo "2.3.0" > .tarball-version
./autogen.sh --prefix=/usr/local --without-cython
make -j2
make install

cd "$WORK"
ldconfig

# Build and stage NQPTP.
cd "$WORK/src/nqptp-1.2.9"
autoreconf -fi
./configure --prefix=/usr
make -j2
DESTDIR="$WORK/stage-nqptp" make install

# Patch Shairport Sync's UUIDv5 call for the older Stretch libuuid.
# The implementation follows RFC 4122: SHA-1(namespace || name),
# followed by setting the UUID version and variant bits.
cd "$WORK/src/shairport-sync-5.6.1"

UUID_SOURCE="$WORK/src/shairport-sync-5.6.1/utilities/generate_device_uuid.c"

if ! grep -q 'HTP1_UUID_SHA1_COMPAT' "$UUID_SOURCE"; then
  if ! grep -q 'uuid_generate_sha1(' "$UUID_SOURCE"; then
    echo "Expected uuid_generate_sha1() call was not found in $UUID_SOURCE" >&2
    exit 1
  fi

  sed -i 's/uuid_generate_sha1(/htp1_uuid_generate_sha1(/g' "$UUID_SOURCE"

  {
    cat <<'UUID_COMPAT'
/* HTP1_UUID_SHA1_COMPAT */
#include <uuid/uuid.h>
#include <openssl/sha.h>
#include <string.h>

static void htp1_uuid_generate_sha1(uuid_t out, const uuid_t ns,
                                    const char *name, size_t len) {
  SHA_CTX ctx;
  unsigned char hash[SHA_DIGEST_LENGTH];

  SHA1_Init(&ctx);
  SHA1_Update(&ctx, ns, sizeof(uuid_t));
  SHA1_Update(&ctx, name, len);
  SHA1_Final(hash, &ctx);

  memcpy(out, hash, sizeof(uuid_t));

  /* RFC 4122 UUID version 5 and variant bits. */
  out[6] = (out[6] & 0x0f) | 0x50;
  out[8] = (out[8] & 0x3f) | 0x80;
}
UUID_COMPAT
    cat "$UUID_SOURCE"
  } > "$UUID_SOURCE.tmp"

  mv "$UUID_SOURCE.tmp" "$UUID_SOURCE"
fi

# Generate the build system and configure AirPlay 2 support.
autoreconf -fi

PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:/usr/local/lib/arm-linux-gnueabihf/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}" \
  ./configure \
    --prefix=/usr \
    --sysconfdir=/etc \
    --with-alsa \
    --with-avahi \
    --with-ssl=openssl \
    --with-soxr \
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

# Record checks. Physical HTP-1 playback is not tested by this build.
{
  echo "result=PASS: build, architecture, dynamic-link and version checks passed"
  echo "runtime_htp1_shared_libraries=NOT_VERIFIED"
  echo "runtime_smi_handshake=NOT_VERIFIED"
  echo "physical_htp1_playback=NOT_VERIFIED"
  echo "shairport_sync_source=5.6.1"
  echo "nqptp_source=1.2.9"
  echo "libplist_source=2.3.0"
  echo "uuid_sha1_compatibility=OpenSSL_SHA1"
  echo "target=armhf / Debian 9 / glibc 2.24 baseline"
  echo "configure_flags=--with-alsa --with-avahi --with-ssl=openssl --with-soxr --with-airplay-2"
  sha256sum "$OUT/shairport-sync" "$OUT/nqptp"
} > "$OUT/BUILD-REPORT.txt"

