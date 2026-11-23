"""Exercise native executable routing and fail-closed source binding without real HID calls."""
from pathlib import Path
import hashlib
import os
import platform
import plistlib
import shutil
import subprocess
import tempfile
import unittest

ROOT=Path(__file__).resolve().parents[1]
SOURCES=['HIDBacklight.c','HIDBridge.c','HIDBridge.h']

@unittest.skipUnless(platform.system()=='Darwin','Native macOS binaries required')
class NativeHostTests(unittest.TestCase):
    def test_native_swift_entry_points_use_host_before_appkit(self):
        with tempfile.TemporaryDirectory(prefix='ecz-host-routing-') as td:
            temp=Path(td)
            shutil.copyfile(ROOT/'broncode/HIDBridge.h',temp/'HIDBridge.h')
            (temp/'mock.c').write_text(r'''
#include "HIDBridge.h"
#include <stdio.h>
#include <string.h>
int32_t ECZBacklightRun(const char *mode,const char *level,int32_t readonly) {
    printf("HOST_FIXTURE readonly=%d mode=%s level=%s\n",readonly,mode,level?level:"");
    if(strcmp(mode,"probe") && strcmp(mode,"permissions") && strcmp(mode,"diagnose") && strcmp(mode,"on") && strcmp(mode,"off"))return 2;
    if(readonly && (!strcmp(mode,"on") || !strcmp(mode,"off")))return 2;
    return 0;
}
''')
            subprocess.run(['xcrun','clang','-c',str(temp/'mock.c'),'-o',str(temp/'mock.o')],check=True,capture_output=True)
            env=dict(os.environ,CLANG_MODULE_CACHE_PATH=str(temp/'clang'),SWIFT_MODULECACHE_PATH=str(temp/'swift'))
            for source,name,readonly in [('InstallWizard.swift','EasyCompWizard',1),('EasyCompKeyboardLight.swift','EasyCompKeyboardLight',0)]:
                snapshot=temp/source
                snapshot.write_text((ROOT/'broncode'/source).read_text())
                exe=temp/name
                built=subprocess.run(['xcrun','swiftc','-import-objc-header',str(temp/'HIDBridge.h'),str(temp/'mock.o'),str(snapshot),'-o',str(exe)],env=env,capture_output=True,text=True,timeout=180)
                self.assertEqual(0,built.returncode,built.stdout+built.stderr)
                for mode in ['probe','permissions','diagnose','off','on']:
                    args=['--ecz-hid',mode]+(['0.5'] if mode=='on' else [])
                    result=subprocess.run([str(exe),*args],capture_output=True,text=True,timeout=15)
                    self.assertEqual(2 if readonly and mode in ['on','off'] else 0,result.returncode,result.stdout+result.stderr)
                    self.assertIn(f'HOST_FIXTURE readonly={readonly} mode={mode}',result.stdout)
                for args in [['--ecz-hid'],['--ecz-hid','probe','extra','extra'],['--ecz-hid','unknown']]:
                    result=subprocess.run([str(exe),*args],capture_output=True,text=True,timeout=15)
                    self.assertEqual(2,result.returncode,result.stdout+result.stderr)

    def test_signed_host_selection_rejects_missing_tampered_or_stale_host(self):
        with tempfile.TemporaryDirectory(prefix='ecz-host-binding-') as td:
            temp=Path(td);project=temp/'project';sources=project/'broncode';sources.mkdir(parents=True)
            for name in SOURCES:shutil.copyfile(ROOT/'broncode'/name,sources/name)
            version=(ROOT/'VERSION').read_text().strip();(project/'VERSION').write_text(version+'\n')
            digest=hashlib.sha256(b''.join((sources/name).read_bytes() for name in SOURCES)).hexdigest()
            app=temp/'Current Setup.app';mac=app/'Contents/MacOS';mac.mkdir(parents=True)
            exe=mac/'EasyCompWizard';info=app/'Contents/Info.plist'
            (temp/'host.c').write_text('int main(void){return 0;}\n')
            subprocess.run(['xcrun','clang',str(temp/'host.c'),'-o',str(exe)],check=True,capture_output=True)
            metadata=plistlib.loads((ROOT/'broncode/SetupInfo.plist').read_bytes())
            metadata['ECZHIDSourceSHA']=digest
            def sign(changes=None):
                values=dict(metadata);values.update(changes or {})
                info.write_bytes(plistlib.dumps(values))
                subprocess.run(['/usr/bin/codesign','--force','--sign','-',str(app)],check=True,capture_output=True)
            def check(host=None,gui=True):
                env=dict(os.environ)
                for key in ['ECZ_SETUP_HID_HOST','ECZ_SETUP_REQUESTER']:env.pop(key,None)
                if gui:env['ECZ_SETUP_REQUESTER']='nl.easycompzeeland.KeyboardLight.Setup'
                if host is not None:env['ECZ_SETUP_HID_HOST']=str(host)
                script='set -euo pipefail\nsource "$1"\necz_hid_select_host "$2"\nprintf "ACTIVE=%s\\n" "$ECZ_HID_HOST_ACTIVE"\nif [[ "$ECZ_HID_HOST_ACTIVE" == 1 ]]; then printf "%s\\n" "${ECZ_HID_RUNNER[@]}"; fi\n'
                return subprocess.run(['bash','-c',script,'fixture',str(ROOT/'scripts/native-hid.sh'),str(project)],env=env,capture_output=True,text=True,timeout=20)
            sign()
            self.assertNotEqual(0,check().returncode,'GUI must not fall back without a signed host')
            cli=check(gui=False);self.assertEqual(0,cli.returncode,cli.stderr);self.assertIn('ACTIVE=0',cli.stdout)
            selected=check(exe);self.assertEqual(0,selected.returncode,selected.stderr);self.assertIn('ACTIVE=1',selected.stdout);self.assertIn('--ecz-hid',selected.stdout)
            self.assertNotEqual(0,check('/usr/bin/true').returncode)
            for changes in [{'ECZDevelopmentVersion':'0.0.1'},{'CFBundleIdentifier':'other.app'},{'ECZHIDHostProtocol':2},{'ECZHIDSourceSHA':'0'*64}]:
                sign(changes);self.assertNotEqual(0,check(exe).returncode,str(changes))
            sign();changed=dict(metadata);changed['CFBundleDisplayName']='Tampered';info.write_bytes(plistlib.dumps(changed))
            self.assertNotEqual(0,check(exe).returncode,'Invalid signature must stop selection')
            sign();(sources/'HIDBacklight.c').write_text((sources/'HIDBacklight.c').read_text()+'\n')
            self.assertNotEqual(0,check(exe).returncode,'Stale native code must not authorize changed source')
