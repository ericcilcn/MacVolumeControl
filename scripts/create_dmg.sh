#!/bin/bash
set -euo pipefail

APP_NAME="MacVolumeControl"
VOLUME_NAME="MacVolumeControl"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ASSETS_DIR="$SCRIPT_DIR/dmg-assets"
BACKGROUND_NAME="background.png"
DEFAULT_APP_PATH="$PROJECT_ROOT/build/Release/$APP_NAME.app"
DEFAULT_OUTPUT_PATH="$PROJECT_ROOT/$APP_NAME.dmg"

APP_PATH="${1:-$DEFAULT_APP_PATH}"
OUTPUT_DMG="${2:-$DEFAULT_OUTPUT_PATH}"
TEMP_DIR="$(mktemp -d)"
STAGING_DIR="$TEMP_DIR/staging"
RW_DMG="$TEMP_DIR/$APP_NAME-temp.dmg"
MOUNT_DIR="$TEMP_DIR/mount"

cleanup() {
    if mount | grep -q "$MOUNT_DIR"; then
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
    -fs APFS \
    -format UDRW \
    "$RW_DMG" >/dev/null

mkdir -p "$MOUNT_DIR"
hdiutil attach "$RW_DMG" -mountpoint "$MOUNT_DIR" -nobrowse -quiet

sleep 1
/usr/bin/osascript <<EOF >/dev/null 2>&1 || true
 tell application "Finder"
     tell disk "$VOLUME_NAME"
         open
         set current view of container window to icon view
         set toolbar visible of container window to false
         set statusbar visible of container window to false
         set bounds of container window to {120, 120, 1080, 660}
         set theViewOptions to the icon view options of container window
         set arrangement of theViewOptions to not arranged
         set icon size of theViewOptions to 112
         set text size of theViewOptions to 16
         if exists file ".background:$BACKGROUND_NAME" of container window then
             set background picture of theViewOptions to file ".background:$BACKGROUND_NAME"
         end if
         set position of item "$APP_NAME.app" of container window to {200, 290}
         set position of item "Applications" of container window to {760, 290}
         close
         open
         update without registering applications
         delay 1
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
