#!/usr/bin/env bash
# Package a Godot Universal staging ZIP on macOS. Optional trusted signing:
# MACOS_SIGN_IDENTITY, APPLE_ID, APPLE_TEAM_ID, APPLE_APP_PASSWORD.
set -euo pipefail
if [[ $# -ne 3 ]]; then
  echo "Usage: $0 staging.zip output-dir version" >&2; exit 2
fi
input="$1"; out="$2"; version="$3"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
mkdir -p "$out"
out="$(cd "$out" && pwd)"
work="$(mktemp -d "${TMPDIR:-/tmp}/sprout-package.XXXXXX")"
mount="$work/mounted"
cleanup() {
  if [[ -d "$mount" ]]; then hdiutil detach "$mount" >/dev/null 2>&1 || true; fi
  rm -rf "$work"
}
trap cleanup EXIT
mkdir -p "$work/extracted" "$work/dmg-root" "$work/installed" "$mount"
ditto -x -k "$input" "$work/extracted"
app="$(find "$work/extracted" -maxdepth 2 -type d -name '*.app' -print -quit)"
test -n "$app"
plist="$app/Contents/Info.plist"
exename="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$plist")"
exe="$app/Contents/MacOS/$exename"
test -f "$exe"; chmod +x "$exe"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $version" "$plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $version" "$plist"
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$plist")" = io.github.weepwood.sproutguardians
root="$(cd "$(dirname "$0")/.." && pwd)"
cp "$root/assets/branding/app-icon.icns" "$app/Contents/Resources/icon.icns"
/usr/libexec/PlistBuddy -c 'Set :CFBundleIconFile icon.icns' "$plist"
plutil -lint "$plist"
archs="$(lipo -archs "$exe")"
[[ " $archs " == *" arm64 "* && " $archs " == *" x86_64 "* ]]
echo "macOS architectures: $archs"
zip="$out/SproutGuardians-macOS-Universal.zip"
dmg="$out/SproutGuardians-macOS-Universal.dmg"
identity="${MACOS_SIGN_IDENTITY:-}"
if [[ -n "$identity" ]]; then
  : "${APPLE_ID:?Missing APPLE_ID}" "${APPLE_TEAM_ID:?Missing APPLE_TEAM_ID}" "${APPLE_APP_PASSWORD:?Missing APPLE_APP_PASSWORD}"
  codesign --force --deep --options runtime --sign "$identity" --timestamp "$app"
else
  codesign --force --deep --sign - --timestamp=none "$app"
fi
codesign --verify --deep --strict --verbose=2 "$app"
notarize() {
  xcrun notarytool submit "$1" --apple-id "$APPLE_ID" --team-id "$APPLE_TEAM_ID" --password "$APPLE_APP_PASSWORD" --wait
}
if [[ -n "$identity" ]]; then
  ditto -c -k --sequesterRsrc --keepParent "$app" "$work/notary-app.zip"
  notarize "$work/notary-app.zip"
  xcrun stapler staple "$app"
  xcrun stapler validate "$app"
  spctl --assess --type execute --verbose=2 "$app"
  echo "developer-id-notarized" > "$out/macos-signing-status.txt"
else
  echo "ad-hoc-unnotarized" > "$out/macos-signing-status.txt"
  echo "WARNING: ad-hoc package is not Apple-notarized and may be blocked by Gatekeeper."
fi
ditto -c -k --sequesterRsrc --keepParent "$app" "$zip"
unzip -tq "$zip"
mkdir -p "$work/zip-check"
ditto -x -k "$zip" "$work/zip-check"
zip_app="$(find "$work/zip-check" -maxdepth 2 -type d -name '*.app' -print -quit)"
test -n "$zip_app"
codesign --verify --deep --strict --verbose=2 "$zip_app"

ditto "$app" "$work/dmg-root/Sprout Guardians.app"
ln -s /Applications "$work/dmg-root/Applications"
hdiutil create -volname "Sprout Guardians" -srcfolder "$work/dmg-root" -fs HFS+ -ov -format UDZO "$dmg"
if [[ -n "$identity" ]]; then
  codesign --force --sign "$identity" --timestamp "$dmg"
  notarize "$dmg"
  xcrun stapler staple "$dmg"
  xcrun stapler validate "$dmg"
fi
hdiutil verify "$dmg"
hdiutil attach -readonly -nobrowse -mountpoint "$mount" "$dmg"
test "$(readlink "$mount/Applications")" = /Applications
test -d "$mount/Sprout Guardians.app"
ditto "$mount/Sprout Guardians.app" "$work/installed/Sprout Guardians.app"
installed="$work/installed/Sprout Guardians.app"
codesign --verify --deep --strict --verbose=2 "$installed"
cmp "$installed/Contents/Resources/icon.icns" "$root/assets/branding/app-icon.icns"
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$installed/Contents/Info.plist")" = "$version"
if [[ -n "$identity" ]]; then
  spctl --assess --type execute --verbose=2 "$installed"
fi
# Launch the copy taken from the final mounted image, rather than the staging executable.
"$installed/Contents/MacOS/$exename" --headless --audio-driver Dummy --quit-after 120 -- --ci-survivors-smoke > "$out/macos-smoke.log" 2>&1
cat "$out/macos-smoke.log"
if grep -E 'SCRIPT ERROR|Parse Error|Compile Error|Failed to load script|Invalid access|Invalid call|on a null instance' "$out/macos-smoke.log"; then exit 1; fi
hdiutil detach "$mount"
echo "Final DMG mounted, app copied and smoke-tested; signing: $(cat "$out/macos-signing-status.txt")"
