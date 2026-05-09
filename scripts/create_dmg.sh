#!/bin/bash
set -euo pipefail

APP_NAME="Rolume"
VOLUME_NAME="Rolume"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ASSETS_DIR="$SCRIPT_DIR/dmg-assets"
BACKGROUND_NAME="background.png"
DEFAULT_APP_PATH="$PROJECT_ROOT/build/Release/$APP_NAME.app"
DEFAULT_OUTPUT_PATH="$PROJECT_ROOT/$APP_NAME.dmg"
WINDOW_X=120
WINDOW_Y=120
WINDOW_WIDTH=960
WINDOW_HEIGHT=540
APP_ICON_X=200
APP_ICON_Y=260
APPLICATIONS_ICON_X=760
APPLICATIONS_ICON_Y=260
ICON_SIZE=128
TEXT_SIZE=14

APP_PATH="${1:-$DEFAULT_APP_PATH}"
OUTPUT_DMG="${2:-$DEFAULT_OUTPUT_PATH}"
TEMP_DIR="$(mktemp -d)"
STAGING_DIR="$TEMP_DIR/staging"
RW_DMG="$TEMP_DIR/$APP_NAME-temp.dmg"
MOUNT_DIR=""

cleanup() {
    if [ -n "$MOUNT_DIR" ] && mount | grep -q "$MOUNT_DIR"; then
        hdiutil detach "$MOUNT_DIR" -quiet || true
    fi
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

if [ ! -d "$APP_PATH" ]; then
    echo "App not found: $APP_PATH"
    echo "Usage: $0 /path/to/$APP_NAME.app [/path/to/output.dmg]"
    exit 1
fi

mkdir -p "$STAGING_DIR"
mkdir -p "$(dirname "$OUTPUT_DMG")"
rm -f "$OUTPUT_DMG"
cp -R "$APP_PATH" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

if [ -f "$ASSETS_DIR/$BACKGROUND_NAME" ]; then
    mkdir -p "$STAGING_DIR/.background"
    cp "$ASSETS_DIR/$BACKGROUND_NAME" "$STAGING_DIR/.background/$BACKGROUND_NAME"
fi

hdiutil create \
    -volname "$VOLUME_NAME" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -fs HFS+ \
    -format UDRW \
    "$RW_DMG" >/dev/null

ATTACH_OUTPUT="$(hdiutil attach "$RW_DMG" -readwrite -noverify -noautoopen)"
MOUNT_DIR="$(printf '%s\n' "$ATTACH_OUTPUT" | awk '/\/Volumes\// {print $NF; exit}')"

if [ -z "$MOUNT_DIR" ] || [ ! -d "$MOUNT_DIR" ]; then
    echo "Failed to mount DMG"
    printf '%s\n' "$ATTACH_OUTPUT"
    exit 1
fi

sleep 1
if [ -d "$MOUNT_DIR/.background" ]; then
    /usr/bin/SetFile -a V "$MOUNT_DIR/.background" || true
fi

/usr/bin/osascript <<EOF
 tell application "Finder"
     tell disk "$VOLUME_NAME"
         open
         set theWindow to container window
         set current view of theWindow to icon view
         set toolbar visible of theWindow to false
         set statusbar visible of theWindow to false
         set bounds of theWindow to {$WINDOW_X, $WINDOW_Y, $((WINDOW_X + WINDOW_WIDTH)), $((WINDOW_Y + WINDOW_HEIGHT))}
         set theViewOptions to the icon view options of theWindow
         set arrangement of theViewOptions to not arranged
         set icon size of theViewOptions to $ICON_SIZE
         set text size of theViewOptions to $TEXT_SIZE
         if exists POSIX file "$MOUNT_DIR/.background/$BACKGROUND_NAME" then
             set background picture of theViewOptions to (POSIX file "$MOUNT_DIR/.background/$BACKGROUND_NAME" as alias)
         end if
         set position of item "$APP_NAME.app" of theWindow to {$APP_ICON_X, $APP_ICON_Y}
         set position of item "Applications" of theWindow to {$APPLICATIONS_ICON_X, $APPLICATIONS_ICON_Y}
         update without registering applications
         delay 1
         close theWindow
     end tell
 end tell
EOF

chmod -Rf go-w "$MOUNT_DIR"
sync
hdiutil detach "$MOUNT_DIR" -quiet

hdiutil convert "$RW_DMG" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "$OUTPUT_DMG" >/dev/null

echo "Created DMG: $OUTPUT_DMG"
