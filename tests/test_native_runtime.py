"""Execute production Swift policies and reject invalid C arguments without HID access."""
from pathlib import Path
import os
import platform
import plistlib
import re
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]

@unittest.skipUnless(platform.system() == 'Darwin', 'AppKit/IOKit require macOS')
class NativeRuntimeTests(unittest.TestCase):
    def test_production_swift_policies(self):
        with tempfile.TemporaryDirectory(prefix='ecz-runtime-') as td:
            temp = Path(td)
            source = (ROOT/'broncode/EasyCompKeyboardLight.swift').read_text()
            harness = (ROOT/'tests/backlight_runtime.swift').read_text()
            (temp/'main.swift').write_text(source + '\n' + harness)
            env = dict(os.environ, CLANG_MODULE_CACHE_PATH=str(temp/'clang'),
                       SWIFT_MODULECACHE_PATH=str(temp/'swift'))
            build = subprocess.run(['xcrun', 'swiftc', '-D', 'ECZ_TESTS',
                                    str(temp/'main.swift'), '-o', str(temp/'runtime')],
                                   env=env, capture_output=True, text=True, timeout=180)
            self.assertEqual(build.returncode, 0, build.stdout + build.stderr)
            result = subprocess.run([str(temp/'runtime')], capture_output=True, text=True, timeout=15)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn('Swift runtime assertions passed', result.stdout)

    def test_c_arguments_and_configuration_without_hid_access(self):
        with tempfile.TemporaryDirectory(prefix='ecz-c-runtime-') as td:
            temp = Path(td)
            (temp/'HIDBacklight.c').write_text((ROOT/'broncode/HIDBacklight.c').read_text())
            (temp/'arguments.c').write_text(r'''
#define IOHIDManagerCreate forbidden_manager
#define IOHIDDeviceGetReport fixture_get_report
#define IOHIDDeviceSetReport forbidden_write
#define main backend_main
#include "HIDBacklight.c"
#undef main
IOHIDManagerRef forbidden_manager(CFAllocatorRef allocator, IOOptionBits options) {
    (void)allocator; (void)options; abort();
}
static int config_case;
IOReturn forbidden_write(IOHIDDeviceRef device, IOHIDReportType kind,
                         CFIndex reportID, const uint8_t *bytes, CFIndex length) {
    (void)device; (void)kind; (void)reportID; (void)bytes; (void)length; abort();
}
IOReturn fixture_get_report(IOHIDDeviceRef device, IOHIDReportType kind,
                           CFIndex reportID, uint8_t *bytes, CFIndex *length) {
    (void)device;
    if(kind!=kIOHIDReportTypeFeature || reportID!=0xbf)abort();
    uint8_t config[]={0xbf,1,0,0,10,0,100,0};
    memcpy(bytes,config,sizeof(config)); *length=sizeof(config);
    switch(config_case){
      case 1:*length=7;break;
      case 2:bytes[0]=0xb0;break;
      case 3:bytes[1]=2;break;
      case 4:bytes[2]=10;break;
      case 5:bytes[4]=0;break;
      case 6:bytes[6]=9;break;
      case 7:*length=65;break;
      case 8:return kIOReturnNotPermitted;
    }
    return kIOReturnSuccess;
}
int main(void) {
    int off=0,lo=0,hi=0;
    if(!butterfly_config(NULL,&off,&lo,&hi) || off!=0 || lo!=10 || hi!=100)return 2;
    for(config_case=1;config_case<=8;config_case++){
        if(butterfly_config(NULL,&off,&lo,&hi))return 3;
    }
    const char *values[]={"nan","NaN","inf","-inf","0","0.09","1.01","oops","0.5junk",""};
    for(size_t i=0;i<sizeof(values)/sizeof(values[0]);i++){
        char *args[]={"test","on",(char *)values[i]};
        if(backend_main(3,args)!=2)return 1;
    }
    return 0;
}
''')
            build = subprocess.run(['xcrun','clang',str(temp/'arguments.c'),'-framework','IOKit',
                                    '-framework','CoreFoundation','-o',str(temp/'arguments')],
                                   capture_output=True,text=True,timeout=60)
            self.assertEqual(build.returncode,0,build.stderr)
            result = subprocess.run([str(temp/'arguments')],capture_output=True,text=True,timeout=10)
            self.assertEqual(result.returncode,0,result.stderr)

class LocalizationCompletenessTests(unittest.TestCase):
    def test_app_keys_and_format_arguments_match(self):
        tables = []
        for code in ['en','nl','de','fr','es','it','pt','pl']:
            path = ROOT/f'broncode/Localizations/{code}.lproj/Localizable.strings'
            keys = re.findall(r'^"([^"\n]+)"\s*=', path.read_text(), re.M)
            self.assertEqual(len(keys), len(set(keys)), f'duplicate localization key: {code}')
            # Use the native parser to validate escaping and string syntax.
            if platform.system() != 'Darwin':
                self.skipTest('Apple strings parser requires macOS')
            result = subprocess.run(['plutil','-convert','xml1','-o','-',str(path)],capture_output=True)
            self.assertEqual(result.returncode,0,result.stderr)
            tables.append(plistlib.loads(result.stdout))
        for table in tables[1:]:
            self.assertEqual(set(tables[0]),set(table))
            self.assertTrue(all(table.values()))
            for key in table:
                self.assertEqual(re.findall(r'%(?:[0-9]+\$)?[@dfius]', tables[0][key]),
                                 re.findall(r'%(?:[0-9]+\$)?[@dfius]', table[key]), key)

class Issue2SafetyTests(unittest.TestCase):
    def test_confirmed_pid_retains_specific_model_interface_and_config_gates(self):
        src = (ROOT/'broncode/HIDBacklight.c').read_text()
        self.assertIn('pid==0x027d && !issue2_model()', src)
        self.assertIn('candidates!=1', src)
        self.assertIn('size!=8 || rep[0]!=0xbf || rep[1]!=1', src)
        self.assertIn('read16(rep+2)!=0', src)
        self.assertIn('read16(rep+4)!=32 || read16(rep+6)!=512', src)
        self.assertIn('butterfly_usage(d) && butterfly_descriptor(d)', src)
        candidate = src.split('static int issue2_read_candidate', 1)[1].split('static uint16_t', 1)[0]
        for expected in ['kIOHIDVendorIDKey', 'kIOHIDProductIDKey',
                         'kIOHIDPrimaryUsagePageKey', 'kIOHIDPrimaryUsageKey',
                         'IOHIDElementGetReportID(e)==0xbf', 'IOHIDElementGetReportSize(e)==120',
                         'IOHIDElementGetReportCount(e)==15', 'return found==1']:
            self.assertIn(expected, candidate)
