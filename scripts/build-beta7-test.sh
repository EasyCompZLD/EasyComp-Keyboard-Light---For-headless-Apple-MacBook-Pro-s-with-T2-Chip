#!/bin/bash
# Build an isolated Intel test app. Never install, launch, or send HID commands.
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
source "$HERE/scripts/developer-tools.sh"
ecz_require_developer_tools --check-only
WORK="$(mktemp -d "${TMPDIR:-/tmp}/ecz-beta7-test.XXXXXXXX")"
trap 'rm -rf "$WORK"' EXIT
export CLANG_MODULE_CACHE_PATH="$WORK/clang-cache"
export SWIFT_MODULECACHE_PATH="$WORK/swift-cache"
APP="$WORK/EasyComp Keyboard Light Beta7 Test.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$HERE/broncode/HIDBacklight.c" "$HERE/broncode/EasyCompKeyboardLight.swift" "$WORK/"
xcrun clang -arch x86_64 -mmacosx-version-min=13.0 -O2 -Wall -Wextra \
  -framework IOKit -framework CoreFoundation "$WORK/HIDBacklight.c" \
  -o "$APP/Contents/MacOS/ecz-t2-backlight"
xcrun swiftc -target x86_64-apple-macosx13.0 -O -framework AppKit -framework CoreGraphics \
  "$WORK/EasyCompKeyboardLight.swift" -o "$APP/Contents/MacOS/EasyCompKeyboardLight"
cp "$HERE/broncode/Info.plist" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier nl.easycompzeeland.KeyboardLight.Beta7Test' "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleName EasyComp Keyboard Light Beta7 Test' "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleDisplayName EasyComp Keyboard Light Beta7 Test' "$APP/Contents/Info.plist"
for lang in en nl de fr es it pt pl; do
  cp -R "$HERE/broncode/Localizations/$lang.lproj" "$APP/Contents/Resources/"
done
iconutil -c icns "$HERE/Assets/AppIcon.iconset" -o "$APP/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$APP/Contents/MacOS/ecz-t2-backlight"
codesign --force --sign - "$APP"
codesign --verify --deep --strict "$APP"
OUT="$HERE/dist/beta7-test-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$OUT"
cp "$HERE/HARDWARE-ACCEPTANCE.md" "$OUT/"
{
  echo 'Development test build; not a release. Intel x86_64, macOS 13 or later.'
  git -C "$HERE" rev-parse HEAD
  git -C "$HERE" branch --show-current
  (cd "$WORK" && shasum -a 256 HIDBacklight.c EasyCompKeyboardLight.swift)
} > "$OUT/BUILD-INFO.txt"
# Archive on the local volume before copying: SMB can add Finder metadata that
# invalidates an unpacked signed bundle. Verify the archive after the SMB roundtrip.
ditto -c -k --keepParent --norsrc "$APP" "$WORK/Beta7-Test-App.zip"
cp -X "$WORK/Beta7-Test-App.zip" "$OUT/Beta7-Test-App.zip"
mkdir "$WORK/verify"
ditto -x -k "$OUT/Beta7-Test-App.zip" "$WORK/verify"
codesign --verify --deep --strict "$WORK/verify/$(basename "$APP")"
shasum -a 256 "$OUT/Beta7-Test-App.zip" > "$OUT/SHA256SUMS.txt"
echo "Test app built (not installed or started): $OUT"
