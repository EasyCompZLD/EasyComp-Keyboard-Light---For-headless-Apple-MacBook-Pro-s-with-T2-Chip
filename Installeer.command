#!/bin/bash
# EasyComp Keyboard Light - lokale broncode bouwen en installeren.
# Alleen voor macOS (Intel MacBookPro16,1 / A2141).
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
APP="$HOME/Applications/EasyComp Keyboard Light.app"
CONTENTS="$APP/Contents"
LABEL="nl.easycompzeeland.KeyboardLight"
AGENT="$HOME/Library/LaunchAgents/$LABEL.plist"
TMPDIR_BUILD="$(mktemp -d "${TMPDIR:-/tmp}/ecz-keyboardlight.XXXXXXXX")"
trap 'rm -rf "$TMPDIR_BUILD"' EXIT

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo 'Fout: dit installatieprogramma is alleen voor macOS.' >&2
  exit 1
fi
if [[ "$(id -u)" == "0" ]]; then
  echo 'Voer de installer uit als gewone gebruiker, niet met sudo.' >&2
  exit 1
fi
MODEL="$(sysctl -n hw.model 2>/dev/null || true)"
if [[ "$MODEL" != "MacBookPro16,1" ]]; then
  echo "Niet ondersteund model: $MODEL (verwacht: MacBookPro16,1)." >&2
  exit 1
fi
if ! xcrun --find clang >/dev/null 2>&1 || ! xcrun --find swiftc >/dev/null 2>&1; then
  echo 'Apple Command Line Tools ontbreken. Installeer ze met:' >&2
  echo '  xcode-select --install' >&2
  exit 1
fi
if [[ ! -f "$HERE/broncode/HIDBacklight.c" || ! -f "$HERE/broncode/EasyCompKeyboardLight.swift" || ! -f "$HERE/broncode/Info.plist" || ! -d "$HERE/Assets/AppIcon.iconset" ]]; then
  echo 'Broncode ontbreekt. Pak eerst de volledige ZIP uit.' >&2
  exit 1
fi
if ! command -v iconutil >/dev/null 2>&1; then
  echo "iconutil ontbreekt; dit is standaard aanwezig op macOS." >&2
  exit 1
fi
for lang in en nl de fr es it pt pl; do
  if [[ ! -f "$HERE/broncode/Localizations/$lang.lproj/Localizable.strings" ]]; then
    echo "Vertaling ontbreekt: $lang" >&2
    exit 1
  fi
done

printf '\n== EasyComp Keyboard Light ==\n'
echo 'Stap 1/4: de bekende T2-HID-driver compileren...'
xcrun clang -O2 -Wall -Wextra -framework IOKit -framework CoreFoundation \
  "$HERE/broncode/HIDBacklight.c" -o "$TMPDIR_BUILD/ecz-a2141-backlight"

# Stop voordat iets wordt geïnstalleerd als het apparaat niet het bewezen protocol heeft.
"$TMPDIR_BUILD/ecz-a2141-backlight" probe > "$TMPDIR_BUILD/probe.log" 2>&1 || {
  cat "$TMPDIR_BUILD/probe.log"
  echo 'Fout: HID-probe mislukt. Niets geïnstalleerd.' >&2
  exit 1
}
if ! grep -q 'Protocolcontrole: OK' "$TMPDIR_BUILD/probe.log"; then
  cat "$TMPDIR_BUILD/probe.log"
  echo 'Fout: HID-protocol wijkt af. Niets geïnstalleerd.' >&2
  exit 1
fi

echo 'Stap 2/4: de native menubalkapp compileren...'
xcrun swiftc -O -framework AppKit -framework CoreGraphics \
  "$HERE/broncode/EasyCompKeyboardLight.swift" \
  -o "$TMPDIR_BUILD/EasyCompKeyboardLight"

echo 'Stap 3/4: appicoon en 8 talen installeren...'
# Maak een echte Finder/Dock .icns, volledig offline, vanuit de meegeleverde iconset.
iconutil -c icns "$HERE/Assets/AppIcon.iconset" -o "$TMPDIR_BUILD/AppIcon.icns"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"
cp "$TMPDIR_BUILD/AppIcon.icns" "$CONTENTS/Resources/AppIcon.icns"
cp -R "$HERE/broncode/Localizations/"*.lproj "$CONTENTS/Resources/"
cp "$TMPDIR_BUILD/ecz-a2141-backlight" "$CONTENTS/MacOS/ecz-a2141-backlight"
cp "$TMPDIR_BUILD/EasyCompKeyboardLight" "$CONTENTS/MacOS/EasyCompKeyboardLight"
cp "$HERE/broncode/Info.plist" "$CONTENTS/Info.plist"
/usr/bin/plutil -lint "$CONTENTS/Info.plist" >/dev/null
chmod 755 "$CONTENTS/MacOS/ecz-a2141-backlight" "$CONTENTS/MacOS/EasyCompKeyboardLight"
# Ad-hoc ondertekening: app is lokaal gebouwd, zonder Apple Developer-certificaat.
/usr/bin/codesign --force --deep --sign - "$APP" > /dev/null

echo 'Stap 4/4: automatisch starten bij aanmelden...'
mkdir -p "$HOME/Library/LaunchAgents"
# Als de app eerder door launchd werd gestart, eerst de oude job ontladen.
/bin/launchctl bootout "gui/$(id -u)/$LABEL" >/dev/null 2>&1 || true
# HTML/XML-escapen van het volledige pad (ook voor spaties, &, <, >, dubbele quotes).
APP_EXEC="$CONTENTS/MacOS/EasyCompKeyboardLight"
ESCAPED_EXEC="$(printf '%s' "$APP_EXEC" | sed -e 's/\&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' -e 's/"/\&quot;/g')"
cat > "$AGENT" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key><array><string>$ESCAPED_EXEC</string></array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><false/>
  <key>LimitLoadToSessionType</key><string>Aqua</string>
</dict></plist>
EOF
/usr/bin/plutil -lint "$AGENT"
if /bin/launchctl bootstrap "gui/$(id -u)" "$AGENT"; then
  echo 'De menubalkapp is gestart via launchd.'
else
  echo 'launchd kon de app niet meteen starten. Ik probeer open...'
  /usr/bin/open "$APP"
fi
printf '\nGeïnstalleerd: %s\n' "$APP"
echo 'Klik rechtsboven op het toetsenbordicoon voor helderheid, aan/uit, taal en autostart.'
echo 'Het Finder-appicoon is geïnstalleerd; taal wordt automatisch gekozen op basis van macOS.'
echo 'Voor de bestaande Touch Bar-knoppen kan Toetsmonitoring-toestemming nodig zijn.'
echo 'De app gebruikt geen sudo, SIP-wijzigingen of kernel-extensies.'
