#!/bin/sh
# Update index.json from the manifest and the exact release archive.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
ADDON="$ROOT/addons/airplay"
INDEX=${INDEX:-"$ROOT/index.json"}
DIST=${DIST:-"$ROOT/dist"}
REPOSITORY=${GITHUB_REPOSITORY:-}
RELEASE_TAG=${RELEASE_TAG:-}
UPDATED=$(date -u +'%Y-%m-%dT%H:%M:%SZ')
command -v jq >/dev/null 2>&1 || { echo "Missing required command: jq" >&2; exit 1; }
[ -n "$REPOSITORY" ] || REPOSITORY=$(git -C "$ROOT" remote get-url origin 2>/dev/null | sed -E 's#^https://github.com/##; s#^git@github.com:##; s#\.git$##' || true)
[ -n "$REPOSITORY" ] || { echo "Set GITHUB_REPOSITORY=owner/repo or configure the origin remote" >&2; exit 1; }
VERSION=$(jq -er '.version' "$ADDON/addon.json")
ID=$(jq -er '.id' "$ADDON/addon.json")
LABEL=$(jq -er '.label' "$ADDON/addon.json")
SUMMARY=$(jq -er '.summary' "$ADDON/addon.json")
[ -n "$RELEASE_TAG" ] || RELEASE_TAG="v$VERSION"
[ "$RELEASE_TAG" = "v$VERSION" ] || { echo "Release tag $RELEASE_TAG does not match manifest version $VERSION" >&2; exit 1; }
ARCHIVE="$DIST/htp1-addon-airplay-$VERSION.tar.gz"
[ -f "$ARCHIVE" ] || { echo "Missing release archive: $ARCHIVE (run tools/pack.sh first)" >&2; exit 1; }
SHA=$(sha256sum "$ARCHIVE" | awk '{print $1}')
SIZE=$(wc -c < "$ARCHIVE" | tr -d ' ')
URL="https://github.com/$REPOSITORY/releases/download/$RELEASE_TAG/htp1-addon-airplay-$VERSION.tar.gz"
if [ -f "$INDEX" ]; then
  jq -e '.name and (.addons | type == "array")' "$INDEX" >/dev/null || { echo "Existing catalog is invalid: $INDEX" >&2; exit 1; }
  jq --arg updated "$UPDATED" --arg id "$ID" --arg version "$VERSION" --arg url "$URL" --arg sha256 "$SHA" --arg label "$LABEL" --arg summary "$SUMMARY" --argjson size "$SIZE" \
    '.name = "htp1-sound" | .updated = $updated | .addons = ([.addons[]? | select(.id != $id)] + [{id:$id,version:$version,label:$label,summary:$summary,requires:{capabilities:["source/1"]},url:$url,sha256:$sha256,size:$size}])' \
    "$INDEX" > "$INDEX.tmp"
else
  jq -n --arg updated "$UPDATED" --arg id "$ID" --arg version "$VERSION" --arg url "$URL" --arg sha256 "$SHA" --arg label "$LABEL" --arg summary "$SUMMARY" --argjson size "$SIZE" \
    '{name:"htp1-sound",updated:$updated,addons:[{id:$id,version:$version,label:$label,summary:$summary,requires:{capabilities:["source/1"]},url:$url,sha256:$sha256,size:$size}]}' > "$INDEX.tmp"
fi
jq -e '.addons | all(.[]; (.id | type == "string") and (.version | type == "string") and (.sha256 | test("^[0-9a-f]{64}$")) and (.size | type == "number" and . > 0) and (.url | type == "string"))' "$INDEX.tmp" >/dev/null
mv "$INDEX.tmp" "$INDEX"
echo "Updated $INDEX for $ID $VERSION"
echo "URL: $URL"
echo "SHA-256: $SHA"
echo "Size: $SIZE bytes"
