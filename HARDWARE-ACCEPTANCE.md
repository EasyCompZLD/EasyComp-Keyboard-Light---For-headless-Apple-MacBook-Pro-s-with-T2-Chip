# Beta7 hardware acceptance — development build

Status: **pending physical validation**. Do not release, tag, merge to main, or claim Butterfly/Touch Bar compatibility from compilation alone.

## Isolated A2141 test

Build from the official checkout with `bash scripts/build-beta7-test.sh`. The output is `Beta7-Test-App.zip` containing an Intel x86_64 app in an ignored, timestamped `dist/beta7-test-*` directory. The signed app is archived locally and verified after extraction from the shared-volume ZIP. This command does not install, launch, probe, or write to HID devices.

1. Quit the installed beta6 app and any other Keyboard Light test app. Do not run two controllers together. Temporarily disable beta6's login startup if testing across login/reboot; restore it afterward.
2. Copy `Beta7-Test-App.zip` to your local Downloads folder, extract it there, then move `EasyComp Keyboard Light Beta7 Test.app` to `~/Applications/`. Avoid extracting onto the network share: SMB Finder metadata can invalidate code signatures. The app uses bundle ID and LaunchAgent label `nl.easycompzeeland.KeyboardLight.Beta7Test`. It has independent preferences; it does not migrate beta6 preferences. Regular beta7 updates retain the original preference keys.
3. Before launching the app, run its helper in read-only mode:

   ```sh
   "$HOME/Applications/EasyComp Keyboard Light Beta7 Test.app/Contents/MacOS/ecz-t2-backlight" probe
   ```

   Confirm the A2141 Magic interface and expected brightness range. Stop if this does not validate. Starting the GUI performs its normal startup LED write.
4. Launch the test app manually. It is ad-hoc signed for local testing, not notarized or published. Configure only the test app's permissions if prompted/needed; do not disable macOS protections.
5. Record model, OS/build, test app source hashes from `BUILD-INFO.txt`, permission states, expected/actual light behavior and helper error codes. Do not publish serial numbers or account information.

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
| Lock/unlock and typing while locked | Record actual notification and idle behavior. Beta8 lock policy is not implemented or accepted yet |
| Installer update/failure | Run only after the isolated app passes; verify staged replacement and rollback on disposable test paths |

The idle timer does not represent a real ambient-light sensor. Secure login/lock-screen event visibility and sleep timing need hardware measurements.

## Touch Bar diagnosis

For a targeted diagnostic run, quit the test app and start its executable in Terminal:

```sh
"$HOME/Applications/EasyComp Keyboard Light Beta7 Test.app/Contents/MacOS/EasyCompKeyboardLight" --diagnose-events
```

Use Console to filter `EasyComp illumination` (or run `log stream --style compact --predicate 'eventMessage CONTAINS "EasyComp illumination"'` in another terminal). The opt-in event log contains only illumination code 21/22/23, source (`tap`, `local`, `global`) and event timestamp. It does not record ordinary keys, typed text, mouse coordinates or device identifiers. Monitor availability and HID failures are logged without this option.

Compare one short test with the menu open, menu closed and another app frontmost, then repeat after wake and with/without permissions. If no illumination events arrive, this alone cannot distinguish OS suppression from a permission/delivery issue. Do not claim the original buttons work until an actual event and LED response are observed. Menu power and brightness controls remain the safe alternative; no private T2 commands are added.

## Issue #2 — MacBookPro15,4

Await `ECZ-KeyboardLight-Issue2-Followup.txt` from the already supplied read-only diagnostic. Check interface, open return status, GetReport status, successful report length, report ID/version and off/min/max values. A length left unchanged after a failed request is buffer capacity, not proof of a returned report.

The updated helper recognizes the reported `05ac:027d` keyboard input descriptor for read-only `probe`/`diagnose`. It does not infer output support from an input element. Even a valid configuration returns exit 9 (protocol pending), **not** installer acceptance. Exit 6 identifies device-open failure, 7 configuration/feature-request failure and 5 no validated interface; manager-open errors use 4. PID `027b` is not added without hardware evidence. The original strict Butterfly write gate remains for existing candidates.

Do not give the tester a GUI/LED build before reviewing and confirming their probe results. A later, separately reviewed compatibility build must permit a controlled LED test only after that confirmation. No `027d` LED test is provided or performed in this revision. Keep issue #2 open.

## Cleanup

Quit the test app, disable its “Start at login” setting if enabled, then remove only the test app from `~/Applications/`. Its LaunchAgent path is `~/Library/LaunchAgents/nl.easycompzeeland.KeyboardLight.Beta7Test.plist`. Restore beta6 startup and launch beta6. Keep the test preferences/logs until acceptance results have been recorded. Do not use the regular uninstall script to remove the isolated test app.
