#!/bin/sh
# Local build path: compile, stage into the canonical addon tree, then package.
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT=$(CDPATH= cd -- "$HERE/../../.." && pwd)
OUT=${OUT:-"$HERE/build-output"}
mkdir -p "$OUT" "$OUT/work"
docker build --platform linux/arm/v7 -t htp1-airplay-build "$HERE"
docker run --rm --platform linux/arm/v7 --entrypoint /bin/sh \
  -v "$OUT:/out" -v "$OUT/work:/work" htp1-airplay-build \
  -c 'exec /usr/local/bin/build-target'
install -d "$ROOT/addons/airplay/bin" "$ROOT/addons/airplay/lib"
install -m 0755 "$OUT/shairport-sync" "$ROOT/addons/airplay/bin/shairport-sync"
install -m 0755 "$OUT/nqptp" "$ROOT/addons/airplay/bin/nqptp"
cp -a "$OUT/lib/." "$ROOT/addons/airplay/lib/"
mkdir -p "$ROOT/dist"
for report in "$OUT"/*-report.txt "$OUT"/*-ldd.txt "$OUT"/*-version.txt "$OUT"/BUILD-REPORT.txt; do
  [ -f "$report" ] && cp "$report" "$ROOT/dist/"
done
"$ROOT/tools/pack.sh"
echo "Local package and diagnostics are under $ROOT/dist/"
