#!/bin/bash
# Shared source binding and signed native-host validation. Never skip a HID probe.
ecz_hid_digest() {
  local directory="$1"
  cat "$directory/HIDBacklight.c" "$directory/HIDBridge.c" "$directory/HIDBridge.h" 2>/dev/null | /usr/bin/shasum -a 256 | awk '{print $1}'
}
ecz_hid_stamp() {
  local directory="$1" info="$2" digest
  digest="$(ecz_hid_digest "$directory")" || return 1
  [[ "$digest" =~ ^[0-9a-f]{64}$ ]] || return 1
  /usr/bin/plutil -replace ECZHIDSourceSHA -string "$digest" "$info"
}
ecz_hid_select_host() {
  local project="$1" host="${ECZ_SETUP_HID_HOST:-}" contents bundle identifier executable version protocol digest expected
  ECZ_HID_RUNNER=()
  ECZ_HID_HOST_ACTIVE=0
  if [[ -z "$host" ]]; then
    [[ "${ECZ_SETUP_REQUESTER:-}" != 'nl.easycompzeeland.KeyboardLight.Setup' ]] && return 0
    echo 'Signed Setup HID host missing; no temporary-helper fallback in the GUI.' >&2; return 1
  fi
  [[ "$host" == /*/Contents/MacOS/EasyCompWizard && -x "$host" ]] || return 1
  contents="$(dirname "$(dirname "$host")")"; bundle="$(dirname "$contents")"
  identifier="$(/usr/bin/plutil -extract CFBundleIdentifier raw -o - "$contents/Info.plist" 2>/dev/null)" || return 1
  executable="$(/usr/bin/plutil -extract CFBundleExecutable raw -o - "$contents/Info.plist" 2>/dev/null)" || return 1
  version="$(/usr/bin/plutil -extract ECZDevelopmentVersion raw -o - "$contents/Info.plist" 2>/dev/null)" || return 1
  protocol="$(/usr/bin/plutil -extract ECZHIDHostProtocol raw -o - "$contents/Info.plist" 2>/dev/null)" || return 1
  digest="$(/usr/bin/plutil -extract ECZHIDSourceSHA raw -o - "$contents/Info.plist" 2>/dev/null)" || return 1
  expected="$(ecz_hid_digest "$project/broncode")" || return 1
  [[ "$identifier" == 'nl.easycompzeeland.KeyboardLight.Setup' && "$executable" == EasyCompWizard && "$version" == "$(cat "$project/VERSION")" && "$protocol" == 1 && "$digest" == "$expected" ]] || return 1
  /usr/bin/codesign --verify --deep --strict "$bundle" >/dev/null 2>&1 || return 1
  ECZ_HID_RUNNER=("$host" '--ecz-hid')
  ECZ_HID_HOST_ACTIVE=1
}
