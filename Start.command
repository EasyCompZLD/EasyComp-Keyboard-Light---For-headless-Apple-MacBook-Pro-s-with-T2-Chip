#!/bin/bash
# EasyComp Keyboard Light 1.2.1-dev.1
# First-run bootstrap: compile a REAL native Mach-O .app on this Mac, then open it.
# This .command is the entry point for new installations and keeps an error log.
set -Eeuo pipefail

PROJECT="$(cd "$(dirname "$0")" && pwd -P)"
# Localized messages and user-selected language. Original technical filenames remain stable.
source "$PROJECT/scripts/cli-i18n.sh"
source "$PROJECT/scripts/developer-tools.sh"
REQUESTED_LANGUAGE="${ECZ_INSTALL_LANGUAGE:-auto}"
APP="$HOME/Library/Application Support/EasyComp Keyboard Light/EasyComp Keyboard Light Setup.app"
ISSUE_URL='https://github.com/EasyCompZLD/EasyComp-Keyboard-Light---For-headless-Apple-MacBook-Pro-s-with-T2-Chip/issues/new?template=installation_failure.md'
DOWNLOADS="$HOME/Downloads"
if ! mkdir -p "$DOWNLOADS" 2>/dev/null || [[ ! -w "$DOWNLOADS" ]]; then DOWNLOADS="${TMPDIR:-/tmp}"; fi
LOG="$DOWNLOADS/EasyComp-Keyboard-Light-Wizard-Startup-$(date +%Y%m%d-%H%M%S)-$$.log"
TMP=''
STAGE=''
BUILD_OK=0

# Keep terminal visible when launched from Finder; if invoked noninteractively,
# allow the caller to receive a meaningful nonzero exit code.
finish() {
  local code=$?
  trap - EXIT
  [[ -z "$TMP" ]] || rm -rf "$TMP"
  if (( code != 0 )); then
    printf '\n%s (exit %d).\n' "$(ecz_t boot.failed)" "$code" >&2
    printf 'Diagnostic log: %s\n' "$LOG" >&2
    printf 'GitHub issues: %s\n' "$ISSUE_URL" >&2
    if [[ "$(uname -s)" == Darwin ]]; then
      /usr/bin/osascript - "$(ecz_t boot.failed)" "$LOG" <<'APPLESCRIPT' >/dev/null 2>&1 || true
on run argv
    set messageText to item 1 of argv
    set logPath to item 2 of argv
    display dialog messageText & return & return & "Diagnostic log:" & return & logPath buttons {"OK"} default button 1 with title "EasyComp Keyboard Light" with icon caution
end run
APPLESCRIPT
    fi
    if [[ -t 0 ]]; then
      printf '\n%s ' "$(ecz_t boot.close)"
      read -r _unused || true
    fi
  fi
  exit "$code"
}
trap finish EXIT

# Terminal output is also recorded locally. This bootstrap intentionally never
# sends the report or any collected information to GitHub.
exec > >(tee -a "$LOG") 2>&1
printf '\n== EasyComp Keyboard Light 1.2.1-dev.1 — %s ==\n' "$(ecz_t boot.title)"
printf 'Opstartlog / startup log: %s\n' "$LOG"

if [[ "$(uname -s)" != Darwin ]]; then
  echo "$(ecz_t boot.nonmac)"
  exit 2
fi
if [[ "$(id -u)" == 0 ]]; then
  echo "$(ecz_t boot.noroot)"
  exit 2
fi
if [[ ! -f "$PROJECT/broncode/InstallWizard.swift" || ! -f "$PROJECT/Installeer.command" || ! -d "$PROJECT/broncode/WizardLocalizations" ]]; then
  echo "$(ecz_t boot.incomplete)"
  exit 3
fi
# Check existing Xcode / CLT first. If both compilers are truly missing, start
# Apple's official install dialog, wait for completion, then continue immediately.
# This is a one-click bootstrap: users do not have to reopen the wizard.
if ! ecz_require_developer_tools --install-if-missing; then
  echo "$(ecz_t boot.tools)"
  echo 'Developer tool setup could not be completed. See the startup log above.'
  exit 4
fi

TMP="$(mktemp -d "${TMPDIR:-/tmp}/ecz-wizard-bootstrap.XXXXXXXX")"
STAGE="$TMP/EasyComp Keyboard Light Setup.app"
mkdir -p "$STAGE/Contents/MacOS" "$STAGE/Contents/Resources"

cp "$PROJECT/broncode/SetupInfo.plist" "$STAGE/Contents/Info.plist"

echo "$(ecz_t boot.compile)"
export CLANG_MODULE_CACHE_PATH="$TMP/clang-cache"
export SWIFT_MODULECACHE_PATH="$TMP/swift-cache"
cp "$PROJECT/broncode/InstallWizard.swift" "$TMP/InstallWizard.swift"
/usr/bin/xcrun swiftc -framework AppKit \
  "$TMP/InstallWizard.swift" \
  -o "$STAGE/Contents/MacOS/EasyCompWizard"
chmod 755 "$STAGE/Contents/MacOS/EasyCompWizard"

echo "$(ecz_t boot.bundle)"
for lang in en nl de fr es it pt pl; do
  if [[ ! -f "$PROJECT/broncode/WizardLocalizations/$lang.lproj/Localizable.strings" ]]; then
    echo "Missing setup translation: $lang" >&2
    exit 3
  fi
  cp -R "$PROJECT/broncode/WizardLocalizations/$lang.lproj" "$STAGE/Contents/Resources/"
done
/usr/bin/iconutil -c icns "$PROJECT/Assets/AppIcon.iconset" \
  -o "$STAGE/Contents/Resources/AppIcon.icns"
/usr/bin/plutil -lint "$STAGE/Contents/Info.plist"
/usr/bin/codesign --force --sign - "$STAGE"
/usr/bin/codesign --verify "$STAGE"

echo "$(ecz_t boot.save)"
# Previous source-based shell launcher is not shipped. A locally compiled native
# wizard is installed only after all build, bundle and signature checks pass.
mkdir -p "$(dirname "$APP")"
if [[ -e "$APP" ]]; then
  mv "$APP" "$TMP/old-setup.app"
fi
if ! mv "$STAGE" "$APP"; then
  if [[ -d "$TMP/old-setup.app" ]]; then mv "$TMP/old-setup.app" "$APP" || true; fi
  echo 'Could not replace setup wizard; previous copy restored if possible.'
  exit 6
fi

echo "$(ecz_t boot.open)"
READY="$TMP/window-ready"
/usr/bin/open -n "$APP" --args "$PROJECT" "$READY" "$REQUESTED_LANGUAGE"
# Don't mistake a successful open(1) return for a successfully launched GUI:
# the Swift application writes a marker after its window has been presented.
for ((i=0; i<30; i++)); do
  if [[ -f "$READY" ]]; then
    echo "OK: $(ecz_t boot.success)"
    echo "Setup wizard: $APP"
    BUILD_OK=1
    break
  fi
  /bin/sleep 0.5
done
if (( BUILD_OK == 0 )); then
  echo 'Wizard executable was built, but the window did not confirm opening.'
  echo 'The previous working keyboard-light app is untouched.'
  echo "Try running directly: '$APP/Contents/MacOS/EasyCompWizard' '$PROJECT'"
  echo "Please include this startup log in a GitHub issue after reviewing it."
  exit 7
fi
