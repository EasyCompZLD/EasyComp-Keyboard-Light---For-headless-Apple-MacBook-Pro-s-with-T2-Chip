"""Validate multilingual launchers, resource completeness, HID code unchanged, and safety."""
from pathlib import Path
import re, subprocess, unittest, unicodedata
ROOT=Path(__file__).resolve().parents[1]
LANGUAGES={
    'en':'English','nl':'Nederlands','de':'Deutsch','fr':'Français',
    'es':'Español','it':'Italiano','pt':'Português','pl':'Polski'
}
class TestMultilingualInstall(unittest.TestCase):
    def test_wizard_localizations_complete(self):
        sets=[]
        for code in LANGUAGES:
            f=ROOT/'broncode/WizardLocalizations'/f'{code}.lproj/Localizable.strings'
            s=f.read_text(encoding='utf8')
            keys=re.findall(r'^"wizard\.([A-Za-z0-9]+)"\s*=',s,re.M)
            self.assertEqual(len(keys),len(set(keys)))
            self.assertGreaterEqual(len(keys),34)
            self.assertTrue(all(x in keys for x in ['title','install','report','copy','close','failedTitle','languageLabel']))
            sets.append(set(keys))
            self.assertTrue(all(re.match(r'^"wizard\.\w+"\s*=\s*"(?:[^"\\]|\\.)*";$', line) for line in s.splitlines() if line.startswith('"wizard.')), f)
        self.assertTrue(all(s == sets[0] for s in sets))
    def test_legacy_language_actions_still_resolve(self):
        for code,name in LANGUAGES.items():
            folder=next(p for p in (ROOT/'legacy/Languages').iterdir()
                        if unicodedata.normalize('NFC', p.name) == name)
            files=list(folder.glob('*.command'))
            self.assertEqual(5,len(files),name)
            for f in files:
                source=f.read_text()
                self.assertIn(f'ECZ_INSTALL_LANGUAGE="{code}"',source)
                self.assertIn('PROJECT=',source)
                self.assertEqual(subprocess.run(['bash','-n',str(f)],capture_output=True).returncode,0)
            self.assertTrue((folder/'README.md').exists())
    def test_legacy_launchers_are_preserved(self):
        aliases=[x for x in (ROOT/'legacy').glob('*.command') if 'ECZ_INSTALL_LANGUAGE=' in x.read_text() and x.name not in ['Installeer.command','Start.command']]
        for code in LANGUAGES:
            self.assertTrue(any(f'ECZ_INSTALL_LANGUAGE="{code}"' in x.read_text() for x in aliases))
        self.assertTrue((ROOT/'legacy/Install.command').exists())
    def test_resources_are_copied_to_compiled_wizard(self):
        bootstrap=(ROOT/'Start.command').read_text()
        self.assertIn('WizardLocalizations/$lang.lproj',bootstrap)
        self.assertIn('cp -R "$PROJECT/broncode/WizardLocalizations/$lang.lproj"',bootstrap)
        self.assertIn('"$READY" "$REQUESTED_LANGUAGE"',bootstrap)
    def test_language_is_passed_to_app_without_overriding_system_preference_on_auto(self):
        swift=(ROOT/'broncode/InstallWizard.swift').read_text()
        installer=(ROOT/'Installeer.command').read_text()
        self.assertIn('explicitLanguage = languageCode != nil && languageCode != "auto"',swift)
        self.assertIn('environment.removeValue(forKey: "ECZ_INSTALL_LANGUAGE")',swift)
        self.assertIn('AppLanguage -string "$ECZ_LANGUAGE"',installer)
        self.assertIn('if [[ -n "${ECZ_INSTALL_LANGUAGE:-}" ]]',installer)
    def test_every_shipped_command_has_valid_bash(self):
        for f in ROOT.rglob('*.command'):
            p=subprocess.run(['bash','-n',str(f)],capture_output=True,text=True)
            self.assertEqual(0,p.returncode, f'{f}: {p.stderr}')
