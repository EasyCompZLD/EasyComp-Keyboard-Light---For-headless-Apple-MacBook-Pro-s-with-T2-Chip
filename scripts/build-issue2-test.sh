#!/bin/bash
# Package the isolated research tool. Never install, launch or send HID commands.
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
source "$HERE/scripts/developer-tools.sh"
ecz_require_developer_tools --check-only
WORK="$(mktemp -d "${TMPDIR:-/tmp}/ecz-issue2-build.XXXXXXXX")"
trap 'rm -rf "$WORK"' EXIT
export CLANG_MODULE_CACHE_PATH="$WORK/clang-cache"
export SWIFT_MODULECACHE_PATH="$WORK/swift-cache"
APP="$WORK/EasyComp Keyboard Light Issue 2 Test.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$HERE/broncode/Issue2ButterflyTest.c" "$HERE/broncode/Issue2CompatibilityTest.swift" "$WORK/"
xcrun clang -arch x86_64 -mmacosx-version-min=13.0 -O2 -Wall -Wextra -Werror \
  -framework IOKit -framework CoreFoundation "$WORK/Issue2ButterflyTest.c" -o "$APP/Contents/MacOS/Issue2Helper"
for arch in x86_64 arm64; do
  xcrun swiftc -target "$arch-apple-macosx13.0" -O -framework AppKit \
    "$WORK/Issue2CompatibilityTest.swift" -o "$WORK/gui-$arch"
done
xcrun lipo -create "$WORK/gui-x86_64" "$WORK/gui-arm64" -output "$APP/Contents/MacOS/Issue2CompatibilityTest"
cp "$HERE/broncode/Issue2TestInfo.plist" "$APP/Contents/Info.plist"
plutil -lint "$APP/Contents/Info.plist"
iconutil -c icns "$HERE/Assets/AppIcon.iconset" -o "$APP/Contents/Resources/AppIcon.icns"
cp "$HERE/ISSUE2-COMPATIBILITY.md" "$APP/Contents/Resources/README.md"
{
  echo 'Isolated Issue #2 experiment. No production compatibility claim.'
  git -C "$HERE" rev-parse HEAD
  git -C "$HERE" branch --show-current
  (cd "$WORK" && shasum -a 256 Issue2ButterflyTest.c Issue2CompatibilityTest.swift)
} > "$APP/Contents/Resources/BUILD-INFO.txt"
codesign --force --sign - "$APP/Contents/MacOS/Issue2Helper"
codesign --force --sign - "$APP"
codesign --verify --deep --strict "$APP"
ditto -c -k --keepParent --norsrc "$APP" "$WORK/Issue2-Butterfly-Compatibility-Test.zip"
OUT="$HERE/dist/issue2"
mkdir -p "$OUT"
cp -X "$WORK/Issue2-Butterfly-Compatibility-Test.zip" "$OUT/.candidate.zip"
mkdir "$WORK/verify"
ditto -x -k "$OUT/.candidate.zip" "$WORK/verify"
codesign --verify --deep --strict "$WORK/verify/$(basename "$APP")"
mv -f "$OUT/.candidate.zip" "$OUT/Issue2-Butterfly-Compatibility-Test.zip"
cp -X "$APP/Contents/Resources/BUILD-INFO.txt" "$HERE/ISSUE2-COMPATIBILITY.md" "$OUT/"
(cd "$OUT" && shasum -a 256 Issue2-Butterfly-Compatibility-Test.zip > SHA256SUMS.txt)
echo "Isolated test packaged, not started: $OUT"
