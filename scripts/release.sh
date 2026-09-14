#!/bin/sh
# Archive the app for the App Store and upload it to App Store Connect.
#
#   scripts/release.sh            build number = git commit count (monotonic, same for
#                                 the same commit on any machine)
#   scripts/release.sh 130        explicit build number
#
# Needs the Admin API key fastlane/AuthKey_4Q3R87G48X.p8 (gitignored) — cloud-managed
# signing refuses App Manager keys. The marketing version comes from the project.
set -e
cd "$(dirname "$0")/.."
BUILD=${1:-$(git rev-list --count HEAD)}
KEY=fastlane/AuthKey_4Q3R87G48X.p8
KEY_ID=4Q3R87G48X
ISSUER=69a6de77-4ce8-47e3-e053-5b8c7c11a4d1
ARCHIVE=build/TeamRadio-$BUILD.xcarchive
VERSION=$(grep -m1 'MARKETING_VERSION = ' TeamRadio.xcodeproj/project.pbxproj | sed 's/.*= \(.*\);/\1/')

[ -f "$KEY" ] || { echo "missing $KEY"; exit 1; }
echo "Archiving $VERSION ($BUILD)…"
rm -rf "$ARCHIVE"
xcodebuild -project TeamRadio.xcodeproj -scheme TeamRadio -configuration Release \
  -destination 'generic/platform=iOS' -archivePath "$ARCHIVE" archive \
  CURRENT_PROJECT_VERSION="$BUILD" -allowProvisioningUpdates \
  -authenticationKeyPath "$PWD/$KEY" -authenticationKeyID "$KEY_ID" -authenticationKeyIssuerID "$ISSUER" -quiet

PLIST="$ARCHIVE/Products/Applications/TeamRadio.app/Info.plist"
echo "Archived $(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$PLIST") build $(/usr/libexec/PlistBuddy -c 'Print CFBundleVersion' "$PLIST")"
[ -f "$ARCHIVE/Products/Applications/TeamRadio.app/Secrets.plist" ] || echo "WARNING: Secrets.plist not bundled — GIF search will be hidden"

echo "Uploading…"
xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportOptionsPlist fastlane/exportOptions.plist \
  -exportPath "build/export-$BUILD" -allowProvisioningUpdates \
  -authenticationKeyPath "$PWD/$KEY" -authenticationKeyID "$KEY_ID" -authenticationKeyIssuerID "$ISSUER" 2>&1 \
  | grep -E "error|Upload succeeded|EXPORT" || true
echo "Next: python3 scripts/asc/release.py submit $VERSION $BUILD"
