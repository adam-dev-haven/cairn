#!/bin/bash
# Builds Cairn.ipa for sideloading with AltStore / SideStore.
# AltStore re-signs the app with your Apple ID when it installs it, so the
# .ipa here is only ad-hoc signed. Needs Xcode (for the iOS SDK and actool).
set -euo pipefail

cd "$(dirname "$0")"
ROOT="$(pwd)"
BUNDLE_ID="${CAIRN_BUNDLE_ID:-com.example.cairn}"
# ./build-ios.sh        → Cairn.ipa for the phone
# ./build-ios.sh --sim  → .build/ios-sim/Payload/Cairn.app for the simulator
if [ "${1:-}" = "--sim" ]; then
    PLATFORM="iphonesimulator"; TRIPLE="arm64-apple-ios17.0-simulator"; OUT="$ROOT/.build/ios-sim"; SUPPORTED="iPhoneSimulator"
else
    PLATFORM="iphoneos"; TRIPLE="arm64-apple-ios17.0"; OUT="$ROOT/.build/ios"; SUPPORTED="iPhoneOS"
fi
SDK="$(xcrun --sdk $PLATFORM --show-sdk-path)"
APP="$OUT/Payload/Cairn.app"

echo "==> Building for iOS (release)"
swift build -c release --triple "$TRIPLE" --sdk "$SDK"
BIN="$(swift build -c release --triple "$TRIPLE" --sdk "$SDK" --show-bin-path)/Cairn"
[ -x "$BIN" ] || { echo "no iOS binary at $BIN"; exit 1; }

echo "==> Icon"
swift build -c release --arch arm64 >/dev/null
rm -rf "$OUT"; mkdir -p "$APP" "$OUT/Assets.xcassets/AppIcon.appiconset"
"$ROOT/.build/release/Cairn" --ios-icon "$OUT/Assets.xcassets/AppIcon.appiconset/icon-1024.png" >/dev/null
cat > "$OUT/Assets.xcassets/Contents.json" <<'JSON'
{ "info" : { "author" : "xcode", "version" : 1 } }
JSON
cat > "$OUT/Assets.xcassets/AppIcon.appiconset/Contents.json" <<'JSON'
{ "images" : [ { "filename" : "icon-1024.png", "idiom" : "universal", "platform" : "ios", "size" : "1024x1024" } ],
  "info" : { "author" : "xcode", "version" : 1 } }
JSON
xcrun actool "$OUT/Assets.xcassets" --compile "$APP" --platform $PLATFORM --minimum-deployment-target 17.0 \
    --app-icon AppIcon --output-partial-info-plist "$OUT/icon-partial.plist" --target-device iphone >/dev/null

echo "==> Assembling Cairn.app"
cp "$BIN" "$APP/Cairn"
SDKVER="$(xcrun --sdk $PLATFORM --show-sdk-version)"
cat > "$APP/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>                 <string>Cairn</string>
    <key>CFBundleDisplayName</key>          <string>Cairn</string>
    <key>CFBundleExecutable</key>           <string>Cairn</string>
    <key>CFBundleIdentifier</key>           <string>$BUNDLE_ID.ios</string>
    <key>CFBundlePackageType</key>          <string>APPL</string>
    <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
    <key>CFBundleShortVersionString</key>   <string>1.0</string>
    <key>CFBundleVersion</key>              <string>$(date +%Y%m%d%H%M)</string>
    <key>CFBundleSupportedPlatforms</key>   <array><string>$SUPPORTED</string></array>
    <key>DTPlatformName</key>               <string>$PLATFORM</string>
    <key>DTSDKName</key>                    <string>$PLATFORM$SDKVER</string>
    <key>MinimumOSVersion</key>             <string>17.0</string>
    <key>LSRequiresIPhoneOS</key>           <true/>
    <key>UIDeviceFamily</key>               <array><integer>1</integer></array>
    <key>UIRequiredDeviceCapabilities</key> <array><string>arm64</string></array>
    <key>UILaunchScreen</key>               <dict><key>UIColorName</key><string></string></dict>
    <key>UIApplicationSupportsIndirectInputEvents</key><true/>
    <key>UIUserInterfaceStyle</key>         <string>Light</string>
    <key>UISupportedInterfaceOrientations</key><array><string>UIInterfaceOrientationPortrait</string></array>
    <key>NSLocalNetworkUsageDescription</key><string>Cairn syncs with Cairn on your Mac over your home Wi-Fi.</string>
    <key>NSBonjourServices</key>            <array><string>_cairn._tcp</string></array>
    <key>CFBundleIcons</key>
    <dict><key>CFBundlePrimaryIcon</key><dict>
        <key>CFBundleIconName</key><string>AppIcon</string>
        <key>CFBundleIconFiles</key><array><string>AppIcon60x60</string></array>
    </dict></dict>
</dict>
</plist>
PLIST
plutil -lint "$APP/Info.plist" >/dev/null
printf 'APPL????' > "$APP/PkgInfo"

echo "==> Signing (ad-hoc; AltStore re-signs on install)"
codesign --force --sign - --timestamp=none "$APP"

if [ "$PLATFORM" = "iphonesimulator" ]; then
    echo; echo "Built $APP"; exit 0
fi

echo "==> Packaging"
rm -f "$ROOT/Cairn.ipa"
(cd "$OUT" && zip -qry "$ROOT/Cairn.ipa" Payload)
ls -lh "$ROOT/Cairn.ipa" | awk '{print "    " $5 "  " $9}'
echo
echo "Built $ROOT/Cairn.ipa — open it with AltStore on the Mac, or AirDrop it to the phone and open in AltStore."
