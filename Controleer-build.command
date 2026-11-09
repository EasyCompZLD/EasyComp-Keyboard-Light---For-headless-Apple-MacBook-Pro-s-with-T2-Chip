#!/bin/bash
# Build-only checks. Does not install or issue any HID report.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/scripts/cli-i18n.sh"
source "$HERE/scripts/developer-tools.sh"
if [[ "$(uname -s)" != "Darwin" ]]; then
  echo 'Alleen op macOS te compileren (AppKit/IOKit vereist).' >&2
  exit 1
fi
# Build verification is read-only for the machine. The regular installer
# installs missing prerequisites; build verification simply explains errors.
ecz_require_developer_tools --check-only || exit 1
TMP="$(mktemp -d "${TMPDIR:-/tmp}/ecz-kbl-build.XXXXXXXX")"
trap 'rm -rf "$TMP"' EXIT
/usr/bin/xcrun clang -O2 -Wall -Wextra -framework IOKit -framework CoreFoundation \
  "$HERE/broncode/HIDBacklight.c" -o "$TMP/ecz-t2-backlight"
/usr/bin/xcrun swiftc -O -framework AppKit -framework CoreGraphics \
  "$HERE/broncode/EasyCompKeyboardLight.swift" -o "$TMP/EasyCompKeyboardLight"
/usr/bin/xcrun swiftc -framework AppKit "$HERE/broncode/InstallWizard.swift" -o "$TMP/EasyComp-Installer"
/usr/bin/plutil -lint "$HERE/broncode/Info.plist"
for lang in en nl de fr es it pt pl; do
  /usr/bin/plutil -lint "$HERE/broncode/Localizations/$lang.lproj/Localizable.strings"
  /usr/bin/plutil -lint "$HERE/broncode/WizardLocalizations/$lang.lproj/Localizable.strings"
done
/usr/bin/iconutil -c icns "$HERE/Assets/AppIcon.iconset" -o "$TMP/AppIcon.icns"
test -s "$TMP/AppIcon.icns"
echo "Build OK: native app, setup wizard, T2 HID, 8 app languages, 8 wizard languages, macOS icon."
