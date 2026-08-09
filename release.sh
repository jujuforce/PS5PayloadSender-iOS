#!/bin/bash
# Build, package and verify release artifacts.
#
# Release builds carry no signing identity by design (see Local.xcconfig), so the
# artifacts must never contain a team ID, a developer name, a provisioning profile
# or a home-directory path. This script refuses to leave an artifact behind that
# does, because the checks are the whole point — doing them by hand is how they
# get skipped.
#
#   ./release.sh            build + package into dist/
#   ./release.sh --upload v1.3   ... and attach to an existing GitHub release
set -euo pipefail
cd "$(dirname "$0")"

PROJECT=PS5PayloadSender.xcodeproj
SCHEME=PS5PayloadSender
BUILD=.build
DIST=dist

# Strings that must never appear in a published artifact.
#
# Derived at runtime, never hardcoded: this file is committed, so literal identity
# strings here would be the very leak it exists to prevent. The Debug identity is
# read from Local.xcconfig (gitignored) and the account name from the environment.
LEAK_PATTERN='/Users/|DerivedData'
LEAK_PATTERN="$LEAK_PATTERN|$(id -un)"
if [ -f Local.xcconfig ]; then
  while IFS= read -r v; do
    [ -n "$v" ] && LEAK_PATTERN="$LEAK_PATTERN|$v"
  done < <(sed -nE 's/^[[:space:]]*(DEVELOPMENT_TEAM|PRODUCT_BUNDLE_IDENTIFIER)\[config=Debug\][[:space:]]*=[[:space:]]*//p' Local.xcconfig | tr -d ' ')
fi

rm -rf "$BUILD" "$DIST"
mkdir -p "$BUILD" "$DIST/Payload"

echo "==> Building iOS (Release)"
xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Release \
  -destination 'generic/platform=iOS' -derivedDataPath "$BUILD/ios" build \
  >"$BUILD/ios.log" 2>&1 || { tail -30 "$BUILD/ios.log"; exit 1; }

echo "==> Building Mac Catalyst (Release)"
xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Release \
  -destination 'platform=macOS,variant=Mac Catalyst' -derivedDataPath "$BUILD/mac" build \
  >"$BUILD/mac.log" 2>&1 || { tail -30 "$BUILD/mac.log"; exit 1; }

echo "==> Packaging"
cp -R "$BUILD/ios/Build/Products/Release-iphoneos/$SCHEME.app" "$DIST/Payload/"
# iOS Release is built unsigned (no profile to sign against); ad-hoc sign it here
# so sideloaders have a well-formed bundle to re-sign.
codesign -f -s - --deep "$DIST/Payload/$SCHEME.app"
( cd "$DIST" && zip -qry "$SCHEME.ipa" Payload )

cp -R "$BUILD/mac/Build/Products/Release-maccatalyst/$SCHEME.app" "$DIST/"
# zip from inside dist/ so the archive holds relative paths only — zipping by
# absolute path is what leaked a username into a published artifact once before.
( cd "$DIST" && zip -qry "$SCHEME-macOS.zip" "$SCHEME.app" )

echo "==> Verifying"
fail=0
for a in "$DIST/$SCHEME.ipa" "$DIST/$SCHEME-macOS.zip"; do
  name=$(basename "$a")
  hits=$(unzip -p "$a" '*' 2>/dev/null | strings -a | grep -icE "$LEAK_PATTERN" || true)
  prof=$(zipinfo -1 "$a" | grep -ci mobileprovision || true)
  abs=$(zipinfo -1 "$a" | grep -cE '^/|Users' || true)
  # iOS keeps Info.plist at the bundle root, Catalyst under Contents/. Only one of
  # the two globs matches, and unzip exits 11 for the other — swallow that, not the
  # pipeline's real status.
  # The built Info.plist is a BINARY plist, so it must go to a file — routing it
  # through a shell variable corrupts it and plutil then reads nothing.
  plist=$(mktemp)
  unzip -p "$a" '*.app/Info.plist' '*.app/Contents/Info.plist' >"$plist" 2>/dev/null || true
  ver=$(plutil -extract CFBundleShortVersionString raw -o - "$plist" 2>/dev/null | head -1)
  bid=$(plutil -extract CFBundleIdentifier raw -o - "$plist" 2>/dev/null | head -1)
  rm -f "$plist"
  echo "    $name  v$ver  $bid"
  [ "$hits" -eq 0 ] || { echo "    FAIL: $hits identity/path string(s)"; fail=1; }
  [ "$prof" -eq 0 ] || { echo "    FAIL: embedded.mobileprovision present"; fail=1; }
  [ "$abs"  -eq 0 ] || { echo "    FAIL: absolute paths in archive"; fail=1; }
done

sig=$(codesign -dvvv "$DIST/Payload/$SCHEME.app" 2>&1)
grep -q 'Signature=adhoc'      <<<"$sig" || { echo "    FAIL: ipa not ad-hoc signed"; fail=1; }
grep -q 'TeamIdentifier=not set' <<<"$sig" || { echo "    FAIL: ipa carries a team identifier"; fail=1; }

if [ "$fail" -ne 0 ]; then
  rm -f "$DIST/$SCHEME.ipa" "$DIST/$SCHEME-macOS.zip"
  echo "==> FAILED verification — artifacts deleted, nothing to publish."
  exit 1
fi
echo "==> Clean."

if [ "${1:-}" = "--upload" ]; then
  tag="${2:?usage: ./release.sh --upload <tag>}"
  echo "==> Uploading to $tag"
  gh release upload "$tag" "$DIST/$SCHEME.ipa" "$DIST/$SCHEME-macOS.zip" --clobber
fi
