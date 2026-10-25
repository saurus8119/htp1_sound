
#!/usr/bin/env bash
set -Eeuo pipefail

# HTP-1 AirPlay add-on packager.
# Usage: BUILD_OUTPUT=/path/to/build-output bash tools/pack.sh airplay

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
ID="${1:-airplay}"
ADDON="$ROOT/addons/$ID"
BUILD_OUTPUT="${BUILD_OUTPUT:-$ROOT/addons/$ID/build/build-output}"
OUT="$ROOT/dist"

die() {
    echo "ERROR: $*" >&2
    exit 1
}

command -v jq >/dev/null 2>&1 || die "jq is required"
command -v tar >/dev/null 2>&1 || die "tar is required"
command -v sha256sum >/dev/null 2>&1 || die "sha256sum is required"

[[ -d "$ADDON" ]] || die "Add-on directory not found: $ADDON"
[[ -f "$ADDON/addon.json" ]] || die "Missing addon.json"

jq -e \
    --arg id "$ID" \
    '.id == $id and (.version | type == "string") and (.version | length > 0)' \
    "$ADDON/addon.json" >/dev/null \
    || die "Invalid addon.json or manifest ID mismatch"

VERSION="$(jq -r '.version' "$ADDON/addon.json")"
ARCHIVE="$OUT/htp1-addon-$ID-$VERSION.tar.gz"

# Required compiled binaries for the AirPlay add-on.
if [[ "$ID" == "airplay" ]]; then
    [[ -x "$BUILD_OUTPUT/shairport-sync" ]] \
        || die "Missing executable: $BUILD_OUTPUT/shairport-sync"
    [[ -x "$BUILD_OUTPUT/nqptp" ]] \
        || die "Missing executable: $BUILD_OUTPUT/nqptp"
fi

mkdir -p "$OUT"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

PKG="$STAGE/$ID"
mkdir -p "$PKG"

# Copy manifest and supported runtime directories only.
cp "$ADDON/addon.json" "$PKG/"

for DIR in bin etc units debs hooks flows state www; do
    if [[ -d "$ADDON/$DIR" ]]; then
        cp -a "$ADDON/$DIR" "$PKG/$DIR"
    fi
done

# Include the ARM binaries produced by the build step.
if [[ "$ID" == "airplay" ]]; then
    mkdir -p "$PKG/bin"
    install -m 0755 "$BUILD_OUTPUT/shairport-sync" \
        "$PKG/bin/shairport-sync"
    install -m 0755 "$BUILD_OUTPUT/nqptp" \
        "$PKG/bin/nqptp"

    if [[ -d "$BUILD_OUTPUT/lib" ]]; then
        mkdir -p "$PKG/lib"
        cp -a "$BUILD_OUTPUT/lib/." "$PKG/lib/"
    fi

    [[ -f "$PKG/bin/start" ]] || die "Missing addons/airplay/bin/start"
    [[ -f "$PKG/bin/volume" ]] || die "Missing addons/airplay/bin/volume"

    chmod 0755 "$PKG/bin/start" "$PKG/bin/volume"
fi

# Ensure packaged lifecycle hooks are executable.
for HOOK in install uninstall pre-upgrade post-update boot; do
    if [[ -f "$PKG/hooks/$HOOK" ]]; then
        chmod 0755 "$PKG/hooks/$HOOK"
    fi
done

# Validate manifest-declared systemd units.
while IFS= read -r UNIT; do
    [[ -n "$UNIT" ]] || continue
    [[ -f "$PKG/units/$UNIT" ]] \
        || die "Manifest declares missing unit: $UNIT"
done < <(jq -r '.units // {} | keys[]' "$PKG/addon.json")

# Create the archive with exactly one top-level add-on directory.
tar -czf "$ARCHIVE" -C "$STAGE" "$ID"

# Verify the archive structure and required files.
LIST="$STAGE/archive-list.txt"
tar -tzf "$ARCHIVE" > "$LIST"

grep -Fxq "$ID/addon.json" "$LIST" \
    || die "Archive is missing $ID/addon.json"

if [[ "$ID" == "airplay" ]]; then
    grep -Fxq "$ID/bin/shairport-sync" "$LIST" \
        || die "Archive is missing shairport-sync"
    grep -Fxq "$ID/bin/nqptp" "$LIST" \
        || die "Archive is missing nqptp"
    grep -Fxq "$ID/units/airplay.service" "$LIST" \
        || die "Archive is missing airplay.service"
    grep -Fxq "$ID/units/nqptp.service" "$LIST" \
        || die "Archive is missing nqptp.service"
fi

if grep -Eq '(^|/)(build|build-output|tests)/|README\.md$' "$LIST"; then
    die "Archive contains development files that should not be packaged"
fi

# Write the checksum file.
(
    cd "$OUT"
    sha256sum "$(basename "$ARCHIVE")" > SHA256SUMS
)

echo "Package created: $ARCHIVE"
echo "Checksum:"
cat "$OUT/SHA256SUMS"
