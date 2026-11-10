#!/bin/sh
# Publish Caldera's own Plex PIN instructions for the add-on page.
set -eu

ADDON_DIR="/var/lib/olympia/addons/caldera"
STATE_DIR="$ADDON_DIR/state"
CONFIG_FILE="$STATE_DIR/.config/caldera-music"
CALDERA="$ADDON_DIR/bin/caldera-music.bin"
WWW_DIR="$ADDON_DIR/www"
TMP_FILE="$WWW_DIR/.auth.txt.tmp"
AUTH_FILE="$WWW_DIR/auth.txt"

mkdir -p "$WWW_DIR"

TOKEN=""
if [ -x "$CALDERA" ]; then
    TOKEN=$("$CALDERA" --config "$CONFIG_FILE" --get plex.token 2>/dev/null || true)
fi

if [ -n "$TOKEN" ] && [ "$TOKEN" != "null" ] && [ "$TOKEN" != '""' ]; then
    printf '%s\n' "Plex authorization is saved. No sign-in is required." > "$TMP_FILE"
elif command -v journalctl >/dev/null 2>&1; then
    journalctl --no-pager --quiet -o cat -n 120 -u caldera.service 2>/dev/null |
        grep -Ei 'Plex sign-in|plex\.tv/link|Enter code:|Waiting for authorization|Authenticated as|Signed in to Plex|Authentication timed out|Failed to get PIN|PIN request failed|PIN check failed|output.device|Output Device|System Default|Cannot start Caldera PIN sign-in|No auth token|re-run --login' > "$TMP_FILE" || true
    if [ ! -s "$TMP_FILE" ]; then
        printf '%s\n' "Waiting for Caldera to start Plex sign-in…" > "$TMP_FILE"
    fi
else
    printf '%s\n' "Waiting for Caldera to start Plex sign-in…" > "$TMP_FILE"
fi

chmod 0644 "$TMP_FILE"
mv -f "$TMP_FILE" "$AUTH_FILE"
