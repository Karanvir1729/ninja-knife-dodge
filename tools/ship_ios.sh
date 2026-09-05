#!/usr/bin/env bash
# Export, archive, sign and upload the iOS build to App Store Connect (TestFlight).
#
#   tools/ship_ios.sh            # uses application/version from export_presets.cfg
#   tools/ship_ios.sh 7          # bumps the build number to 7 first
#   NINJA_OUT=/path/out tools/ship_ios.sh 7   # build somewhere else (parallel editions)
#
# Needs: Godot on PATH with matching export templates, Xcode, the App Store
# provisioning profile installed, the distribution identity in the dedicated
# keychain at ~/.appstoreconnect/ninja-signing (unlocked here), the App Store
# Connect API key at ~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8 and the
# issuer id in ~/.appstoreconnect/issuer_id. Nothing secret lives in the repo.
set -euo pipefail
cd "$(dirname "$0")/.."

KEY_ID="${ASC_KEY_ID:-9S2ALUPNQR}"
ISSUER_ID="${ASC_ISSUER_ID:-$(cat ~/.appstoreconnect/issuer_id)}"
SIGNING=~/.appstoreconnect/ninja-signing
KEYCHAIN="${NINJA_KEYCHAIN:-$SIGNING/ninja-build.keychain-db}"
KEYCHAIN_PW_FILE="${NINJA_KEYCHAIN_PW:-$SIGNING/keychain_pw}"
OUT="${NINJA_OUT:-$(cd .. && pwd)/ninja-ios}"
SCHEME="ninja"

if [[ -n "${1:-}" ]]; then
  sed -i '' -E "s/^application\/version=\"[0-9]+\"/application\/version=\"$1\"/" export_presets.cfg
fi
BUILD=$(grep -E '^application/version="' export_presets.cfg | tail -1 | sed -E 's/.*"([0-9]+)".*/\1/')
VERSION=$(grep -E '^application/short_version="' export_presets.cfg | tail -1 | sed -E 's/.*"([^"]+)".*/\1/')
echo "== Ninja Knife Dodge $VERSION build $BUILD"

echo "== keychain ($KEYCHAIN)"
security unlock-keychain -p "$(tr -d '\n\r' < "$KEYCHAIN_PW_FILE")" "$KEYCHAIN"
security set-keychain-settings -lut 21600 "$KEYCHAIN"
# Put our keychain first in the search list without dropping anyone else's.
OTHERS=$(security list-keychains -d user | tr -d '" ' | grep -v "^$KEYCHAIN$" || true)
security list-keychains -d user -s "$KEYCHAIN" $OTHERS >/dev/null

echo "== godot export (Xcode project)"
rm -rf "$OUT/$SCHEME" "$OUT/$SCHEME.xcodeproj" "$OUT/build"
mkdir -p "$OUT"
godot --headless --path . --import >/dev/null 2>&1 || true
godot --headless --path . --export-release iOS "$OUT/$SCHEME.ipa" 2>&1 | grep -vE "^\[|reimport|loading_editor|DONE|^$" || true
test -d "$OUT/$SCHEME.xcodeproj" || { echo "export failed: no $OUT/$SCHEME.xcodeproj"; exit 1; }

echo "== xcodebuild archive"
xcodebuild -project "$OUT/$SCHEME.xcodeproj" -scheme "$SCHEME" -configuration Release \
  -destination "generic/platform=iOS" -archivePath "$OUT/build/$SCHEME.xcarchive" archive \
  CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM=77793D45RF CODE_SIGN_IDENTITY="iPhone Distribution" \
  PROVISIONING_PROFILE_SPECIFIER="Ninja App Store" -quiet

echo "== xcodebuild export ipa"
xcodebuild -exportArchive -archivePath "$OUT/build/$SCHEME.xcarchive" -exportPath "$OUT/build/export" \
  -exportOptionsPlist "$OUT/ExportOptions.plist" -quiet
IPA=$(ls "$OUT"/build/export/*.ipa | head -1)
echo "ipa: $IPA ($(du -h "$IPA" | cut -f1))"

echo "== verify ipa"
rm -rf "$OUT/build/verify" && mkdir -p "$OUT/build/verify" && unzip -q "$IPA" -d "$OUT/build/verify"
APP=$(ls -d "$OUT"/build/verify/Payload/*.app | head -1)
plutil -extract CFBundleShortVersionString raw "$APP/Info.plist" | sed 's/^/  short version: /'
plutil -extract CFBundleVersion raw "$APP/Info.plist" | sed 's/^/  build: /'
plutil -extract CFBundleIdentifier raw "$APP/Info.plist" | sed 's/^/  bundle id: /'
plutil -extract MinimumOSVersion raw "$APP/Info.plist" | sed 's/^/  min iOS: /'
codesign -dv --entitlements - "$APP" 2>&1 | grep -E "Authority=|application-identifier|get-task-allow" | head -4 | sed 's/^/  /'

echo "== upload to App Store Connect"
xcrun altool --upload-app -f "$IPA" -t ios --apiKey "$KEY_ID" --apiIssuer "$ISSUER_ID" 2>&1 | tail -5
echo "== done: build $BUILD uploaded; it appears in TestFlight after Apple processes it (usually 5-30 minutes)"
