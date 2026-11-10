#!/usr/bin/env bash
# Releases a new version of Elsewhere in one step:
# bumps the version, builds, signs, notarizes, publishes the GitHub release with
# a Sparkle appcast, and updates the Homebrew cask.
#
# One time setup:
#   xcrun notarytool store-credentials elsewhere-notary --apple-id <id> --team-id 2L3ZYUGUP7
#   The Sparkle signing key lives in the login keychain under the account "elsewhere".
#   The tap is checked out next to this repo at ../homebrew-tap (override with TAP_DIR).
#
# Usage:
#   scripts/release.sh 2.2           # full release
#   scripts/release.sh --build-only  # build and sign the current version, no notarizing or publishing

set -euo pipefail

cd "$(dirname "$0")/.."

TEAM_ID="2L3ZYUGUP7"
NOTARY_PROFILE="${NOTARY_PROFILE:-elsewhere-notary}"
SPARKLE_ACCOUNT="elsewhere"
REPO="1stevengrant/Elsewhere"
REMOTE="${REMOTE:-elsewhere}"
TAP_DIR="${TAP_DIR:-../homebrew-tap}"
PROJECT="Elsewhere.xcodeproj/project.pbxproj"
BUILD_DIR="build"
DERIVED_DATA=".build/DerivedData"
ARCHIVE="$BUILD_DIR/Elsewhere.xcarchive"

if [ $# -ne 1 ]; then
    echo "Usage: scripts/release.sh <version> | --build-only"
    exit 1
fi

BUILD_ONLY=false

if [ "$1" = "--build-only" ]; then
    BUILD_ONLY=true
fi

if [ "$BUILD_ONLY" = false ]; then
    VERSION="$1"

    if [ -n "$(git status --porcelain)" ]; then
        echo "Working tree is not clean. Commit or stash changes first."
        exit 1
    fi

    if git rev-parse "v$VERSION" >/dev/null 2>&1; then
        echo "Tag v$VERSION already exists."
        exit 1
    fi

    if [ ! -d "$TAP_DIR/Casks" ]; then
        echo "Homebrew tap not found at $TAP_DIR."
        exit 1
    fi

    BUILD_NUMBER=$(($(grep -m1 -E 'CURRENT_PROJECT_VERSION = [0-9]+;' "$PROJECT" | sed -E 's/.*= ([0-9]+);/\1/') + 1))

    echo "Bumping to $VERSION ($BUILD_NUMBER)..."
    # Only the app target uses 2.x versions and build numbers above 1; the test targets stay at 1.0 (1).
    sed -i '' -E "s/MARKETING_VERSION = [2-9][0-9.]*;/MARKETING_VERSION = $VERSION;/" "$PROJECT"
    sed -i '' -E "s/CURRENT_PROJECT_VERSION = ([2-9]|[0-9]{2,});/CURRENT_PROJECT_VERSION = $BUILD_NUMBER;/" "$PROJECT"
fi

VERSION=$(grep -m1 -E 'MARKETING_VERSION = [2-9]' "$PROJECT" | sed -E 's/.*= ([0-9.]+);/\1/')
ZIP="$BUILD_DIR/Elsewhere-$VERSION.zip"

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

echo "Archiving Elsewhere $VERSION..."
xcodebuild archive \
    -project Elsewhere.xcodeproj \
    -scheme Elsewhere \
    -configuration Release \
    -archivePath "$ARCHIVE" \
    -derivedDataPath "$DERIVED_DATA" \
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

# Exporting re-signs nested code, including Sparkle's XPC services, with the Developer ID certificate.
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE" \
    -exportPath "$BUILD_DIR/export" \
    -exportOptionsPlist scripts/ExportOptions.plist \
    > "$BUILD_DIR/export.log" 2>&1 || {
        grep -E "error" "$BUILD_DIR/export.log" || tail -30 "$BUILD_DIR/export.log"
        exit 1
    }

cp -R "$BUILD_DIR/export/Elsewhere.app" "$BUILD_DIR/"
APP="$BUILD_DIR/Elsewhere.app"

echo "Verifying signature..."
codesign --verify --deep --strict --verbose=2 "$APP"

if [ "$BUILD_ONLY" = true ]; then
    ditto -c -k --keepParent "$APP" "$ZIP"
    echo "Built $ZIP (not notarized)"
    exit 0
fi

echo "Notarizing..."
ditto -c -k --keepParent "$APP" "$ZIP"
xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$APP"
spctl --assess --type execute --verbose "$APP"

rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"
SHA256=$(shasum -a 256 "$ZIP" | cut -d' ' -f1)

echo "Generating appcast..."
SPARKLE_BIN="$DERIVED_DATA/SourcePackages/artifacts/sparkle/Sparkle/bin"
UPDATES_DIR="$BUILD_DIR/updates"
mkdir -p "$UPDATES_DIR"
cp "$ZIP" "$UPDATES_DIR/"
"$SPARKLE_BIN/generate_appcast" \
    --account "$SPARKLE_ACCOUNT" \
    --download-url-prefix "https://github.com/$REPO/releases/download/v$VERSION/" \
    --link "https://github.com/$REPO" \
    "$UPDATES_DIR"

echo "Publishing v$VERSION..."
git add -f "$PROJECT"
git commit -q -m "Release $VERSION"
git tag "v$VERSION"
git push -q "$REMOTE" HEAD:main
git push -q "$REMOTE" "v$VERSION"
gh release create "v$VERSION" "$ZIP" "$UPDATES_DIR/appcast.xml" \
    --repo "$REPO" \
    --title "Elsewhere $VERSION" \
    --generate-notes

echo "Updating Homebrew cask..."
CASK="$TAP_DIR/Casks/elsewhere.rb"
sed -i '' -E "s/version \"[^\"]+\"/version \"$VERSION\"/" "$CASK"
sed -i '' -E "s/sha256 \"[^\"]+\"/sha256 \"$SHA256\"/" "$CASK"
git -C "$TAP_DIR" commit -q -am "Update Elsewhere to $VERSION"
git -C "$TAP_DIR" push -q

echo "Released Elsewhere $VERSION"
