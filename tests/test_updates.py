"""Execute update policies against synthetic release/ZIP data; never contact GitHub or install."""
from pathlib import Path
import os
import platform
import struct
import subprocess
import tempfile
import unittest
import warnings
import zipfile

ROOT = Path(__file__).resolve().parents[1]
PREFIX = 'EasyComp Keyboard Light Setup.app/'

@unittest.skipUnless(platform.system() == 'Darwin', 'Native Swift requires macOS')
class UpdateTests(unittest.TestCase):
    def test_release_digest_archive_policies(self):
        with tempfile.TemporaryDirectory(prefix='ecz-update-fixture-') as td:
            temp = Path(td)
            fixtures = []
            def archive(name, entries):
                path = temp / (name + '.zip')
                with warnings.catch_warnings():
                    warnings.simplefilter('ignore', UserWarning)
                    with zipfile.ZipFile(path, 'w', zipfile.ZIP_DEFLATED) as z:
                        for item, data in entries:
                            z.writestr(item, data)
                fixtures.append(path)
                return path
            valid = archive('valid-basic', [(PREFIX, b''), (PREFIX+'Contents/Info.plist', b'fixture')])
            archive('bad-traversal', [(PREFIX+'../outside', b'no')])
            archive('bad-absolute', [('/tmp/outside', b'no')])
            archive('bad-backslash', [(PREFIX+'Contents\\outside', b'no')])
            archive('bad-prefix', [('Unrelated.app/Contents/a', b'no')])
            archive('bad-duplicate', [(PREFIX+'a', b'first'), (PREFIX+'a', b'second')])
            link = zipfile.ZipInfo(PREFIX+'link')
            link.create_system = 3
            link.external_attr = 0o120777 << 16
            archive('bad-symlink', [(link, b'/tmp/outside')])
            real_package=ROOT/'dist/release/EasyComp-Keyboard-Light.zip'
            if real_package.exists():
                actual=temp/'valid-real-release.zip'
                actual.write_bytes(real_package.read_bytes())
                fixtures.append(actual)
            original = valid.read_bytes()
            central = original.index(b'PK\x01\x02')
            def altered(name, offset, value):
                data = bytearray(original)
                data[offset:offset+len(value)] = value
                path = temp / (name + '.zip')
                path.write_bytes(data)
                fixtures.append(path)
            altered('bad-encrypted', central+8, struct.pack('<H', 1))
            altered('bad-compression', central+10, struct.pack('<H', 99))
            altered('bad-expansion', central+24, struct.pack('<I', 128*1024*1024))
            altered('bad-local-name', 30, b'X')
            altered('bad-directory-offset', len(original)-6, struct.pack('<I', 0xffffffff))
            for index, raw in enumerate([b'', b'PK', bytes(range(255)), original[:20], original[:-1], original+b'junk']):
                path=temp/f'bad-truncated-{index}.zip'
                path.write_bytes(raw)
                fixtures.append(path)
            source = (ROOT/'broncode/EasyCompKeyboardLight.swift').read_text()
            harness = (ROOT/'tests/update_runtime.swift').read_text()
            (temp/'main.swift').write_text(source+'\n'+harness)
            env=dict(os.environ,CLANG_MODULE_CACHE_PATH=str(temp/'clang'),SWIFT_MODULECACHE_PATH=str(temp/'swift'))
            built=subprocess.run(['xcrun','swiftc','-D','ECZ_TESTS',str(temp/'main.swift'),'-o',str(temp/'fixture')],env=env,capture_output=True,text=True,timeout=180)
            self.assertEqual(0,built.returncode,built.stdout+built.stderr)
            completed=subprocess.run([str(temp/'fixture'),*[str(p) for p in fixtures]],capture_output=True,text=True,timeout=30)
            self.assertEqual(0,completed.returncode,completed.stdout+completed.stderr)
            self.assertIn('updater policy/archive assertions passed',completed.stdout)

    def test_update_preserves_disabled_login_item(self):
        source=(ROOT/'Installeer.command').read_text()
        snippet=source.split('mv "$STAGE_APP" "$APP"\n',1)[1].split('# Explicit language launchers',1)[0]
        with tempfile.TemporaryDirectory(prefix='ecz-login-fixture-') as td:
            temp=Path(td)
            (temp/'agent.plist').write_text('new configuration')
            for preserve, previous, expected in [('1',0,False),('1',1,True),('0',0,True),('0',1,True)]:
                agent=temp/'installed-agent.plist'
                agent.unlink(missing_ok=True)
                if previous: agent.write_text('previous configuration')
                env=dict(os.environ,WORK=str(temp),AGENT=str(agent),HAD_OLD_AGENT=str(previous),ECZ_PRESERVE_LOGIN_STATE=preserve)
                run=subprocess.run(['bash','-c','set -euo pipefail\n'+snippet],env=env,capture_output=True,text=True)
                self.assertEqual(0,run.returncode,run.stderr)
                self.assertEqual(expected,agent.exists(),(preserve,previous))
