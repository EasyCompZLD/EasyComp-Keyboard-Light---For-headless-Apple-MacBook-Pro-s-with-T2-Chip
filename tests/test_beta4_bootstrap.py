"""Checks the beta4 bootstrap contract without relying on macOS hardware."""
from pathlib import Path
import subprocess
import tempfile
import os
import unittest

ROOT = Path(__file__).resolve().parents[1]

class TestNativeBootstrap(unittest.TestCase):
    def test_no_broken_shell_app_in_release(self):
        self.assertFalse((ROOT / 'EasyComp Keyboard Light Installer.app').exists())
        self.assertFalse((ROOT / 'EasyComp Keyboard Light Setup.app').exists())

    def test_wizard_compiled_as_real_app(self):
        source = (ROOT / 'Start-Installatie.command').read_text()
        self.assertIn('swiftc -framework AppKit', source)
        self.assertIn('Contents/MacOS/EasyCompWizard', source)
        self.assertIn('CFBundleExecutable', source)
        self.assertIn('/usr/bin/codesign --verify', source)
        self.assertIn('window-ready', source)
        self.assertIn('/usr/bin/open -n', source)
        self.assertNotIn('Contents/MacOS/Launcher', source)

    def test_wizard_signals_actual_window(self):
        source = (ROOT / 'broncode/InstallWizard.swift').read_text()
        self.assertIn('window.makeKeyAndOrderFront(nil)', source)
        self.assertIn('window-ready', source)
        self.assertIn('Bundle.main.bundleURL.deletingLastPathComponent().path', source)

    def test_startup_log_and_report_link(self):
        source = (ROOT / 'Start-Installatie.command').read_text()
        self.assertIn('Wizard-Startup-', source)
        self.assertIn('installation_failure.md', source)
        self.assertIn('read -r _unused', source)
        self.assertNotIn('curl ', source)
        self.assertNotIn('\nsudo ', source)

    def test_shipped_shell_scripts_parse(self):
        for f in ROOT.glob('*.command'):
            result = subprocess.run(['bash','-n',str(f)],capture_output=True,text=True)
            self.assertEqual(result.returncode,0,f'{f}: {result.stderr}')

    def test_non_mac_refuses_safely(self):
        if os.uname().sysname == 'Darwin':
            self.skipTest('Linux-only negative test')
        with tempfile.TemporaryDirectory() as td:
            home=Path(td)
            env=dict(os.environ,HOME=str(home),TMPDIR=td)
            p=subprocess.run(['bash',str(ROOT/'Start-Installatie.command')],env=env,capture_output=True,text=True,timeout=15)
            self.assertEqual(p.returncode,2,p.stdout+p.stderr)
            self.assertIn('requires macOS',p.stdout+p.stderr)
            self.assertFalse((home/'Applications').exists())
            logs=list((home/'Downloads').glob('EasyComp-Keyboard-Light-Wizard-Startup-*.log'))
            self.assertEqual(len(logs),1)
            self.assertIn('requires macOS',logs[0].read_text())

if __name__=='__main__': unittest.main()
