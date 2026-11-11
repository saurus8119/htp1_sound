#!/bin/sh
# Publish HTPlex's Plex sign-in status for the add-on page.
set -eu

ADDON_DIR="/var/lib/olympia/addons/caldera"
STATE_DIR="$ADDON_DIR/state"
CONFIG_FILE="$STATE_DIR/.config/caldera-music"
LOGIN_LOG="$STATE_DIR/caldera-login.typescript"
CALDERA="$ADDON_DIR/bin/caldera-music.bin"
LOADER="$ADDON_DIR/lib/ld-linux-armhf.so.3"
WWW_DIR="$ADDON_DIR/www"
TMP_FILE="$WWW_DIR/.auth.txt.tmp"
AUTH_FILE="$WWW_DIR/auth.txt"

mkdir -p "$WWW_DIR"

TOKEN=""
if [ -x "$CALDERA" ] && [ -x "$LOADER" ]; then
    TOKEN=$("$LOADER" --library-path "$ADDON_DIR/lib" "$CALDERA" --config "$CONFIG_FILE" --get plex.token 2>/dev/null || true)
fi

if [ -n "$TOKEN" ] && [ "$TOKEN" != "null" ] && [ "$TOKEN" != '\"\"' ]; then
    printf '%s\n' "Plex authorization is saved. No sign-in is required." > "$TMP_FILE"
elif [ -s "$LOGIN_LOG" ]; then
    tr -d '\r' < "$LOGIN_LOG" | tail -n 100 > "$TMP_FILE"
    if [ ! -s "$TMP_FILE" ]; then
        printf '%s\n' "Waiting for HTPlex to provide the Plex PIN…" > "$TMP_FILE"
    fi
else
    printf '%s\n' "HTPlex Plex sign-in has not started yet." > "$TMP_FILE"
fi

chmod 0644 "$TMP_FILE"
mv -f "$TMP_FILE" "$AUTH_FILE"
