#!/bin/bash
# EasyComp Keyboard Light - verwijdert de app en de gebruikers-LaunchAgent.
set -euo pipefail
LABEL='nl.easycompzeeland.KeyboardLight'
AGENT="$HOME/Library/LaunchAgents/$LABEL.plist"
APP="$HOME/Applications/EasyComp Keyboard Light.app"
if [[ "$(uname -s)" != 'Darwin' ]]; then echo 'Alleen macOS.' >&2; exit 1; fi
if [[ "$(id -u)" == 0 ]]; then echo 'Niet uitvoeren met sudo.' >&2; exit 1; fi
/bin/launchctl bootout "gui/$(id -u)/$LABEL" >/dev/null 2>&1 || true
rm -f "$AGENT"
rm -rf "$APP"
echo 'EasyComp Keyboard Light en de autostart zijn verwijderd.'
echo 'De opgeslagen helderheid in macOS-voorkeuren blijft behouden.'
