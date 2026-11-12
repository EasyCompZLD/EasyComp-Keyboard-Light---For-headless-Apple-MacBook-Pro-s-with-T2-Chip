# Hardware acceptance — current development beta

Status: **pending physical validation**. Do not release, tag, merge to main, or claim Butterfly/Touch Bar compatibility from compilation alone.

## A2141 test — the single beta

Build from the official checkout with `bash scripts/build-beta.sh`. The current package is `dist/beta/EasyComp-Keyboard-Light-Beta.zip`, containing one universal **EasyComp Keyboard Light Setup.app** with its backend bundled internally. The build signs and verifies the archive without installing, starting a controller or sending HID commands.

1. Back up the currently installed app before an experimental update. Quit any historical Beta7 Test app and disable its startup if necessary.
2. Copy the ZIP to a local folder and extract it. Avoid extracting onto the network share: SMB Finder metadata can invalidate code signatures.
3. Double-click Setup, choose each of the eight languages as needed, and continue. Check that nothing is installed before clicking Install. Technical logs must start collapsed.
4. Click Install/Update. Setup checks compatibility, obtains experimental-model confirmation when required, stops the existing controller and invokes the established installer with its read-only protocol probe, staging and rollback. An invalid probe must stop installation before GUI/controller startup or LED commands. If developer tools are missing, approve Apple's official dialog; do not type commands into Terminal.
5. Test Diagnostic report, Copy report and Show details. Reports stay local. Test the optional build check under details. Open app is enabled only when the installed app exists.
6. After functional acceptance, test Uninstall: cancellation must leave the app untouched; confirmation must stop the controller, remove the app/autostart and retain saved settings. Test restoration from your backup if needed.
7. Record model, OS/build, source hashes from `BUILD-INFO.txt`, permission states, expected/actual light behavior and helper error codes. Do not publish serial numbers or account information. The package is ad-hoc signed, not notarized or published.

The standard app identity `nl.easycompzeeland.KeyboardLight` and existing preference keys are retained. This is the same development beta, not a separate test preference domain. Source-checkout users can double-click `Start.command`; it must build the same GUI and launch it from a local Application Support folder.

## Acceptance matrix

Record pass/fail and observations for each row. A menu status of “listening” proves tap creation only; “event received” proves event reception, not physical LED response.

| Test | Expected result |
|---|---|
| Slider, brighter/dimmer, 0–100% | Off at 0; 10% increments up/down through 100; no jump back to 10% |
| Timeout 15 seconds | Off within one timer interval (about 1 second) after the selected idle duration |
| Timeout 30 seconds | Same; default on a fresh preference domain |
| Never | No idle-off, including with the menu open |
| Activity, each input device separately | Internal keyboard, external keyboard, mouse and trackpad restore the exact chosen brightness |
| Manual off | Activity never turns the light on; explicit power/brightness input may turn it on |
| Sleep while lit | Off requested immediately; confirm the physical result and that HID completes before sleep |
| Wake while lit/manually off | Reevaluate; exact previous level when enabled, remain off when manually disabled |
| Rapid changes followed by sleep/off | One helper at a time; no obsolete on-command after the final off intent |
| Touch Bar, menu open/closed | Each press changes one step; repeated presses and held keys work |
| Touch Bar, another app frontmost | Same behavior |
| Sleep/wake and fast user switching | Monitor recovers; an inactive user session does not control lighting; no overlapping controllers in other sessions |
| App restart and login | Last manual brightness, manual power state, timeout and language persist |
| No Input Monitoring/Accessibility | Menu/timeout remain usable; monitor status is accurate; no repeated permission prompts |
| Permission granted after launch | Tap retries without restarting; record if macOS requires relaunch |
| Lock/unlock and typing while locked | Record actual notification and idle behavior. The complete lock policy is not implemented or accepted yet |
| Installer update/failure | Run only after the isolated app passes; verify staged replacement and rollback on disposable test paths |

The idle timer does not represent a real ambient-light sensor. Secure login/lock-screen event visibility and sleep timing need hardware measurements.

## Touch Bar diagnosis

For a targeted diagnostic run, quit the test app and start its executable in Terminal:

```sh
"$HOME/Applications/EasyComp Keyboard Light.app/Contents/MacOS/EasyCompKeyboardLight" --diagnose-events
```

Use Console to filter `EasyComp illumination` (or run `log stream --style compact --predicate 'eventMessage CONTAINS "EasyComp illumination"'` in another terminal). The opt-in event log contains only illumination code 21/22/23, source (`tap`, `local`, `global`) and event timestamp. It does not record ordinary keys, typed text, mouse coordinates or device identifiers. Monitor availability and HID failures are logged without this option.

Compare one short test with the menu open, menu closed and another app frontmost, then repeat after wake and with/without permissions. If no illumination events arrive, this alone cannot distinguish OS suppression from a permission/delivery issue. Do not claim the original buttons work until an actual event and LED response are observed. Menu power and brightness controls remain the safe alternative; no private T2 commands are added.

## Issue #2 — MacBookPro15,4

The [second report](https://github.com/EasyCompZLD/EasyComp-Keyboard-Light---For-headless-Apple-MacBook-Pro-s-with-T2-Chip/issues/2#issuecomment-6810254280) is now received: one keyboard candidate, successful BF feature read, 8 bytes, ID BF/version 1, off 0/minimum 32/maximum 512. It does not separately list the device-open status or numeric IOKit status, nor does it validate output or visible LEDs.

Use [the separately packaged compatibility test](ISSUE2-COMPATIBILITY.md) for the next opt-in hardware stage. It logs those statuses explicitly, starts with a new read-only probe and keeps the LED test locked until the tester reviews and confirms it. The ordinary application/installer remains blocked for PID `027d`.
The updated helper recognizes the reported `05ac:027d` keyboard input descriptor for read-only `probe`/`diagnose`. It does not infer output support from an input element. Even a valid configuration returns exit 9 (protocol pending), **not** installer acceptance. Exit 6 identifies device-open failure, 7 configuration/feature-request failure and 5 no validated interface; manager-open errors use 4. PID `027b` is not added without hardware evidence. The original strict Butterfly write gate remains for existing candidates.

Do not give the tester a GUI/LED build before reviewing and confirming their probe results. The isolated compatibility build permits a controlled minimum-light pulse only after that confirmation. An isolated opt-in `027d` LED test is now provided; no physical LED test has been performed by this development session. Keep issue #2 open.

## Previous test-app cleanup and rollback

The previous `EasyComp Keyboard Light Beta7 Test.app` is historical. If installed, quit it and disable its “Start at login” setting. Its separate LaunchAgent was `~/Library/LaunchAgents/nl.easycompzeeland.KeyboardLight.Beta7Test.plist`. Remove that old test app only after preserving any test results you need. Its preferences are not automatically migrated; the current beta uses the regular installed app's existing preferences.

Do not run the generic uninstall script just to remove the old test app: it targets the regular app. If physical acceptance fails, stop the beta and restore your backed-up installed app. No cleanup, replacement or preference reset is performed by the build command.
