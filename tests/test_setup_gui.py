"""Native GUI regression: no installer, HID command or application removal is run."""
from pathlib import Path
import os
import platform
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]

@unittest.skipUnless(platform.system() == 'Darwin', 'AppKit requires macOS')
class SetupGUITests(unittest.TestCase):
    def test_native_controls_and_report_lifecycle(self):
        with tempfile.TemporaryDirectory(prefix='ecz-setup-test-') as td:
            temp = Path(td)
            bundle = temp/'Fixture.app'
            executable = bundle/'Contents/MacOS/EasyCompWizard'
            executable.parent.mkdir(parents=True)
            resources = bundle/'Contents/Resources'
            resources.mkdir()
            for lang in ['en','nl','de','fr','es','it','pt','pl']:
                shutil.copytree(ROOT/f'broncode/WizardLocalizations/{lang}.lproj', resources/f'{lang}.lproj')
            shutil.copyfile(ROOT/'broncode/SetupInfo.plist',bundle/'Contents/Info.plist')
            project = temp/'project'
            project.mkdir()
            source = (ROOT/'broncode/InstallWizard.swift').read_text()
            harness = (ROOT/'tests/setup_runtime.swift').read_text()
            (temp/'main.swift').write_text(source+'\n'+harness)
            env = dict(os.environ, CLANG_MODULE_CACHE_PATH=str(temp/'clang'),
                       SWIFT_MODULECACHE_PATH=str(temp/'swift'), ECZ_GUI_FIXTURE=str(project))
            compiled = subprocess.run(['xcrun','swiftc','-D','ECZ_TESTS',str(temp/'main.swift'),'-o',str(executable)],
                                      env=env,capture_output=True,text=True,timeout=180)
            self.assertEqual(compiled.returncode,0,compiled.stdout+compiled.stderr)
            result = subprocess.run([str(executable)],env=env,capture_output=True,text=True,timeout=30)
            self.assertEqual(result.returncode,0,result.stdout+result.stderr)
            self.assertIn('Native setup controls',result.stdout)
