#!/bin/bash
# Build the current stable release or development beta with a self-contained native setup GUI. Never install, launch, or send HID commands.
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
source "$HERE/scripts/developer-tools.sh"
ecz_require_developer_tools --check-only
WORK="$(mktemp -d "${TMPDIR:-/tmp}/ecz-beta.XXXXXXXX")"
trap 'rm -rf "$WORK"' EXIT
export CLANG_MODULE_CACHE_PATH="$WORK/clang-cache"
export SWIFT_MODULECACHE_PATH="$WORK/swift-cache"
APP="$WORK/EasyComp Keyboard Light.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$HERE/broncode/HIDBacklight.c" "$HERE/broncode/EasyCompKeyboardLight.swift" "$HERE/broncode/InstallWizard.swift" "$WORK/"
xcrun clang -arch x86_64 -mmacosx-version-min=13.0 -O2 -Wall -Wextra \
  -framework IOKit -framework CoreFoundation "$WORK/HIDBacklight.c" \
  -o "$APP/Contents/MacOS/ecz-t2-backlight"
xcrun swiftc -target x86_64-apple-macosx13.0 -O -framework AppKit -framework CoreGraphics \
  "$WORK/EasyCompKeyboardLight.swift" -o "$APP/Contents/MacOS/EasyCompKeyboardLight"
cp "$HERE/broncode/Info.plist" "$APP/Contents/Info.plist"
for lang in en nl de fr es it pt pl; do
  cp -R "$HERE/broncode/Localizations/$lang.lproj" "$APP/Contents/Resources/"
done
iconutil -c icns "$HERE/Assets/AppIcon.iconset" -o "$APP/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$APP/Contents/MacOS/ecz-t2-backlight"
codesign --force --sign - "$APP"
codesign --verify --deep --strict "$APP"
# The download contains one Setup.app. Its bundled backend stays internal.
SETUP="$WORK/EasyComp Keyboard Light Setup.app"
PAYLOAD="$SETUP/Contents/Resources/Project"
mkdir -p "$SETUP/Contents/MacOS" "$PAYLOAD/broncode" "$PAYLOAD/scripts" "$PAYLOAD/Assets"
cp "$HERE/broncode/SetupInfo.plist" "$SETUP/Contents/Info.plist"
for arch in x86_64 arm64; do
  xcrun swiftc -target "$arch-apple-macosx13.0" -O -framework AppKit \
    "$WORK/InstallWizard.swift" -o "$WORK/wizard-$arch"
done
xcrun lipo -create "$WORK/wizard-x86_64" "$WORK/wizard-arm64" -output "$SETUP/Contents/MacOS/EasyCompWizard"
for lang in en nl de fr es it pt pl; do
  cp -R "$HERE/broncode/WizardLocalizations/$lang.lproj" "$SETUP/Contents/Resources/"
done
cp "$APP/Contents/Resources/AppIcon.icns" "$SETUP/Contents/Resources/"
for script in Installeer.command Verwijder.command Probleemrapport.command Controleer-build.command; do
  cp "$HERE/$script" "$PAYLOAD/"
done
cp "$HERE/scripts/cli-i18n.sh" "$HERE/scripts/developer-tools.sh" "$PAYLOAD/scripts/"
cp "$WORK/HIDBacklight.c" "$WORK/EasyCompKeyboardLight.swift" "$WORK/InstallWizard.swift" "$PAYLOAD/broncode/"
cp "$HERE/broncode/Info.plist" "$HERE/broncode/SetupInfo.plist" "$PAYLOAD/broncode/"
cp -R "$HERE/broncode/Localizations" "$HERE/broncode/WizardLocalizations" "$PAYLOAD/broncode/"
cp -R "$HERE/Assets/AppIcon.iconset" "$PAYLOAD/Assets/"
cp "$HERE/VERSION" "$HERE/LICENSE" "$PAYLOAD/"
codesign --force --sign - "$SETUP"
codesign --verify --deep --strict "$SETUP"
VERSION="$(cat "$HERE/VERSION")"
case "$VERSION" in
  *-*) CHANNEL="beta"; ARCHIVE="EasyComp-Keyboard-Light-Beta.zip"; STATUS="prerelease candidate; not a stable release" ;;
  *) CHANNEL="release"; ARCHIVE="EasyComp-Keyboard-Light.zip"; STATUS="stable release" ;;
esac
OUT="$HERE/dist/$CHANNEL"
mkdir -p "$OUT"
{
  echo "$VERSION — $STATUS. Universal setup, Intel T2 controller, macOS 13 or later."
  git -C "$HERE" rev-parse HEAD
  git -C "$HERE" branch --show-current
  (cd "$WORK" && shasum -a 256 HIDBacklight.c EasyCompKeyboardLight.swift InstallWizard.swift)
} > "$WORK/BUILD-INFO.txt"
# Archive on the local volume before copying: SMB can add Finder metadata that
# invalidates an unpacked signed bundle. Verify the archive after the SMB roundtrip.
ditto -c -k --keepParent --norsrc "$SETUP" "$WORK/$ARCHIVE"
cp -X "$WORK/$ARCHIVE" "$OUT/.beta-candidate.zip"
mkdir "$WORK/verify"
ditto -x -k "$OUT/.beta-candidate.zip" "$WORK/verify"
codesign --verify --deep --strict "$WORK/verify/$(basename "$SETUP")"
mv -f "$OUT/.beta-candidate.zip" "$OUT/$ARCHIVE"
cp -X "$WORK/BUILD-INFO.txt" "$HERE/HARDWARE-ACCEPTANCE.md" "$OUT/"
(cd "$OUT" && shasum -a 256 "$ARCHIVE" > SHA256SUMS.txt)
echo "Package built (not installed or started): $OUT"
