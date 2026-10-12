#!/bin/bash
# Builds Cairn with Xcode's signing (free Apple ID, Personal Team) and installs
# it on the plugged-in iPhone. Run it to install updates, and weekly to re-sign
# before the 7-day free-account signature runs out. Data on the phone is kept.
set -euo pipefail
cd "$(dirname "$0")"

# Your Apple Developer Team ID (Xcode → Settings → Accounts → your team; ten characters).
# A free Apple ID works; it just has to be the one signed in to Xcode.
TEAM="${CAIRN_TEAM_ID:?Set CAIRN_TEAM_ID to your Apple Developer Team ID, e.g. CAIRN_TEAM_ID=ABCDE12345 ./install-phone.sh}"
BUNDLE_ID="${CAIRN_BUNDLE_ID:-com.example.cairn}.ios"

DEVICE="$(xcrun devicectl list devices 2>/dev/null | awk '/physical/ && !/unavailable/ {for (i=1;i<=NF;i++) if ($i ~ /^[0-9A-F]{8}-[0-9A-F]{16}$/) print $i}' | head -1)"
[ -n "$DEVICE" ] || { echo "No iPhone found. Plug it in (or put it on the same Wi-Fi), unlock it, and try again."; exit 1; }
echo "==> iPhone $DEVICE"

echo "==> Building and signing"
xcodebuild -project ios/Cairn.xcodeproj -scheme Cairn -configuration Release \
    -destination "id=$DEVICE" -derivedDataPath .build/xcode-device \
    DEVELOPMENT_TEAM="$TEAM" PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID" \
    -allowProvisioningUpdates build -quiet

APP=".build/xcode-device/Build/Products/Release-iphoneos/Cairn.app"
SIGN="$(codesign -dvv "$APP" 2>&1)"; grep -q "Apple Development" <<<"$SIGN" || { echo "Not signed with the Apple Development certificate"; exit 1; }

echo "==> Installing"
xcrun devicectl device install app --device "$DEVICE" "$APP" >/dev/null
echo "==> Opening Cairn"
xcrun devicectl device process launch --device "$DEVICE" "$BUNDLE_ID" >/dev/null 2>&1 \
    || echo "Installed. If it won't open: Settings → General → VPN & Device Management → Trust."
echo "Done. Signature is good for 7 days (until $(date -v+7d '+%a %d %b'))."
