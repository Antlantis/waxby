#!/usr/bin/env bash
# Build Waxby for App Store Connect (TestFlight / App Store).
#
#   tools/ios_release.sh            # archive + export a signed .ipa, no upload
#   tools/ios_release.sh --upload   # archive + upload to App Store Connect
#
# Needs: Xcode signed in to the team's Apple ID (Xcode > Settings > Accounts),
# and, for --upload, the app's record in App Store Connect (bundle ID
# com.ant.waxby). Bump application/version (the build number) in the
# "iOS App Store" preset of game/export_presets.cfg before every upload:
# App Store Connect refuses a build number it has seen.
#
# Godot's own iOS archive step fails with automatic signing (its release
# config pins "Apple Distribution"), so the "iOS App Store" preset exports
# the Xcode project only, and this script archives it with the development
# identity and lets the App Store export re-sign it for distribution.
# (The same pipeline as Anthaul's tools/ios_release.sh.)
set -euo pipefail
cd "$(dirname "$0")/.."
G="${GODOT:-/Users/antmacpro/Downloads/Godot.app/Contents/MacOS/Godot}"
TEAM="B2ZBWG372P"
OUT="${WAXBY_RELEASE_DIR:-$HOME/Developer/waxby-ios-release}"
dest="export"
[ "${1:-}" = "--upload" ] && dest="upload"

mkdir -p "$OUT"
(cd game && "$G" --headless --path . --export-release "iOS App Store" "$OUT/waxby.ipa")
cd "$OUT"
rm -rf waxby.xcarchive appstore
xcodebuild -project waxby.xcodeproj -scheme waxby -configuration Release \
	-destination 'generic/platform=iOS' -archivePath "$OUT/waxby.xcarchive" \
	-allowProvisioningUpdates CODE_SIGN_STYLE=Automatic \
	CODE_SIGN_IDENTITY="Apple Development" DEVELOPMENT_TEAM="$TEAM" archive
cat > ExportOptions.plist <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key><string>app-store-connect</string>
	<key>destination</key><string>$dest</string>
	<key>teamID</key><string>$TEAM</string>
	<key>signingStyle</key><string>automatic</string>
	<key>uploadSymbols</key><true/>
	<key>manageAppVersionAndBuildNumber</key><false/>
</dict>
</plist>
PLIST
xcodebuild -exportArchive -archivePath "$OUT/waxby.xcarchive" -exportPath "$OUT/appstore" \
	-exportOptionsPlist ExportOptions.plist -allowProvisioningUpdates
echo "Done ($dest): $OUT/appstore"
