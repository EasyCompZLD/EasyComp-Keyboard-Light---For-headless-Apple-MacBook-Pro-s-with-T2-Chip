#!/bin/bash
# EasyComp Keyboard Light - privacy-conscious, local issue report generator.
# Compatible with the installer: --installer-failure REASON EXIT_CODE LOG_FILE PROBE_FILE
# Never submits anything to GitHub automatically; diagnosis never writes HID reports.
set -u
set -o pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/scripts/cli-i18n.sh"
source "$HERE/scripts/developer-tools.sh"
REPO_URL='https://github.com/EasyCompZLD/EasyComp-Keyboard-Light---For-headless-Apple-MacBook-Pro-s-with-T2-Chip'
ISSUE_URL="$REPO_URL/issues/new?template=installation_failure.md"
MODE="${1:-manual}"
REASON="${2:-Not provided}"
EXIT_CODE="${3:-N/A}"
INSTALL_LOG="${4:-}"
PROBE_LOG="${5:-}"
REPORT_VERSION="1.2.0-beta"

# Reject any unexpected internal invocation rather than interpreting arguments as commands.
if [[ "$MODE" != manual && "$MODE" != --installer-failure ]]; then
  echo 'Gebruik: bash Probleemrapport.command' >&2
  exit 2
fi

report_location="${HOME:-/tmp}/Downloads"
if ! mkdir -p "$report_location" 2>/dev/null || [[ ! -w "$report_location" ]]; then
  report_location="${TMPDIR:-/tmp}"
fi
NOW="$(date '+%Y%m%d-%H%M%S' 2>/dev/null || echo unknown)"
REPORT="$report_location/EasyComp-Keyboard-Light-Report-${NOW}-$$.txt"
TEMP="$(mktemp -d "${TMPDIR:-/tmp}/ecz-kbl-report.XXXXXXXX" 2>/dev/null || true)"
if [[ -z "$TEMP" || ! -d "$TEMP" ]]; then
  echo 'Could not create a temporary diagnostic directory.' >&2
  exit 1
fi
trap 'rm -rf "$TEMP"' EXIT

# Keep logs useful for debugging while hiding macOS home folders, unique temp paths,
# IPv4 addresses, email addresses, MAC addresses, UUIDs and common credential syntax.
# This is best-effort redaction: user should review before sharing.
sanitize() {
  LC_ALL=C sed -E \
    -e 's#/Users/[^/:]+#/Users/[REDACTED]#g' \
    -e 's#/home/[^/:]+#/home/[REDACTED]#g' \
    -e 's#/var/folders/[^[:space:]:]+#[TEMP_PATH]#g' \
    -e 's#[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}#[EMAIL_REDACTED]#g' \
    -e 's#([[:xdigit:]]{2}:){5}[[:xdigit:]]{2}#[MAC_REDACTED]#g' \
    -e 's#[[:xdigit:]]{8}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{12}#[UUID_REDACTED]#g' \
    -e 's#([0-9]{1,3}\.){3}[0-9]{1,3}#[IP_REDACTED]#g' \
    -e 's#(Serial Number|SerialNumber|Hardware UUID|HardwareUUID|IOPlatformSerialNumber|Password|password|token|api_key)[[:space:]:=]+[^[:space:]]+#\1: [REDACTED]#g'
}

safe_value() {
  local value="$1"
  value="${value//$'\n'/ }"
  printf '%s\n' "$value" | sanitize | head -c 280
  printf '\n'
}
read_cmd() { "$@" 2>/dev/null || printf 'Unavailable\n'; }

# All remaining content is generated locally. No device identifiers beyond model and
# Apple vendor/product/usage descriptors are read. Do not collect system_profiler -detailLevel full.
{
  echo '=== EasyComp Keyboard Light: installation / compatibility report ==='
  echo "Report schema: 1"
  echo "Project version: $REPORT_VERSION"
  echo 'Privacy: no serial numbers, hardware UUID, username, user address or network identity requested.'
  echo 'IMPORTANT: Review this report yourself before pasting it into a public GitHub issue.'
  echo
  echo '--- Outcome ---'
  if [[ "$MODE" == --installer-failure ]]; then
    echo 'Result: installation failed or refused'
    printf 'Installer stage / reason: '; safe_value "$REASON"
    printf 'Exit code: '; safe_value "$EXIT_CODE"
  else
    echo 'Result: manual read-only diagnostic; installation status not assessed'
  fi
  echo
  echo '--- Mac / OS ---'
  printf 'Model identifier: '; read_cmd /usr/sbin/sysctl -n hw.model | head -n 1
  printf 'CPU architecture: '; read_cmd /usr/bin/uname -m | head -n 1
  printf 'macOS version: '; read_cmd /usr/bin/sw_vers -productVersion | head -n 1
  printf 'macOS build: '; read_cmd /usr/bin/sw_vers -buildVersion | head -n 1
  # Re-use the same detection as the actual installer. Never start CLT
  # installation when preparing a read-only diagnostic report.
  if ecz_prereq_probe_all; then
    echo 'Apple clang: available'
    echo 'Apple swiftc: available'
    echo "Selected developer tools: ${ECZ_SELECTED_DEVELOPER_DIR##*/}"
  else
    echo 'Apple toolchain: not currently usable (may be absent or misconfigured)'
    if [[ "${ECZ_PREREQ_COMPILERS_PRESENT:-0}" == 1 ]]; then
      echo 'Compilers detected but could not run; check Xcode license / first-launch setup.'
    fi
  fi
  if [[ -x /usr/bin/xcode-select ]]; then
    printf 'Active developer directory: '
    (/usr/bin/xcode-select -p 2>&1 || true) | head -n 2 | sanitize
  fi
  echo
  echo '--- Package / autostart ---'
  [[ -f "$HERE/broncode/HIDBacklight.c" ]] && echo 'HIDBacklight.c: present' || echo 'HIDBacklight.c: missing'
  [[ -f "$HERE/broncode/EasyCompKeyboardLight.swift" ]] && echo 'EasyCompKeyboardLight.swift: present' || echo 'EasyCompKeyboardLight.swift: missing'
  [[ -d "$HERE/Assets/AppIcon.iconset" ]] && echo 'App icon source: present' || echo 'App icon source: missing'
  [[ -f "${HOME:-/tmp}/Library/LaunchAgents/nl.easycompzeeland.KeyboardLight.plist" ]] && echo 'Login agent: present' || echo 'Login agent: absent'
  echo
  echo '--- Read-only HID diagnostic ---'
  if [[ -f "$PROBE_LOG" && -s "$PROBE_LOG" ]]; then
    echo 'Installer HID probe output:'
    head -n 100 "$PROBE_LOG" | sanitize
  else
    echo 'No previous HID probe output available.'
  fi
  # A failed installer may have stopped before compiling the helper. Rebuild and run
  # the strictly read-only 'diagnose' mode if Apple's compiler is available.
  if [[ "$(uname -s 2>/dev/null || true)" == Darwin ]] &&
     ecz_prereq_probe_all && [[ -f "$HERE/broncode/HIDBacklight.c" ]]; then
    echo 'Fresh HID descriptor scan (no SetReport / no LED changes):'
    if /usr/bin/xcrun clang -O2 -Wall -Wextra -framework IOKit -framework CoreFoundation \
       "$HERE/broncode/HIDBacklight.c" -o "$TEMP/ecz-t2-diagnostic" >"$TEMP/compile.log" 2>&1; then
      "$TEMP/ecz-t2-diagnostic" diagnose >"$TEMP/scan.log" 2>&1
      PROBE_RESULT=$?
      printf 'HID diagnostic exit code: %s\n' "$PROBE_RESULT"
      head -n 140 "$TEMP/scan.log" | sanitize
    else
      echo 'Could not compile the diagnostic helper:'
      head -n 45 "$TEMP/compile.log" | sanitize
    fi
  else
    echo 'Fresh HID scan skipped (macOS + Xcode Command Line Tools required).'
  fi
  echo
  echo '--- Installer diagnostic log (last 100 lines) ---'
  if [[ -n "$INSTALL_LOG" && -f "$INSTALL_LOG" ]]; then
    tail -n 100 "$INSTALL_LOG" | sanitize
  else
    echo 'No installer log provided.'
  fi
  echo
  echo '--- What happened? (please complete manually) ---'
  echo 'Did the keyboard LEDs turn on/off? '
  echo 'Did brightness adjustment work? '
  echo 'Did the Touch Bar illumination keys work with the menu CLOSED? '
  echo 'Did they work with the menu OPEN? '
  echo 'Additional notes / steps to reproduce: '
  echo
  echo '--- Issue page ---'
  echo "$ISSUE_URL"
} >"$REPORT" || { echo 'Could not save report.' >&2; exit 1; }

echo
echo '============================================='
echo ' EasyComp Keyboard Light - diagnostic report'
echo '============================================='
echo "Saved report: $REPORT"
echo "$(ecz_t report.done)"
echo 'The report was generated locally and has NOT been uploaded.'
echo 'Review it before publishing: automatic redaction is best-effort.'
echo "GitHub issue page: $ISSUE_URL"
echo
echo '--- Report preview ---'
sed -n '1,32p' "$REPORT"
echo '--- End of preview; open the file for the complete report ---'
echo
if [[ -t 0 ]]; then
  echo "$(ecz_t report.question)"
  printf 'Your choice: '
  IFS= read -r choice || choice=''
  case "$choice" in
    1|2)
      if command -v pbcopy >/dev/null 2>&1; then
        if pbcopy < "$REPORT"; then
          echo 'Report copied. Paste it into the issue with Cmd+V.'
        else
          echo 'Copy failed. Open the report file and copy it manually.'
        fi
      else
        echo 'Clipboard not available. Open the report file and copy it manually.'
      fi
      ;;
  esac
  case "$choice" in
    1|3)
      if command -v open >/dev/null 2>&1; then
        open "$ISSUE_URL" || true
      else
        echo "Open this page yourself: $ISSUE_URL"
      fi
      ;;
    4)
      if command -v open >/dev/null 2>&1; then
        open -a TextEdit "$REPORT" || echo "Open manually: $REPORT"
      else
        echo "Open manually: $REPORT"
      fi
      ;;
  esac
fi
exit 0
