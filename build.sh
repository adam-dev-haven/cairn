#!/bin/bash
# Builds Cairn.app — a self-contained macOS app bundle, ad-hoc signed.
# Needs the Command Line Tools; nothing else.
set -euo pipefail

cd "$(dirname "$0")"
ROOT="$(pwd)"
APP="$ROOT/Cairn.app"
CONFIG="${1:-release}"
# Reverse-DNS id for the bundle. Override it to use your own: CAIRN_BUNDLE_ID=com.yourname.cairn ./build.sh
BUNDLE_ID="${CAIRN_BUNDLE_ID:-com.example.cairn}"

echo "==> Building ($CONFIG)"
swift build -c "$CONFIG" --arch arm64

BIN="$ROOT/.build/$CONFIG/Cairn"
[ -x "$BIN" ] || { echo "build produced no binary at $BIN"; exit 1; }

echo "==> Generating icon"
ICONSET="$ROOT/.build/AppIcon.iconset"
rm -rf "$ICONSET"
"$BIN" --iconset "$ICONSET" >/dev/null
iconutil -c icns "$ICONSET" -o "$ROOT/.build/AppIcon.icns"

echo "==> Assembling bundle"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Cairn"
cp "$ROOT/.build/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
# Exercise photos (flat files, found by name at runtime). The same folder is what the iPhone build bundles.
if [ -d "$ROOT/ios/Resources/photos" ]; then
    cp "$ROOT/ios/Resources/photos/"*.jpg "$APP/Contents/Resources/"
fi

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>               <string>Cairn</string>
    <key>CFBundleDisplayName</key>        <string>Cairn</string>
    <key>CFBundleExecutable</key>         <string>Cairn</string>
    <key>CFBundleIdentifier</key>         <string>$BUNDLE_ID</string>
    <key>CFBundlePackageType</key>        <string>APPL</string>
    <key>CFBundleShortVersionString</key> <string>1.0</string>
    <key>CFBundleVersion</key>            <string>1</string>
    <key>CFBundleIconFile</key>           <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>     <string>14.0</string>
    <key>NSHighResolutionCapable</key>    <true/>
    <key>NSPrincipalClass</key>           <string>NSApplication</string>
    <key>LSApplicationCategoryType</key>  <string>public.app-category.healthcare-fitness</string>
    <key>NSLocalNetworkUsageDescription</key> <string>Cairn syncs with Cairn on your iPhone over your home Wi-Fi.</string>
    <key>NSBonjourServices</key>          <array><string>_cairn._tcp</string></array>
    <key>NSAppTransportSecurity</key>
    <dict><key>NSAllowsLocalNetworking</key><true/></dict>
</dict>
</plist>
PLIST

printf 'APPL????' > "$APP/Contents/PkgInfo"

echo "==> Signing (ad-hoc)"
codesign --force --deep --sign - "$APP"
codesign --verify --deep --strict "$APP" && echo "    signature ok"

echo
echo "Built $APP"
echo "Run it with:  open '$APP'"
