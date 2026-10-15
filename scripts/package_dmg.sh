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

# Placeholder icon (flat tile) until Pixel Snob delivers the real one.
TMP=$(mktemp -d); ICONSET="$TMP/AppIcon.iconset"; mkdir "$ICONSET"
python3 - "$TMP/base.png" <<'PY'
import sys, zlib, struct
n=1024; row=b"\x00"+bytes([28,28,30])*n
def chunk(t,d): return struct.pack(">I",len(d))+t+d+struct.pack(">I",zlib.crc32(t+d)&0xffffffff)
png=b"\x89PNG\r\n\x1a\n"+chunk(b"IHDR",struct.pack(">IIBBBBB",n,n,8,2,0,0,0))+chunk(b"IDAT",zlib.compress(row*n,9))+chunk(b"IEND",b"")
open(sys.argv[1],"wb").write(png)
PY
for s in 16 32 128 256 512; do
  sips -z $s $s "$TMP/base.png" --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
  d=$((s*2)); sips -z $d $d "$TMP/base.png" --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
rm -rf "$TMP"

codesign --force --deep -s - "$APP"
ln -s /Applications "$STAGE/Applications"
hdiutil create -quiet -volname "OpenKef $VERSION" -srcfolder "$STAGE" -ov -format UDZO "$DMG"
rm -rf "$STAGE"
echo "dmg: $DMG"
