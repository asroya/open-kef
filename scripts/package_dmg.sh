#!/bin/sh
# MET-9: build OpenKef.app and an unsigned (ad-hoc signed) UDZO dmg. Built-in macOS tools only.
# Output: dist/OpenKef-$VERSION.dmg
set -eu
ROOT=$(cd "$(dirname "$0")/.." && pwd)
VERSION=${VERSION:-0.1.0}
BUNDLE_ID=io.github.asroya.openkef
DIST="$ROOT/dist"; STAGE="$DIST/stage"; APP="$STAGE/OpenKef.app"
DMG="$DIST/OpenKef-$VERSION.dmg"

BIN=$("$ROOT/apps/macos/build.sh" | sed -n 's/^built: //p' | tail -1)
[ -x "$BIN" ] || { echo "build failed: no binary" >&2; exit 1; }

rm -rf "$STAGE" "$DMG"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/OpenKef"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>OpenKef</string>
  <key>CFBundleDisplayName</key><string>open-kef</string>
  <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
  <key>CFBundleExecutable</key><string>OpenKef</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSLocalNetworkUsageDescription</key><string>open-kef finds and controls your KEF speakers on your local network.</string>
  <key>NSBonjourServices</key><array><string>_kef-info._tcp</string></array>
</dict>
</plist>
PLIST
plutil -lint "$APP/Contents/Info.plist"

# App icon: Pixel Snob's ruler motif, built from the committed iconset.
ICONSET="$ROOT/design/assets/icon/AppIcon.iconset"
[ -d "$ICONSET" ] || { echo "missing $ICONSET" >&2; exit 1; }
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

codesign --force --deep -s - "$APP"
ln -s /Applications "$STAGE/Applications"

# Styled window without create-dmg: read-write image -> Finder layout via AppleScript -> UDZO.
# Background: 1x + @2x combined into one HiDPI TIFF (tiffutil, built in). Layout per design/assets/README.md.
VOL="OpenKef $VERSION"; RW="$DIST/rw.dmg"; BG="$ROOT/design/assets/dmg"
mkdir -p "$STAGE/.background"
tiffutil -cathidpicheck "$BG/dmg-background.png" "$BG/dmg-background@2x.png" -out "$STAGE/.background/background.tiff" >/dev/null
rm -f "$RW"
hdiutil create -quiet -volname "$VOL" -srcfolder "$STAGE" -fs HFS+ -format UDRW -ov "$RW"
# Unique mountpoint: never /Volumes/<name>, which collides with an already-mounted "OpenKef x.y.z".
MNT=$(mktemp -d "${TMPDIR:-/tmp}/openkef-dmg.XXXXXX")
cleanup() { if mount | grep -q " on $MNT "; then hdiutil detach -force -quiet "$MNT" || true; fi; rmdir "$MNT" 2>/dev/null || true; }
trap cleanup EXIT INT TERM
hdiutil attach -quiet -readwrite -noverify -noautoopen -nobrowse -mountpoint "$MNT" "$RW"
[ -d "$MNT/OpenKef.app" ] || { echo "attach failed" >&2; exit 1; }
# Finder needs the GUI session; SKIP_FINDER=1 builds an unstyled dmg instead.
if [ "${SKIP_FINDER:-0}" != 1 ]; then
osascript <<OSA
set f to POSIX file "$MNT" as alias
tell application "Finder"
  -- Finder may not see a fresh mount yet: wait up to ~10 s.
  repeat 20 times
    if exists folder f then exit repeat
    delay 0.5
  end repeat
  tell folder f
    open
    set w to container window
    set current view of w to icon view
    set toolbar visible of w to false
    set statusbar visible of w to false
    set bounds of w to {200, 120, 860, 520}
    set o to icon view options of w
    set arrangement of o to not arranged
    set icon size of o to 128
    set text size of o to 13
    set background picture of o to file ".background:background.tiff"
    set position of item "OpenKef.app" of w to {170, 200}
    set position of item "Applications" of w to {490, 200}
    update without registering applications
    delay 1
    close
  end tell
end tell
OSA
fi
chmod -Rf go-w "$MNT" || true
sync
hdiutil detach -quiet "$MNT" || { sleep 2; hdiutil detach -force -quiet "$MNT"; }
rmdir "$MNT" 2>/dev/null || true
hdiutil convert -quiet "$RW" -format UDZO -imagekey zlib-level=9 -ov -o "$DMG"
rm -rf "$STAGE" "$RW"
echo "dmg: $DMG"
