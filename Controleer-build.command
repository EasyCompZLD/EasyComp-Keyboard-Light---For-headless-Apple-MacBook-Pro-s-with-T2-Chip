#!/bin/bash
# Build-only checks. Does not install or issue any HID report.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
if [[ "$(uname -s)" != "Darwin" ]]; then
  echo 'Alleen op macOS te compileren (AppKit/IOKit vereist).' >&2
  exit 1
fi
for program in clang swiftc; do
  if ! xcrun --find "$program" >/dev/null 2>&1; then
    echo "Apple Command Line Tools ontbreken: $program" >&2
    exit 1
  fi
done
if ! command -v iconutil >/dev/null 2>&1; then
  echo 'iconutil ontbreekt.' >&2
  exit 1
fi
TMP="$(mktemp -d "${TMPDIR:-/tmp}/ecz-kbl-build.XXXXXXXX")"
trap 'rm -rf "$TMP"' EXIT
xcrun clang -O2 -Wall -Wextra -framework IOKit -framework CoreFoundation \
  "$HERE/broncode/HIDBacklight.c" -o "$TMP/ecz-a2141-backlight"
xcrun swiftc -O -framework AppKit -framework CoreGraphics \
  "$HERE/broncode/EasyCompKeyboardLight.swift" -o "$TMP/EasyCompKeyboardLight"
/usr/bin/plutil -lint "$HERE/broncode/Info.plist"
for lang in en nl de fr es it pt pl; do
  /usr/bin/plutil -lint "$HERE/broncode/Localizations/$lang.lproj/Localizable.strings"
done
iconutil -c icns "$HERE/Assets/AppIcon.iconset" -o "$TMP/AppIcon.icns"
test -s "$TMP/AppIcon.icns"
echo 'Build OK: Swift, C, 8 vertalingen en macOS-appicoon.'
