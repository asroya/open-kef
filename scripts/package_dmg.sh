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
hdiutil create -quiet -volname "OpenKef $VERSION" -srcfolder "$STAGE" -ov -format UDZO "$DMG"
rm -rf "$STAGE"
echo "dmg: $DMG"
