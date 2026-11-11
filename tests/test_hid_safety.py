"""Source-level guardrails only; these tests cannot replace real T2 hardware tests."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]

class TestHIDSafety(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.hid = (ROOT / "broncode/HIDBacklight.c").read_text()
        cls.installer = (ROOT / "Installeer.command").read_text()
        cls.wizard = (ROOT / "broncode/InstallWizard.swift").read_text()
        cls.diagnostic = (ROOT / "Probleemrapport.command").read_text()

    def test_hid_manager_requires_exact_vendor_and_product(self):
        self.assertIn('set_number(match,CFSTR(kIOHIDVendorIDKey),APPLE_VID);', self.hid)
        self.assertIn('set_number(match,CFSTR(kIOHIDProductIDKey),pid);', self.hid)
        self.assertIn('const int pids[]={MAGIC_PID', self.hid)
        self.assertIn('IOHIDManagerSetDeviceMatching(manager,match);', self.hid)

    def test_verified_magic_report_bytes_unchanged(self):
        self.assertIn('uint8_t power[6]={3,0,0x5e,0x01,0,0}', self.hid)
        self.assertIn('uint8_t light[9]={1,0,0,0,0,0x5e,0x01,0,0}', self.hid)
        self.assertIn('put32(light+1,val)', self.hid)
        self.assertIn('magic_usage(d) && inspect_magic(d,&minB,&maxB)', self.hid)

    def test_butterfly_read_only_check_precedes_writes(self):
        self.assertIn('butterfly_usage(d) && butterfly_descriptor(d)', self.hid)
        self.assertIn('butterfly_config(d,&off,&minB,&maxB)', self.hid)
        self.assertIn('Read-only protocol check completed. No LED commands sent.', self.hid)

    def test_installer_stages_before_replacing(self):
        self.assertIn('STAGE_APP=', self.installer)
        self.assertIn("run_step 'Ad-hoc sign staged app'", self.installer)
        self.assertIn('mv "$STAGE_APP" "$APP"', self.installer)
        self.assertIn('Herstel: vorige installatie terugzetten', self.installer)

    def test_wizard_is_native_and_provides_issue_workflow(self):
        for needle in ['import AppKit', 'NSWindow(', 'NSProgressIndicator(',
                       'NSPasteboard.general', 'issuePage', 'languagePopup']:
            self.assertIn(needle, self.wizard)
        self.assertIn('p.standardInput = FileHandle.nullDevice', self.wizard)

    def test_no_automatic_reporting_or_privileged_helper(self):
        self.assertNotIn('curl ', self.diagnostic)
        self.assertNotIn('sudo ', self.installer)
        self.assertIn('No LED commands', self.hid)
        self.assertIn('ISSUE_URL=', self.diagnostic)

if __name__ == '__main__':
    unittest.main()
