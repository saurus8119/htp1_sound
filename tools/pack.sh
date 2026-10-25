#!/bin/sh
# Package one HTP-1 add-on using the runtime layout expected by addonctl.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
ID=${1:-airplay}
ADDON="$ROOT/addons/$ID"
[ -d "$ADDON" ] || { echo "Unknown addon: $ID ($ADDON does not exist)" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "jq is required" >&2; exit 1; }
command -v sha256sum >/dev/null 2>&1 || { echo "sha256sum is required" >&2; exit 1; }
[ -f "$ADDON/addon.json" ] || { echo "Missing $ADDON/addon.json" >&2; exit 1; }
jq -e --arg id "$ID" '.id == $id and (.version | type == "string") and (.label | type == "string")' "$ADDON/addon.json" >/dev/null || {
  echo "Invalid manifest or manifest id/version/label mismatch for $ID" >&2; exit 1;
}
VERSION=$(jq -r '.version' "$ADDON/addon.json")
case "$VERSION" in *[!0-9A-Za-z.+-]*|'') echo "Invalid version: $VERSION" >&2; exit 1 ;; esac
# BUILD_OUTPUT points to the build recipe's staged ARM binaries. For AirPlay,
# this is normally addons/airplay/build/build-output or the CI output directory.
BUILD_OUTPUT=${BUILD_OUTPUT:-"$ADDON/build/build-output"}
STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT HUP INT TERM
PKG="$STAGE/$ID"
mkdir -p "$PKG"
cp "$ADDON/addon.json" "$PKG/addon.json"
# Copy only recognized runtime directories. Development files such as build/
# and README files are intentionally not shipped.
for dir in bin etc units debs hooks flows state www; do
  if [ -d "$ADDON/$dir" ]; then cp -a "$ADDON/$dir" "$PKG/$dir"; fi
done
if [ "$ID" = airplay ]; then
  [ -x "$BUILD_OUTPUT/shairport-sync" ] || { echo "Missing $BUILD_OUTPUT/shairport-sync; run addons/airplay/build/build.sh first" >&2; exit 1; }
  [ -x "$BUILD_OUTPUT/nqptp" ] || { echo "Missing $BUILD_OUTPUT/nqptp; run addons/airplay/build/build.sh first" >&2; exit 1; }
  mkdir -p "$PKG/bin"
  install -m 0755 "$BUILD_OUTPUT/shairport-sync" "$PKG/bin/shairport-sync"
  install -m 0755 "$BUILD_OUTPUT/nqptp" "$PKG/bin/nqptp"
  if [ -d "$BUILD_OUTPUT/lib" ]; then
    mkdir -p "$PKG/lib"
    cp -a "$BUILD_OUTPUT/lib/." "$PKG/lib/"
  fi
fi
# Ensure shell hooks and helper executables retain executable permissions.
for dir in bin hooks; do
  if [ -d "$PKG/$dir" ]; then
    find "$PKG/$dir" -type f \( -name start -o -name volume -o -name install -o -name uninstall -o -name pre-upgrade -o -name post-update -o -name boot \) -exec chmod 0755 {} \;
  fi
done
# Manifest-declared units must exist in the package.
jq -r '.units // {} | keys[]' "$PKG/addon.json" | while IFS= read -r unit; do
  [ -f "$PKG/units/$unit" ] || { echo "Manifest declares missing unit: $unit" >&2; exit 1; }
done
# AirPlay's callback scripts are part of its source/1 integration.
if [ "$ID" = airplay ]; then
  [ -x "$PKG/bin/start" ] || { echo "Missing executable bin/start" >&2; exit 1; }
  [ -x "$PKG/bin/volume" ] || { echo "Missing executable bin/volume" >&2; exit 1; }
fi
OUT="$ROOT/dist"
mkdir -p "$OUT"
ARCHIVE="$OUT/htp1-addon-$ID-$VERSION.tar.gz"
tar -czf "$ARCHIVE" -C "$STAGE" "$ID"
# Verify single top-level directory and required manifest before reporting success.
LIST="$STAGE/archive-list.txt"
tar -tzf "$ARCHIVE" > "$LIST"
grep -Fxq "$ID/addon.json" "$LIST"
if grep -Eq '(^|/)(build|build-output|tests)/|README\.md$' "$LIST"; then
  echo "Package contains development-only files" >&2; exit 1
fi
(cd "$OUT" && sha256sum "$(basename "$ARCHIVE")" > SHA256SUMS)
echo "Created $ARCHIVE"
cat "$OUT/SHA256SUMS"
