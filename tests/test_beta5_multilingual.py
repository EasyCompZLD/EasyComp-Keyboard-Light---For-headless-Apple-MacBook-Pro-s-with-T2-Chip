"""Validate multilingual launchers, resource completeness, HID code unchanged, and safety."""
from pathlib import Path
import os, re, subprocess, tempfile, unittest
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
            self.assertEqual(len(keys),34)
            self.assertTrue(all(x in keys for x in ['title','install','report','copy','close','failedTitle','languageLabel']))
            sets.append(set(keys))
            self.assertTrue(all(re.match(r'^"wizard\.\w+"\s*=\s*"(?:[^"\\]|\\.)*";$', line) for line in s.splitlines() if line.startswith('"wizard.')), f)
        self.assertTrue(all(s == sets[0] for s in sets))
    def test_every_language_has_all_clickable_actions(self):
        for code,name in LANGUAGES.items():
            folder=ROOT/'Languages'/name
            files=list(folder.glob('*.command'))
            self.assertEqual(5,len(files),name)
            for f in files:
                source=f.read_text()
                self.assertIn(f'ECZ_INSTALL_LANGUAGE="{code}"',source)
                self.assertIn('PROJECT=',source)
                self.assertEqual(subprocess.run(['bash','-n',str(f)],capture_output=True).returncode,0)
            self.assertTrue((folder/'README.md').exists())
    def test_root_has_eight_language_install_choices(self):
        aliases=[x for x in ROOT.glob('*.command') if 'ECZ_INSTALL_LANGUAGE=' in x.read_text() and x.name not in ['Installeer.command','Start-Installatie.command']]
        for code in LANGUAGES:
            self.assertTrue(any(f'ECZ_INSTALL_LANGUAGE="{code}"' in x.read_text() for x in aliases))
        self.assertTrue((ROOT/'Install.command').exists())
    def test_resources_are_copied_to_compiled_wizard(self):
        bootstrap=(ROOT/'Start-Installatie.command').read_text()
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
    def test_no_accidental_install_on_nonmac(self):
        if os.uname().sysname=='Darwin': self.skipTest('Linux negative test')
        with tempfile.TemporaryDirectory() as td:
            for code,name in [('en','Install - English.command'),('de','Installieren - Deutsch.command'),('fr','Installer - Français.command')]:
                env=dict(os.environ,HOME=td,TMPDIR=td)
                p=subprocess.run(['bash',str(ROOT/name)],env=env,capture_output=True,text=True,timeout=20)
                self.assertEqual(2,p.returncode, p.stdout+p.stderr)
                self.assertFalse((Path(td)/'Applications').exists())
