#!/usr/bin/env bash
# Build Waxby for App Store Connect (TestFlight / App Store).
#
#   tools/ios_release.sh                    # the playtest build: archive + export a signed .ipa, no upload
#   tools/ios_release.sh --upload           # the playtest build, uploaded to App Store Connect (TestFlight)
#   tools/ios_release.sh --store            # the App Store submission: archive + export, no upload
#   tools/ios_release.sh --store --upload   # the App Store submission, uploaded
#
# --store is the one switch between the two builds. Without it (TestFlight
# build 5 on: the owner's own playtests) the "iOS App Store" preset is used as
# committed: Documents shows in the Files app (Files > On My iPhone > Waxby:
# playlog.json, the saves, logs/godot.log) and Godot's file log is on (the
# preset's "playtest" feature; project.godot debug/file_logging). With
# --store, tools/store_preset.py turns Files access and file sharing off and
# drops "playtest" (so no file log) in that preset for the length of the
# export, and the committed file is put back afterwards: nobody edits the
# preset by hand. The build number is the same either way.
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
store=0
for a in "$@"; do
	case "$a" in
		--upload) dest="upload" ;;
		--store) store=1 ;;
		*) echo "ios_release.sh: unknown option $a (--store, --upload)" >&2; exit 2 ;;
	esac
done

PRESETS="game/export_presets.cfg"
KEPT=""
restore() {
	if [ -n "$KEPT" ] && [ -f "$KEPT" ]; then
		cp "$KEPT" "$PRESETS"
		rm -f "$KEPT"
		KEPT=""
	fi
}
trap restore EXIT
if [ "$store" = "1" ]; then
	KEPT="$(mktemp "${TMPDIR:-/tmp}/waxby-presets.XXXXXX")"
	cp "$PRESETS" "$KEPT"
	python3 tools/store_preset.py --apply "$PRESETS"
	echo "== App Store submission: Files access off, file log off"
else
	echo "== playtest build: Files access on, file log on (--store for the submission)"
fi

mkdir -p "$OUT"
(cd game && "$G" --headless --path . --export-release "iOS App Store" "$OUT/waxby.ipa")
restore

# The exported Info.plist says which build this is: check it said what was asked.
PLIST="$OUT/waxby/waxby-Info.plist"
want="true"
[ "$store" = "1" ] && want="false"
for key in UIFileSharingEnabled LSSupportsOpeningDocumentsInPlace; do
	got="$(/usr/libexec/PlistBuddy -c "Print :$key" "$PLIST")"
	if [ "$got" != "$want" ]; then
		echo "ios_release.sh: $key is $got in $PLIST, wanted $want" >&2
		exit 1
	fi
done

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
echo "Done ($dest, $([ "$store" = "1" ] && echo "App Store submission" || echo "playtest")): $OUT/appstore"
