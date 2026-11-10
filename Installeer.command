#!/bin/bash
# EasyComp Keyboard Light v1.2.0-beta6: safe, locally compiled installation.
# Public entry point for CLI users; GUI wizard calls this script as a child.
# Does not require sudo, SIP changes, kernel extensions or a network connection.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/scripts/cli-i18n.sh"
source "$HERE/scripts/developer-tools.sh"
APP="$HOME/Applications/EasyComp Keyboard Light.app"
LABEL='nl.easycompzeeland.KeyboardLight'
AGENT="$HOME/Library/LaunchAgents/$LABEL.plist"
USER_APPS="$HOME/Applications"
mkdir -p "$USER_APPS"
WORK="$(mktemp -d "$USER_APPS/.ecz-kbl-build.XXXXXXXX")"
STAGE_APP="$WORK/EasyComp Keyboard Light.app"
CONTENTS="$STAGE_APP/Contents"
BACKUP_APP="$WORK/previous.app"
PREVIOUS_AGENT="$WORK/previous-agent.plist"
INSTALL_LOG="$WORK/install.log"
PROBE_LOG="$WORK/probe.log"
: > "$INSTALL_LOG"
CURRENT_STAGE='Environment checks'
FAILURE_REASON=''
SWAPPED=0
AGENT_CHANGED=0
HAD_OLD_APP=0
HAD_OLD_AGENT=0

cleanup() {
  local result=$?
  trap - EXIT
  set +e
  if (( result != 0 )); then
    # Recover previous app and LaunchAgent on a post-swap failure.
    if (( SWAPPED == 1 )); then
      echo 'Herstel: vorige installatie terugzetten...'
      /bin/launchctl bootout "gui/$(id -u)/$LABEL" >/dev/null 2>&1 || true
      rm -rf "$APP"
      if (( HAD_OLD_APP == 1 )); then
        mv "$BACKUP_APP" "$APP" || echo 'WAARSCHUWING: oude app kon niet automatisch worden teruggezet.' >&2
      fi
      if (( HAD_OLD_AGENT == 1 )); then
        cp "$PREVIOUS_AGENT" "$AGENT" || true
      else
        rm -f "$AGENT"
      fi
      if (( HAD_OLD_AGENT == 1 )) && [[ -e "$AGENT" ]]; then
        /bin/launchctl bootstrap "gui/$(id -u)" "$AGENT" >/dev/null 2>&1 || true
      fi
    fi
    echo
    echo 'INSTALLATION NOT COMPLETED. Creating local developer diagnostic report...'
    if [[ -f "$HERE/Probleemrapport.command" ]]; then
      /bin/bash "$HERE/Probleemrapport.command" --installer-failure \
          "${FAILURE_REASON:-$CURRENT_STAGE}" "$result" "$INSTALL_LOG" "$PROBE_LOG" || true
    else
      echo 'Diagnostic generator missing: Probleemrapport.command' >&2
    fi
  fi
  rm -rf "$WORK"
  exit "$result"
}
trap cleanup EXIT

fail() {
  FAILURE_REASON="$1"
  printf 'Fout: %s\n' "$FAILURE_REASON" >&2
  printf 'Failure: %s\n' "$FAILURE_REASON" >>"$INSTALL_LOG"
  exit "${2:-1}"
}
run_step() {
  CURRENT_STAGE="$1"
  shift
  printf '>> %s\n' "$CURRENT_STAGE"
  local out="$WORK/step.log" code=0
  "$@" >"$out" 2>&1 || code=$?
  cat "$out"
  {
    printf '=== %s (exit %s) ===\n' "$CURRENT_STAGE" "$code"
    cat "$out"
    printf '\n'
  } >> "$INSTALL_LOG"
  if (( code != 0 )); then
    FAILURE_REASON="$CURRENT_STAGE (exit $code)"
    exit "$code"
  fi
}

[[ "$(uname -s)" == 'Darwin' ]] || fail 'Deze installer werkt alleen op macOS.'
[[ "$(id -u)" != '0' ]] || fail 'Start als gewone gebruiker, niet via sudo.'
MODEL="$(sysctl -n hw.model 2>/dev/null || true)"
[[ "$(uname -m)" == 'x86_64' ]] || fail 'Een Intel MacBook met T2-chip is vereist.'
case "$MODEL" in
  MacBookPro16,1) : ;;
  MacBookPro15,*|MacBookPro16,*|MacBookAir8,*|MacBookAir9,1)
    if [[ "${1:-}" != '--experimental' ]]; then
      fail "Experimenteel Mac-model $MODEL; gebruik de wizard of Installeer.command --experimental."
    fi
    echo "WAARSCHUWING: testondersteuning voor $MODEL; geen bevestigde compatibiliteit."
    ;;
  *) fail "Niet-ondersteund Mac-model: $MODEL. Gebruik Probleemrapport.command." ;;
esac
CURRENT_STAGE='Check / install Apple developer prerequisites'
if ! ecz_require_developer_tools --install-if-missing; then
  fail 'Apple developer tools could not be prepared. Review the preceding diagnostics (Xcode path, first-launch requirements or Apple CLT install).'
fi
if [[ ! -f "$HERE/broncode/HIDBacklight.c" || ! -f "$HERE/broncode/EasyCompKeyboardLight.swift" || \
      ! -f "$HERE/broncode/Info.plist" || ! -d "$HERE/Assets/AppIcon.iconset" ]]; then
   fail 'Broncode/appicon ontbreekt. Pak eerst het volledige project uit.'
fi
[[ -x /usr/bin/iconutil ]] || fail 'iconutil ontbreekt (onderdeel van macOS).'
for lang in en nl de fr es it pt pl; do
  [[ -f "$HERE/broncode/Localizations/$lang.lproj/Localizable.strings" ]] || fail "Vertaling ontbreekt: $lang"
done

printf '\n== EasyComp Keyboard Light 1.2.0-beta6 ==\n'
echo "ECZ_STEP:1"
echo "$(ecz_t boot.compile)"
run_step 'Compile C HID helper' /usr/bin/xcrun clang -O2 -Wall -Wextra -framework IOKit -framework CoreFoundation \
  "$HERE/broncode/HIDBacklight.c" -o "$WORK/ecz-t2-backlight"
CURRENT_STAGE='Read-only HID protocol probe'
PROBE_STATUS=0
"$WORK/ecz-t2-backlight" probe >"$PROBE_LOG" 2>&1 || PROBE_STATUS=$?
cat "$PROBE_LOG"
{
  echo "=== HID probe (exit $PROBE_STATUS) ==="
  cat "$PROBE_LOG"
} >> "$INSTALL_LOG"
if (( PROBE_STATUS != 0 )); then
  fail "HID-protocol niet bevestigd: probe exit $PROBE_STATUS. Geen LED-commando verstuurd." "$PROBE_STATUS"
fi
grep -q 'Protocolcontrole: OK' "$PROBE_LOG" || fail 'Geen valide HID-reportdescriptor; veilig gestopt.'

echo "ECZ_STEP:2"
echo "$(ecz_t boot.bundle)"
run_step 'Compile Swift app' /usr/bin/xcrun swiftc -O -framework AppKit -framework CoreGraphics \
  "$HERE/broncode/EasyCompKeyboardLight.swift" -o "$WORK/EasyCompKeyboardLight"

echo "ECZ_STEP:3"
echo "$(ecz_t boot.save)"
run_step 'Generate app icon' /usr/bin/iconutil -c icns "$HERE/Assets/AppIcon.iconset" -o "$WORK/AppIcon.icns"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"
cp "$WORK/AppIcon.icns" "$CONTENTS/Resources/AppIcon.icns"
cp -R "$HERE/broncode/Localizations/"*.lproj "$CONTENTS/Resources/"
cp "$WORK/ecz-t2-backlight" "$CONTENTS/MacOS/ecz-t2-backlight"
cp "$WORK/EasyCompKeyboardLight" "$CONTENTS/MacOS/EasyCompKeyboardLight"
cp "$HERE/broncode/Info.plist" "$CONTENTS/Info.plist"
chmod 755 "$CONTENTS/MacOS/ecz-t2-backlight" "$CONTENTS/MacOS/EasyCompKeyboardLight"
run_step 'Validate Info.plist' /usr/bin/plutil -lint "$CONTENTS/Info.plist"
run_step 'Ad-hoc sign staged app' /usr/bin/codesign --force --deep --sign - "$STAGE_APP"

CURRENT_STAGE='Prepare login agent'
mkdir -p "$HOME/Library/LaunchAgents"
APP_EXEC="$APP/Contents/MacOS/EasyCompKeyboardLight"
ESCAPED_EXEC="$(printf '%s' "$APP_EXEC" | sed -e 's/\&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' -e 's/"/\&quot;/g')"
cat > "$WORK/agent.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key><array><string>$ESCAPED_EXEC</string></array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><false/>
  <key>LimitLoadToSessionType</key><string>Aqua</string>
</dict></plist>
PLIST
run_step 'Validate LaunchAgent' /usr/bin/plutil -lint "$WORK/agent.plist"

echo "ECZ_STEP:4"
echo "$(ecz_t boot.open)"
CURRENT_STAGE='Replace previous installation'
if [[ -d "$APP" ]]; then
  HAD_OLD_APP=1
fi
if [[ -f "$AGENT" ]]; then
  HAD_OLD_AGENT=1
  cp "$AGENT" "$PREVIOUS_AGENT"
fi
/bin/launchctl bootout "gui/$(id -u)/$LABEL" >/dev/null 2>&1 || true
if (( HAD_OLD_APP == 1 )); then mv "$APP" "$BACKUP_APP"; fi
# Mark rollback active only once any previous app has moved successfully.
SWAPPED=1
mv "$STAGE_APP" "$APP"
cp "$WORK/agent.plist" "$AGENT"
AGENT_CHANGED=1
# Explicit language launchers choose the installed app's initial menu language.
# Automatic system-language launch does not overwrite any prior app preference.
if [[ -n "${ECZ_INSTALL_LANGUAGE:-}" ]]; then
  /usr/bin/defaults write nl.easycompzeeland.KeyboardLight AppLanguage -string "$ECZ_LANGUAGE" || true
fi
CURRENT_STAGE='Start launch agent'
if ! /bin/launchctl bootstrap "gui/$(id -u)" "$AGENT"; then
  echo 'launchctl bootstrap failed; trying direct launch...'
  run_step 'Launch app via open fallback' /usr/bin/open "$APP"
fi
# The installation is now complete. Discard old app backup only after success.
rm -rf "$BACKUP_APP"
SWAPPED=0
printf '\nInstallatie voltooid: %s\n' "$APP"
echo 'De menubalkapp gebruikt dezelfde bewezen A2141 HID-reports als v1.1.0.'
echo 'Toetsmonitoring-toestemming kan nodig zijn voor Touch Bar-bediening.'
