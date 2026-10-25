#!/bin/sh
# Generate the repository catalog for a release tag after package archives exist in dist/.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TAG=${1:-}
[ -n "$TAG" ] || { echo "Usage: tools/index.sh vX.Y.Z" >&2; exit 2; }
case "$TAG" in v*) VERSION=${TAG#v} ;; *) echo "Tag must start with v (example: v0.1.0)" >&2; exit 2 ;; esac
command -v jq >/dev/null 2>&1 || { echo "jq is required" >&2; exit 1; }
command -v sha256sum >/dev/null 2>&1 || { echo "sha256sum is required" >&2; exit 1; }
command -v stat >/dev/null 2>&1 || { echo "stat is required" >&2; exit 1; }
DIST="$ROOT/dist"
TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT HUP INT TERM
UPDATED=$(date -u +'%Y-%m-%dT%H:%M:%SZ')
REPO=${GITHUB_REPOSITORY:-saurus8119/htp1-sound}
# Build the catalog from published manifests. Currently this repository has AirPlay only.
ITEMS='[]'
for MANIFEST in "$ROOT"/addons/*/addon.json; do
  [ -f "$MANIFEST" ] || continue
  ID=$(jq -r '.id' "$MANIFEST")
  PUBLISHED=$(jq -r 'if has("published") then .published else true end' "$MANIFEST")
  [ "$PUBLISHED" = true ] || continue
  ADDON_VERSION=$(jq -r '.version' "$MANIFEST")
  [ "$ADDON_VERSION" = "$VERSION" ] || { echo "$ID manifest version $ADDON_VERSION does not match tag $TAG" >&2; exit 1; }
  ARCHIVE="$DIST/htp1-addon-$ID-$ADDON_VERSION.tar.gz"
  [ -s "$ARCHIVE" ] || { echo "Missing release archive: $ARCHIVE" >&2; exit 1; }
  SHA=$(sha256sum "$ARCHIVE" | awk '{print $1}')
  SIZE=$(stat -c '%s' "$ARCHIVE")
  URL="https://github.com/$REPO/releases/download/$TAG/$(basename "$ARCHIVE")"
  ITEM=$(jq -n --slurpfile m "$MANIFEST" --arg url "$URL" --arg sha "$SHA" --argjson size "$SIZE" '{id:$m[0].id,version:$m[0].version,label:$m[0].label,summary:$m[0].summary,requires:($m[0].requires // {}),url:$url,sha256:$sha,size:$size}')
  ITEMS=$(jq --argjson item "$ITEM" '. + [$item]' <<EOF_ITEMS
$ITEMS
EOF_ITEMS
)
done
[ "$ITEMS" != '[]' ] || { echo "No published add-ons found" >&2; exit 1; }
jq -n --arg name "htp1-sound" --arg updated "$UPDATED" --argjson addons "$ITEMS" '{name:$name,updated:$updated,addons:$addons}' > "$TMP"
# Replace atomically after successful validation.
jq -e '.name and (.addons | type == "array" and length > 0)' "$TMP" >/dev/null
mv "$TMP" "$ROOT/index.json"
echo "Updated $ROOT/index.json for $TAG"
