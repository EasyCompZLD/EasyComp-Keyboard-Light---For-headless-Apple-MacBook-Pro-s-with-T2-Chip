#!/bin/bash
# Shared macOS developer-tool resolution for EasyComp Keyboard Light.
# Bash 3.2 compatible. Source this file, then call ecz_require_developer_tools.
# Never switches the user's global Xcode selection, uses sudo, or fetches third-party software.
# If neither Xcode nor Apple CLT is usable, starts Apple's official installation dialog.

ecz_prereq_text() {
  if declare -f ecz_t >/dev/null 2>&1; then
    ecz_t "prereq.$1"
    return
  fi
  case "$1" in
    present) echo 'Apple developer tools available';;
    missing) echo 'No working compiler found. Starting the official Apple Command Line Tools installer.';;
    approval) echo 'Approve the macOS dialog and license. Installation will then resume automatically.';;
    resume) echo 'Apple developer tools are ready. Continuing automatically.';;
    broken) echo 'Xcode compilers exist but cannot run. Open Xcode for setup/license acceptance.';;
    failed) echo 'Apple tools could not be prepared. Check the diagnostic log.';;
    check) echo 'No usable Xcode or Command Line Tools detected. Build verification does not install software.';;
  esac
}

# Narrow wrappers make the decision logic testable with harmless local mocks.
# Production always uses Apple's fixed, trusted system executable paths.
ecz_prereq_xcrun() { /usr/bin/xcrun "$@"; }
ecz_prereq_xcrun_exists() { [[ -x /usr/bin/xcrun ]]; }
ecz_prereq_active_developer_dir() { /usr/bin/xcode-select -p; }
ecz_prereq_install_dialog() { /usr/bin/xcode-select --install; }
ecz_prereq_install_dialog_exists() { [[ -x /usr/bin/xcode-select ]]; }
ecz_prereq_sleep() { /bin/sleep "$1"; }

# Finder/LaunchServices can give GUI applications a reduced or custom PATH.
# Use Apple's system locations explicitly, without discarding other user PATH entries.
ecz_prereq_normalize_environment() {
  PATH="/usr/bin:/bin:/usr/sbin:/sbin:${PATH:-}"
  export PATH
  # These inherited overrides can point at a removed SDK/toolchain, making a valid
  # Xcode installation appear unavailable. They are not required for this project.
  unset SDKROOT TOOLCHAINS
}

ecz_prereq_probe_current() {
  local clang_path swift_path
  ecz_prereq_xcrun_exists || return 1
  clang_path=$(ecz_prereq_xcrun --find clang 2>/dev/null) || return 1
  swift_path=$(ecz_prereq_xcrun --find swiftc 2>/dev/null) || return 1
  [[ -x "$clang_path" && -x "$swift_path" ]] || return 1
  # Tools may be installed but not usable yet (e.g. Xcode license or first launch).
  # That is NOT a missing CLT installation, and we should not download duplicates.
  ECZ_PREREQ_COMPILERS_PRESENT=1
  export ECZ_PREREQ_COMPILERS_PRESENT
  ecz_prereq_xcrun clang --version >/dev/null 2>&1 || return 1
  ecz_prereq_xcrun swiftc --version >/dev/null 2>&1 || return 1
  return 0
}

ecz_prereq_probe_candidate() {
  local candidate="$1"
  if [[ -n "$candidate" ]]; then
    [[ -d "$candidate" ]] || return 1
    DEVELOPER_DIR="$candidate"
    export DEVELOPER_DIR
  else
    unset DEVELOPER_DIR
  fi
  ecz_prereq_probe_current
}

ecz_prereq_probe_all() {
  local active previous candidate
  ecz_prereq_normalize_environment
  previous="${DEVELOPER_DIR:-}"
  ECZ_PREREQ_COMPILERS_PRESENT=0
  export ECZ_PREREQ_COMPILERS_PRESENT
  active=$(ecz_prereq_active_developer_dir 2>/dev/null || true)

  # 1) Currently configured developer directory (including an explicit override).
  # 2) System-selected toolchain without any override.
  # 3) Explicit Xcode and Apple CLT locations, without changing system settings.
  if [[ -n "$previous" ]] && ecz_prereq_probe_candidate "$previous"; then
    ECZ_SELECTED_DEVELOPER_DIR="$previous"
    export ECZ_SELECTED_DEVELOPER_DIR
    return 0
  fi
  if ecz_prereq_probe_candidate ''; then
    ECZ_SELECTED_DEVELOPER_DIR='system default'
    export ECZ_SELECTED_DEVELOPER_DIR
    return 0
  fi
  for candidate in "$active" '/Applications/Xcode.app/Contents/Developer' \
                   '/Library/Developer/CommandLineTools'; do
    [[ -n "$candidate" ]] || continue
    if ecz_prereq_probe_candidate "$candidate"; then
      ECZ_SELECTED_DEVELOPER_DIR="$candidate"
      export ECZ_SELECTED_DEVELOPER_DIR
      return 0
    fi
  done
  # Support renamed/beta Xcode installations in the normal Applications directory.
  for candidate in /Applications/Xcode*.app/Contents/Developer; do
    [[ -d "$candidate" ]] || continue
    if ecz_prereq_probe_candidate "$candidate"; then
      ECZ_SELECTED_DEVELOPER_DIR="$candidate"
      export ECZ_SELECTED_DEVELOPER_DIR
      return 0
    fi
  done
  # Do not retain an invalid override after a failed scan.
  unset DEVELOPER_DIR
  ECZ_SELECTED_DEVELOPER_DIR='unavailable'
  export ECZ_SELECTED_DEVELOPER_DIR
  return 1
}

ecz_prereq_check_system_utilities() {
  local program
  for program in iconutil plutil codesign; do
    if [[ ! -x "/usr/bin/$program" ]]; then
      printf 'Required macOS system utility missing: /usr/bin/%s\n' "$program" >&2
      return 1
    fi
  done
  return 0
}

ecz_require_developer_tools() {
  local mode="${1:---install-if-missing}" dialog_output='' check=0
  [[ "$(uname -s)" == Darwin ]] || {
    echo 'The Apple toolchain is only available on macOS.' >&2
    return 2
  }
  ecz_prereq_check_system_utilities || return 3
  if ecz_prereq_probe_all; then
    printf '%s (%s).\n' "$(ecz_prereq_text present)" "$ECZ_SELECTED_DEVELOPER_DIR"
    return 0
  fi
  if [[ "$mode" == '--check-only' ]]; then
    echo "$(ecz_prereq_text check)" >&2
    echo 'Check Xcode selection and license status. No installation was started.' >&2
    return 4
  fi
  if [[ "${ECZ_PREREQ_COMPILERS_PRESENT:-0}" == 1 ]]; then
    echo "$(ecz_prereq_text broken)" >&2
    return 8
  fi

  echo "$(ecz_prereq_text missing)"
  echo "$(ecz_prereq_text approval)"
  echo 'No third-party package manager or administrator password is used by this script.'
  if ! ecz_prereq_install_dialog_exists; then
    echo 'xcode-select is not available. The operating system may be damaged.' >&2
    return 5
  fi
  dialog_output=$(ecz_prereq_install_dialog 2>&1) || check=$?
  if (( check != 0 )); then
    printf 'macOS could not start the developer tools installer (exit %s): %s\n' "$check" "$dialog_output" >&2
    echo 'If Xcode is installed, open it once to complete any first-launch or license prompts.' >&2
    echo 'Otherwise install Apple Command Line Tools using System Settings / Software Update.' >&2
    return 6
  fi
  echo "$dialog_output"
  # xcode-select --install starts a GUI installation asynchronously. Never report
  # success until BOTH compilers are usable. Users can cancel with Ctrl+C.
  local i
  for ((i=0; i<360; i++)); do
    if ecz_prereq_probe_all; then
      echo "$(ecz_prereq_text resume)"
      return 0
    fi
    ecz_prereq_sleep 10
  done
  echo "$(ecz_prereq_text failed)" >&2
  echo 'Complete the Apple installer or fix the Xcode configuration, then retry.' >&2
  return 7
}

# Compiler calls must use this absolute path, not whatever PATH Finder provided.
ecz_xcrun() { /usr/bin/xcrun "$@"; }
