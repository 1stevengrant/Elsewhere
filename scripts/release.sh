#!/usr/bin/env bash
# Builds, signs, notarizes and zips Elsewhere for distribution.
#
# Requires a notarytool keychain profile, created once with:
#   xcrun notarytool store-credentials elsewhere-notary --apple-id <id> --team-id 2L3ZYUGUP7
#
# Usage: scripts/release.sh [--skip-notarize]

set -euo pipefail

cd "$(dirname "$0")/.."

TEAM_ID="2L3ZYUGUP7"
NOTARY_PROFILE="${NOTARY_PROFILE:-elsewhere-notary}"
BUILD_DIR="build"
ARCHIVE="$BUILD_DIR/Elsewhere.xcarchive"

VERSION=$(grep -m1 'MARKETING_VERSION = 2' Elsewhere.xcodeproj/project.pbxproj | sed -E 's/.*= ([0-9.]+);/\1/')
ZIP="$BUILD_DIR/Elsewhere-$VERSION.zip"

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

echo "Archiving Elsewhere $VERSION..."
xcodebuild archive \
    -project Elsewhere.xcodeproj \
    -scheme Elsewhere \
    -configuration Release \
    -archivePath "$ARCHIVE" \
    -destination "generic/platform=macOS" \
    CODE_SIGN_STYLE=Manual \
    CODE_SIGN_IDENTITY="Developer ID Application: Steven Grant ($TEAM_ID)" \
    DEVELOPMENT_TEAM="$TEAM_ID" \
    PROVISIONING_PROFILE_SPECIFIER="" \
    OTHER_CODE_SIGN_FLAGS="--timestamp" \
    > "$BUILD_DIR/archive.log" 2>&1 || {
        grep -E "error:" "$BUILD_DIR/archive.log" || tail -30 "$BUILD_DIR/archive.log"
        exit 1
    }

APP="$ARCHIVE/Products/Applications/Elsewhere.app"

cp -R "$APP" "$BUILD_DIR/"
APP="$BUILD_DIR/Elsewhere.app"

echo "Verifying signature..."
codesign --verify --deep --strict --verbose=2 "$APP"

if [ "${1:-}" != "--skip-notarize" ]; then
    echo "Notarizing..."
    ditto -c -k --keepParent "$APP" "$ZIP"
    xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$APP"
    spctl --assess --type execute --verbose "$APP"
fi

rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

echo "Built $ZIP"
echo "sha256 $(shasum -a 256 "$ZIP" | cut -d' ' -f1)"
