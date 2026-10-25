#!/bin/sh
# Build the firmware-installable archive from the staged addon tree.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
ADDON="$ROOT/addons/airplay"
OUT=${OUT:-"$ROOT/dist"}
command -v jq >/dev/null 2>&1 || { echo "Missing required command: jq" >&2; exit 1; }
command -v tar >/dev/null 2>&1 || { echo "Missing required command: tar" >&2; exit 1; }
command -v sha256sum >/dev/null 2>&1 || { echo "Missing required command: sha256sum" >&2; exit 1; }

jq -e '
  .id == "airplay" and
  (.version | type == "string" and test("^[0-9]+\\.[0-9]+\\.[0-9]+(-[0-9A-Za-z.-]+)?(\\+[0-9A-Za-z.-]+)?$")) and
  .units["airplay.service"] == "link" and
  .units["nqptp.service"] == "link" and
  .service.unit == "airplay.service" and
  .input.code == "airplay" and
  (.requires.capabilities | index("source/1") != null)
' "$ADDON/addon.json" >/dev/null || { echo "addon.json failed required AirPlay manifest checks" >&2; exit 1; }
VERSION=$(jq -r '.version' "$ADDON/addon.json")
for file in bin/start bin/volume bin/shairport-sync bin/nqptp etc/shairport-sync.conf units/airplay.service units/nqptp.service; do
  [ -f "$ADDON/$file" ] || { echo "Missing required runtime file: addons/airplay/$file" >&2; exit 1; }
done
for file in bin/start bin/volume bin/shairport-sync bin/nqptp; do
  [ -x "$ADDON/$file" ] || { echo "Required runtime file is not executable: addons/airplay/$file" >&2; exit 1; }
done

mkdir -p "$OUT"
STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT HUP INT TERM
mkdir -p "$STAGE/airplay"
cp "$ADDON/addon.json" "$STAGE/airplay/"
cp -a "$ADDON/bin" "$ADDON/etc" "$ADDON/units" "$STAGE/airplay/"
[ ! -d "$ADDON/lib" ] || cp -a "$ADDON/lib" "$STAGE/airplay/"
ARCHIVE="$OUT/htp1-addon-airplay-$VERSION.tar.gz"
tar -czf "$ARCHIVE" -C "$STAGE" airplay
LIST="$STAGE/archive-list.txt"
tar -tzf "$ARCHIVE" > "$LIST"
for path in airplay/addon.json airplay/bin/start airplay/bin/volume airplay/bin/shairport-sync airplay/bin/nqptp airplay/etc/shairport-sync.conf airplay/units/airplay.service airplay/units/nqptp.service; do
  grep -Fxq "$path" "$LIST" || { echo "Archive missing required path: $path" >&2; exit 1; }
done
if grep -Eq '(^/|(^|/)\.\.(/|$)|(^|/)build(/|$))' "$LIST"; then
  echo "Archive contains an unsafe or development-only path" >&2; exit 1
fi
sha256sum "$ARCHIVE" > "$OUT/SHA256SUMS"
echo "Created $ARCHIVE"
echo "SHA-256: $(awk '{print $1}' "$OUT/SHA256SUMS")"
