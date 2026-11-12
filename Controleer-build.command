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
# Keep compiler caches inside the disposable build directory.
export CLANG_MODULE_CACHE_PATH="$TMP/clang-cache"
export SWIFT_MODULECACHE_PATH="$TMP/swift-cache"
cp "$HERE/broncode/HIDBacklight.c" "$HERE/broncode/EasyCompKeyboardLight.swift" \
  "$HERE/broncode/InstallWizard.swift" "$TMP/"
/usr/bin/xcrun clang -O2 -Wall -Wextra -framework IOKit -framework CoreFoundation \
  "$TMP/HIDBacklight.c" -o "$TMP/ecz-t2-backlight"
/usr/bin/xcrun swiftc -O -framework AppKit -framework CoreGraphics \
  "$TMP/EasyCompKeyboardLight.swift" -o "$TMP/EasyCompKeyboardLight"
/usr/bin/xcrun swiftc -framework AppKit "$TMP/InstallWizard.swift" -o "$TMP/EasyComp-Installer"
# The standalone Issue #2 experiment is checked only when its sources are present.
# The normal packaged setup intentionally does not contain this research tool.
if [[ -f "$HERE/broncode/Issue2ButterflyTest.c" && -f "$HERE/broncode/Issue2CompatibilityTest.swift" ]]; then
  cp "$HERE/broncode/Issue2ButterflyTest.c" "$HERE/broncode/Issue2CompatibilityTest.swift" "$TMP/"
  /usr/bin/xcrun clang -O2 -Wall -Wextra -Werror -framework IOKit -framework CoreFoundation \
    "$TMP/Issue2ButterflyTest.c" -o "$TMP/Issue2Helper"
  /usr/bin/xcrun swiftc -framework AppKit "$TMP/Issue2CompatibilityTest.swift" -o "$TMP/Issue2CompatibilityTest"
  /usr/bin/plutil -lint "$HERE/broncode/Issue2TestInfo.plist"
fi
/usr/bin/plutil -lint "$HERE/broncode/Info.plist"
/usr/bin/plutil -lint "$HERE/broncode/SetupInfo.plist"
for lang in en nl de fr es it pt pl; do
  /usr/bin/plutil -lint "$HERE/broncode/Localizations/$lang.lproj/Localizable.strings"
  /usr/bin/plutil -lint "$HERE/broncode/WizardLocalizations/$lang.lproj/Localizable.strings"
done
/usr/bin/iconutil -c icns "$HERE/Assets/AppIcon.iconset" -o "$TMP/AppIcon.icns"
test -s "$TMP/AppIcon.icns"
echo "Build OK: native app, setup wizard, T2 HID, 8 app languages, 8 wizard languages, macOS icon."
