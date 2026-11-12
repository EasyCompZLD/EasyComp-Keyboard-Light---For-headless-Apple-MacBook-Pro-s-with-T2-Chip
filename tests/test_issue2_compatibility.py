"""Isolated Issue #2 tests. All IOKit hardware APIs are replaced with fixtures."""
from pathlib import Path
import os
import platform
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]

@unittest.skipUnless(platform.system() == 'Darwin', 'IOKit/AppKit require macOS')
class Issue2CompatibilityTests(unittest.TestCase):
    def test_real_c_helper_with_mocked_hid_endpoints(self):
        cases = ['probe','default','pulse','off','no-confirmation','wrong-confirmation',
                 'extra-probe-argument','wrong-model','unknown-product','unknown-vendor',
                 'wrong-primary-page','wrong-primary-usage','no-devices','ambiguous',
                 'duplicate-signature','manager-denied','device-denied','get-unsupported',
                 'low-unsupported','off-unsupported','interrupted','timer-failed']
        cases += [f'descriptor-{i}' for i in range(1,9)] + [f'config-{i}' for i in range(1,9)]
        with tempfile.TemporaryDirectory(prefix='ecz-issue2-c-') as td:
            temp = Path(td)
            for source in ['broncode/Issue2ButterflyTest.c','tests/fixtures/issue2_hid_fixture.c']:
                (temp/Path(source).name).write_text((ROOT/source).read_text())
            build = subprocess.run(['xcrun','clang','-Wall','-Wextra',str(temp/'issue2_hid_fixture.c'),
                                    '-framework','IOKit','-framework','CoreFoundation',
                                    '-o',str(temp/'fixture')],capture_output=True,text=True,timeout=60)
            self.assertEqual(build.returncode,0,build.stdout+build.stderr)
            for case in cases:
                with self.subTest(case=case):
                    result = subprocess.run([str(temp/'fixture'),case],capture_output=True,text=True,timeout=10)
                    self.assertEqual(result.returncode,0,result.stdout+result.stderr)
                    self.assertIn('no real HID APIs invoked',result.stdout)

    def test_integrated_production_protocol_and_magic_regression(self):
        cases = ['probe','diagnose','off','wrong-model','unknown-product','unknown-vendor',
                 'wrong-primary-page','wrong-primary-usage','ambiguous','duplicate-signature',
                 'no-devices','manager-denied','device-denied','get-unsupported','write-unsupported',
                 'magic','magic-off','magic-probe','magic-rejected']
        cases += [f'level-{i/10:.1f}' for i in range(1,11)]
        cases += [f'descriptor-{i}' for i in range(1,9)] + [f'config-{i}' for i in range(1,9)]
        with tempfile.TemporaryDirectory(prefix='ecz-production-hid-') as td:
            temp = Path(td)
            for source in ['broncode/HIDBacklight.c','tests/fixtures/production_hid_fixture.c']:
                (temp/Path(source).name).write_text((ROOT/source).read_text())
            build = subprocess.run(['xcrun','clang','-Wall','-Wextra',str(temp/'production_hid_fixture.c'),
                                    '-framework','IOKit','-framework','CoreFoundation',
                                    '-o',str(temp/'fixture')],capture_output=True,text=True,timeout=60)
            self.assertEqual(build.returncode,0,build.stdout+build.stderr)
            for case in cases:
                with self.subTest(case=case):
                    result = subprocess.run([str(temp/'fixture'),case],capture_output=True,text=True,timeout=10)
                    self.assertEqual(result.returncode,0,result.stdout+result.stderr)
                    self.assertIn('no real HID APIs invoked',result.stdout)

    def test_native_gui_probe_review_and_observation_flow(self):
        with tempfile.TemporaryDirectory(prefix='ecz-issue2-gui-') as td:
            temp = Path(td)
            source = (ROOT/'broncode/Issue2CompatibilityTest.swift').read_text()
            harness = (ROOT/'tests/issue2_gui_runtime.swift').read_text()
            (temp/'main.swift').write_text(source+'\n'+harness)
            env = dict(os.environ, CLANG_MODULE_CACHE_PATH=str(temp/'clang'),
                       SWIFT_MODULECACHE_PATH=str(temp/'swift'), ECZ_ISSUE2_FIXTURE=str(temp))
            build = subprocess.run(['xcrun','swiftc','-D','ECZ_TESTS',str(temp/'main.swift'),
                                    '-o',str(temp/'gui')],env=env,capture_output=True,text=True,timeout=180)
            self.assertEqual(build.returncode,0,build.stdout+build.stderr)
            result = subprocess.run([str(temp/'gui')],env=env,capture_output=True,text=True,timeout=20)
            self.assertEqual(result.returncode,0,result.stdout+result.stderr)
            self.assertIn('Issue2 GUI fixture passed',result.stdout)
