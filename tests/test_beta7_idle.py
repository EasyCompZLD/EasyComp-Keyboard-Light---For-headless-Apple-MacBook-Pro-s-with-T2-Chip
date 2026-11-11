"""Regression checks for automatic idle off and passive Touch Bar monitoring.
These guard source contracts; the actual feature needs a compatible macOS host.
"""
from pathlib import Path
import unittest

ROOT=Path(__file__).resolve().parents[1]
class KeyboardIdleAndTouchBarTests(unittest.TestCase):
    def test_timeout_defaults_to_30_seconds_and_is_persisted(self):
        src=(ROOT/'broncode/EasyCompKeyboardLight.swift').read_text()
        for expected in ('private var timeoutSeconds = 30',
                         'idleTimeoutSeconds', 'CGEventSource.secondsSinceLastEventType',
                         'systemIdleSeconds()', 'Timer(timeInterval: 1.0',
                         'private func effectiveLevel()',
                         'NSWorkspace.willSleepNotification',
                         'NSWorkspace.didWakeNotification'):
            self.assertIn(expected,src)
    def test_localizations_have_consistent_timeout_menu(self):
        keys=['idle.timeout.title','idle.never','idle.15s','idle.30s',
              'idle.1m','idle.5m','idle.10m','idle.30m',
              'idle.status.off','idle.status.active']
        for lang in ['nl','en','de','fr','es','it','pt','pl']:
            text=(ROOT/f'broncode/Localizations/{lang}.lproj/Localizable.strings').read_text()
            for key in keys:
                self.assertIn(f'"{key}" = ',text, f'{lang}:{key}')
    def test_hid_protocol_unchanged(self):
        c=(ROOT/'broncode/HIDBacklight.c').read_text()
        self.assertIn('uint8_t power[6]={3,0,0x5e,0x01,0,0}',c)
        self.assertIn('uint8_t light[9]={1,0,0,0,0,0x5e,0x01,0,0}',c)
    def test_touchbar_passive_fallback_and_duplicate_guard(self):
        src=(ROOT/'broncode/EasyCompKeyboardLight.swift').read_text()
        self.assertIn('NSEvent.addGlobalMonitorForEvents(matching: .systemDefined)',src)
        self.assertIn('CGEvent.tapCreate(tap: .cgSessionEventTap',src)
        self.assertIn('illuminationEvents.accept(code: code, timestamp: timestamp)',src)

if __name__=='__main__': unittest.main()
