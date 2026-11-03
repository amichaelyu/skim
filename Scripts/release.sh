#!/bin/bash
#
# Builds a release of this Skim fork for distribution: built, signed with a Developer ID,
# notarized, stapled, and zipped, with a Sparkle appcast to go beside it.
#
# Leaves exactly two files in $DIST, Skim.zip and appcast.xml, ready to attach to a GitHub release
# tagged with the marketing version (the app's update feed is releases/latest/download/appcast.xml).
# It does not create that release or tag anything.
#
# Settings, all from the environment:
#   DEVELOPMENT_TEAM  the team whose "Developer ID Application" certificate signs the app
#                     (default SNC2X5N2CY)
#   NOTARY_PROFILE    the keychain profile `xcrun notarytool store-credentials` saved (default notary)
#   SPARKLE_ACCOUNT   the keychain account holding the Sparkle EdDSA private key that matches
#                     SUPublicEDKey in Info.plist (default "Skim (amichaelyu fork)")
#   SPARKLE_BIN       Sparkle's command line tools (generate_appcast); downloaded when missing
#   DIST              where the artifacts go (default dist/ in the repository); it is emptied first
#   DERIVED           build products and scratch files (default /tmp/skim-release)
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM:-SNC2X5N2CY}"
NOTARY_PROFILE="${NOTARY_PROFILE:-notary}"
SPARKLE_ACCOUNT="${SPARKLE_ACCOUNT:-Skim (amichaelyu fork)}"
SPARKLE_VERSION=2.10.1
SPARKLE_BIN="${SPARKLE_BIN:-$HOME/Library/Caches/skim-release/sparkle-$SPARKLE_VERSION/bin}"
DIST="${DIST:-$ROOT/dist}"
DERIVED="${DERIVED:-/tmp/skim-release}"

SYMROOT="$DERIVED/build"
BUILT_APP="$SYMROOT/Release/Skim.app"
WORK="$DERIVED/release-work"
APP="$DIST/Skim.app"
ZIP="$DIST/Skim.zip"

setting() { sed -n "s/^$1 = //p" "$ROOT/Configurations/Skim-Common.xcconfig"; }
VERSION="$(setting MARKETING_VERSION)"
BUILD="$(setting CURRENT_PROJECT_VERSION)"
[ -n "$VERSION" ] && [ -n "$BUILD" ] || { echo "error: no version in Skim-Common.xcconfig" >&2; exit 1; }
IDENTITY="$(security find-identity -v -p codesigning | sed -n "s/.*\"\(Developer ID Application: .*($DEVELOPMENT_TEAM)\)\"/\1/p" | head -1)"
[ -n "$IDENTITY" ] || { echo "error: no Developer ID Application certificate for team $DEVELOPMENT_TEAM" >&2; exit 1; }
echo "==> Releasing Skim $VERSION ($BUILD), signed by $IDENTITY"

if [ ! -x "$SPARKLE_BIN/generate_appcast" ]; then
    echo "==> Fetching Sparkle $SPARKLE_VERSION tools"
    mkdir -p "$SPARKLE_BIN/.."
    curl -fsSL "https://github.com/sparkle-project/Sparkle/releases/download/$SPARKLE_VERSION/Sparkle-$SPARKLE_VERSION.tar.xz" \
        | tar -xJ -C "$SPARKLE_BIN/.."
fi

rm -rf "$DIST" "$WORK" "$SYMROOT"
mkdir -p "$DIST" "$WORK"

run_logged() {
    local name="$1" log="$DIST/$1.log"; shift
    if ! "$@" >"$log" 2>&1; then
        echo "error: $name failed; the last lines of $log follow" >&2
        tail -40 "$log" >&2
        exit 1
    fi
}

echo "==> Building"
# Built unsigned, then signed inside out by codesign_skim.sh as upstream does. Xcode 27 builds
# nothing older than macOS 12, and the bundled subprojects still say 10.13, hence the override.
run_logged build xcodebuild -project "$ROOT/Skim.xcodeproj" -target Skim -configuration Release \
    SYMROOT="$SYMROOT" MACOSX_DEPLOYMENT_TARGET=12.0 \
    CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO DEVELOPMENT_TEAM= CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
    build
ditto "$BUILT_APP" "$APP"

BUILT_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
BUILT_BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP/Contents/Info.plist")"
if [ "$BUILT_VERSION" != "$VERSION" ] || [ "$BUILT_BUILD" != "$BUILD" ]; then
    echo "error: built $BUILT_VERSION ($BUILT_BUILD), but the configuration says $VERSION ($BUILD)" >&2
    exit 1
fi

echo "==> Signing"
run_logged codesign "$ROOT/codesign_skim.sh" "$IDENTITY" "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"
TEAM_SIGNED="$(codesign -dv "$APP" 2>&1 | sed -n 's/^TeamIdentifier=//p')"
if [ "$TEAM_SIGNED" != "$DEVELOPMENT_TEAM" ]; then
    echo "error: signed by team '$TEAM_SIGNED', expected $DEVELOPMENT_TEAM" >&2
    exit 1
fi

echo "==> Notarizing (this usually takes a few minutes)"
ditto -c -k --keepParent "$APP" "$WORK/Skim-unstapled.zip"
xcrun notarytool submit "$WORK/Skim-unstapled.zip" --keychain-profile "$NOTARY_PROFILE" \
    --wait --output-format json > "$WORK/notary.json" || true
SUBMISSION="$(plutil -extract id raw -o - "$WORK/notary.json" 2>/dev/null || true)"
STATUS="$(plutil -extract status raw -o - "$WORK/notary.json" 2>/dev/null || true)"
echo "    submission ${SUBMISSION:-unknown}: ${STATUS:-no status}"
if [ "$STATUS" != "Accepted" ]; then
    echo "error: notarization was not accepted" >&2
    cat "$WORK/notary.json" >&2
    if [ -n "$SUBMISSION" ]; then
        xcrun notarytool log "$SUBMISSION" --keychain-profile "$NOTARY_PROFILE" >&2 || true
    fi
    exit 1
fi
rm -f "$WORK/Skim-unstapled.zip"

echo "==> Stapling"
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"
spctl -a -vv -t exec "$APP"
ditto -c -k --keepParent "$APP" "$ZIP"

echo "==> Writing the appcast"
mkdir -p "$WORK/appcast"
cp "$ZIP" "$WORK/appcast/Skim.zip"
"$SPARKLE_BIN/generate_appcast" --account "$SPARKLE_ACCOUNT" \
    --download-url-prefix "https://github.com/amichaelyu/skim/releases/download/$VERSION/" \
    -o "$DIST/appcast.xml" "$WORK/appcast"
grep -q "<sparkle:version>$BUILD</sparkle:version>" "$DIST/appcast.xml" \
    || { echo "error: appcast.xml does not offer build $BUILD" >&2; exit 1; }
grep -q 'sparkle:edSignature=' "$DIST/appcast.xml" \
    || { echo "error: appcast.xml carries no EdDSA signature" >&2; exit 1; }

rm -rf "$WORK/Skim.app" "$WORK/logs"
mv "$APP" "$WORK/Skim.app"
mkdir -p "$WORK/logs" && mv "$DIST"/*.log "$WORK/logs/"

echo "==> Done"
echo "    version    $VERSION"
echo "    build      $BUILD"
echo "    notarized  $SUBMISSION"
echo "    sha256     $(shasum -a 256 "$ZIP" | cut -d' ' -f1)"
echo "    $ZIP"
echo "    $DIST/appcast.xml"
