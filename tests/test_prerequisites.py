"""Behavioral tests for developer tool discovery and Apple install-on-demand.

Mock system executables: do not modify the host and do not attempt to install Xcode.
These are shell integration tests; actual macOS compilers require an Apple host.
"""
from pathlib import Path
import os, subprocess, tempfile, unittest
ROOT=Path(__file__).resolve().parents[1]
SCRIPT=ROOT/'scripts/developer-tools.sh'

class ApplePrerequisiteTests(unittest.TestCase):
    def harness(self, mode, scenario):
        with tempfile.TemporaryDirectory(prefix='ecz-prereq-test-') as tmp:
            stub=Path(tmp)
            toolchain=stub/'Xcode.app'/'Contents'/'Developer'
            toolchain.mkdir(parents=True)
            for tool in ('clang','swiftc'):
                p=stub/tool
                p.write_text('#!/bin/sh\nexit 0\n')
                p.chmod(0o755)
            # Native Bash mocks only; the production wrappers still use /usr/bin.
            code = r'''
source "$1"
MOCK_TOOLS="$2"
MOCK_SELECTED="$3"
MOCK_SCENARIO="$4"
uname() { echo Darwin; }
ecz_prereq_check_system_utilities() { return 0; }
ecz_prereq_xcrun_exists() { return 0; }
ecz_prereq_active_developer_dir() { echo "$MOCK_SELECTED"; }
ecz_prereq_install_dialog_exists() { return 0; }
ecz_prereq_xcrun() {
  local tool="$1" required=no
  if [[ "$MOCK_SCENARIO" == xcode || "$MOCK_SCENARIO" == xcode-broken ]] && [[ "${DEVELOPER_DIR:-}" == "$MOCK_SELECTED" ]]; then required=yes; fi
  if [[ "$MOCK_SCENARIO" == auto ]] && [[ -e "$MOCK_TOOLS/installed.flag" ]]; then required=yes; fi
  [[ "$required" == yes ]] || return 1
  if [[ "$tool" == --find ]]; then
    echo "$MOCK_TOOLS/$2"
    return 0
  fi
  if [[ "$2" == --version ]]; then
    if [[ "$MOCK_SCENARIO" == xcode-broken ]]; then return 1; fi
    echo 'Apple compiler mock, 1.0'
    return 0
  fi
  return 1
}
ecz_prereq_install_dialog() {
  if [[ "$MOCK_SCENARIO" == cancel ]]; then echo 'macOS installation was rejected'; return 1; fi
  touch "$MOCK_TOOLS/installed.flag"
  echo 'Requested official Apple CLT installation'
}
ecz_prereq_sleep() { :; }
export DEVELOPER_DIR="$MOCK_TOOLS/non-existent-developer-dir"
export SDKROOT="$MOCK_TOOLS/non-existent-sdk"
export TOOLCHAINS='non-existent-toolchain'
rc=0
ecz_require_developer_tools "$5" || rc=$?
echo "RESULT_DIR=${DEVELOPER_DIR:-unset}"
echo "RESULT_SDK=${SDKROOT:-unset}"
exit "$rc"
'''
            env=os.environ.copy()
            env['PATH']='/usr/bin:/bin:/usr/sbin:/sbin'
            out=subprocess.run(['bash','-c',code,'--',str(SCRIPT),str(stub),str(toolchain),scenario,mode],
                               capture_output=True,text=True,env=env,timeout=20)
            return out

    def test_existing_xcode_recovered_from_stale_gui_environment(self):
        p=self.harness('--install-if-missing','xcode')
        self.assertEqual(0,p.returncode,p.stdout+p.stderr)
        self.assertIn('Apple developer tools available',p.stdout)
        self.assertIn('RESULT_DIR=',p.stdout)
        self.assertIn('/Xcode.app/Contents/Developer',p.stdout)
        self.assertIn('RESULT_SDK=unset',p.stdout)
        self.assertNotIn('Requested official Apple CLT installation',p.stdout)

    def test_missing_compilers_trigger_official_install_and_resume(self):
        p=self.harness('--install-if-missing','auto')
        self.assertEqual(0,p.returncode,p.stdout+p.stderr)
        self.assertIn('Starting the official Apple Command Line Tools installer',p.stdout)
        self.assertIn('Continuing automatically',p.stdout)
        self.assertIn('RESULT_SDK=unset',p.stdout)

    def test_xcode_present_but_unusable_never_installs_duplicate_clt(self):
        p=self.harness('--install-if-missing','xcode-broken')
        self.assertEqual(8,p.returncode,p.stdout+p.stderr)
        self.assertIn('exist but cannot run',p.stderr)
        self.assertNotIn('Starting the official Apple Command Line Tools installer',p.stdout)
        self.assertNotIn('Requested official Apple CLT installation',p.stdout)

    def test_diagnostics_does_not_launch_apple_install(self):
        p=self.harness('--check-only','none')
        self.assertEqual(4,p.returncode,p.stdout+p.stderr)
        self.assertIn('No installation was started',p.stderr)
        self.assertNotIn('Requested official Apple CLT installation',p.stdout)

    def test_rejected_clt_install_fails_without_claiming_success(self):
        p=self.harness('--install-if-missing','cancel')
        self.assertEqual(6,p.returncode,p.stdout+p.stderr)
        self.assertIn('could not start the developer tools installer',p.stderr)
        self.assertNotIn('Continuing automatically',p.stdout)

    def test_prerequisite_status_messages_available_in_all_eight_languages(self):
        code = 'source "$1"; ECZ_LANGUAGE="$2"; ecz_t prereq.present; ecz_t prereq.approval'
        expected = {'en':'Apple developer tools available', 'nl':'Apple-ontwikkeltools beschikbaar',
                    'de':'Apple-Entwicklerwerkzeuge verfügbar', 'fr':'Outils de développement Apple disponibles',
                    'es':'Herramientas de desarrollo de Apple disponibles', 'it':'Strumenti di sviluppo Apple disponibili',
                    'pt':'Ferramentas de desenvolvimento Apple disponíveis', 'pl':'Narzędzia programistyczne Apple są dostępne'}
        for language, title in expected.items():
            result = subprocess.run(['bash','-c',code,'--',str(ROOT/'scripts/cli-i18n.sh'),language],
                                    capture_output=True,text=True,timeout=10)
            self.assertEqual(0,result.returncode,result.stderr)
            self.assertIn(title,result.stdout)
            self.assertNotIn('prereq.approval',result.stdout)

    def test_all_entrypoints_use_one_shared_checker(self):
        for name in ['Start.command','Installeer.command','Controleer-build.command','Probleemrapport.command']:
            self.assertIn('scripts/developer-tools.sh',(ROOT/name).read_text(),name)
        self.assertIn('ecz_require_developer_tools --install-if-missing',(ROOT/'Installeer.command').read_text())
        self.assertIn('ecz_require_developer_tools --install-if-missing',(ROOT/'Start.command').read_text())
        self.assertIn('ecz_require_developer_tools --check-only',(ROOT/'Controleer-build.command').read_text())
        self.assertNotIn('sudo ',(ROOT/'scripts/developer-tools.sh').read_text())

if __name__ == '__main__': unittest.main()
