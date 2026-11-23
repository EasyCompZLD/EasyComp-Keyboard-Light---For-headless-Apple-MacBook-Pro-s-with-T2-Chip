# Issue #7 — permission recovery investigation

**Working build:** `1.2.1-dev.4`, build 15, on `dev/beta`. This is a local, unpublished candidate. The published dev.3 test did not resolve the refusal; stable remains 1.2.0.

## Dev.3 follow-up: both processes denied

In [comment 7114970607](https://github.com/EasyCompZLD/EasyComp-Keyboard-Light---For-headless-Apple-MacBook-Pro-s-with-T2-Chip/issues/7#issuecomment-7114970607), the tester reports the same problem with dev.3. Schema 3 now shows **Setup GUI Input Monitoring: denied** and the signed native worker also reports **denied**. The native worker actually runs, and HIDManagerOpen for 05ac:027d returns 0xe00002e2 before the Butterfly configuration can be read. Its C source fingerprint matches dev.3. I do not claim that moving the worker fixed access.

This report is explicitly a **manual read-only diagnostic**, with no prior probe or installer log. It demonstrates refused access in that context, but cannot independently establish which installation or permission-request buttons were used. It also establishes that dev.3 launches and reaches native diagnostic code on Intel Sequoia; the earlier cross-link warning did not prevent those steps.

Apple explains in [TN3127, Inside Code Signing: Requirements](https://developer.apple.com/documentation/technotes/tn3127-inside-code-signing-requirements) that ad-hoc code identity is tied to a specific build and cannot be reliably tracked across versions. The packages here use ad-hoc signing. A stale authorization is therefore a **hypothesis**, not a demonstrated TCC database diagnosis. I have not read the tester's TCC database. I am keeping distribution ad hoc without a paid Apple Developer membership. I do not promise permission preservation across rebuilt packages; a changed build may need fresh explicit consent. I have not provisioned a certificate or changed the published signature.

## Dev.4 changes and scope

- **Keyboard access…** is always available in Setup, including before installation and after a manual report. Previously the recovery dialog was reached only after an installation failure.
- **Reset Setup permission…** opens a separate confirmation with Cancel as default. Only a confirmed click runs Apple's `tccutil reset ListenEvent nl.easycompzeeland.KeyboardLight.Setup` for the current user. It does not grant access, reset other apps or the installed controller, install anything or send a HID command. It never runs during reports, startup or automatic updates. No administrator rights are requested.
- The reset runs asynchronously. Install/report/close and duplicate reset actions are blocked until it exits. A ten-second watchdog terminates this child if still running. Success and failure are reported; no automatic permission request, retry, restart or LED test follows. A successful reset only means the reset command succeeded, not that HID access is fixed.
- Schema **4** records the last Setup reset exit **in the current session**, plus the validated on-disk native host's signing kind and code hash. It does not print certificate owner names or full executable paths. After quitting/reopening, the session reset status starts as not attempted.
- The native-worker architecture, exact matching/configuration checks, packet bytes, read-only installer gate and rollback are retained. The controller has no functional change in this candidate.

Apple documents both [Input Monitoring's ListenEvent service and an app-specific reset](https://developer.apple.com/documentation/xcode/resetting-access-to-protected-resources-in-macos). This makes the reset a documented recovery experiment, not proof that it will repair this Mac.


## Follow-up that changes the diagnosis

In [comment 7098093298](https://github.com/EasyCompZLD/EasyComp-Keyboard-Light---For-headless-Apple-MacBook-Pro-s-with-T2-Chip/issues/7#issuecomment-7098093298), the tester reports that dev.2 still fails after enabling and relaunching the current Setup. The screenshot shows “EasyComp Keyboard Light Setup 2” enabled in Input Monitoring. The reported HID source SHA matches the supplied dev.2 candidate. I do not treat this as a failure to follow the instructions.

The helper reports denied access. The old “Requester context: Setup GUI” line was an environment label I passed to the installer, not a real permission check performed in Setup. Thus the report does **not** establish whether Setup’s own IOHIDCheckAccess was granted, or which client macOS considered responsible. The old path was Setup → Bash installer → newly compiled temporary C executable. I have removed that temporary executable from GUI HID operations.

Apple discusses responsible code and stable code-signing identity in its [launch-constraint guidance](https://developer.apple.com/documentation/security/applying-launch-environment-and-library-constraints). Those principles motivate this change, but that guidance is not proof of the exact HID/TCC decision on this Mac. I have not identified a definitive OS-level cause.

## Native worker design

- HIDBridge.c includes the **single canonical HIDBacklight.c** implementation. It adds no report IDs, payload bytes, models, PIDs or relaxed descriptor/configuration checks. The driver body is unchanged from dev.2 apart from its version comment.
- Setup and the controller link this C code into their own native executables using a normal C bridging header. Their `--ecz-hid` worker entry exits before starting AppKit UI, timers or monitors. These remain separate short-lived processes, not C calls on the UI thread. Each uses the same executable/bundle/signature as its corresponding GUI.
- Setup’s compiled worker passes read-only mode: only probe, diagnose and permissions are allowed. On/off and unknown commands are rejected before device access. The controller’s worker retains normal validated on/off commands and the existing serialized/coalesced queue and timeout watchdog. No permission is shared implicitly between Setup and the controller.
- The GUI installer selects the signed Setup host and still executes a **real read-only protocol probe**. It does not accept a cached result, permission flag or skip-probe environment variable. The host must match bundle identity, development version, native-host protocol and the combined driver/bridge source digest, and pass code-signature verification. Failure stops with exit **10**; there is no silent temporary-helper fallback for the GUI.
- Source CLI workflows retain the standalone C helper, with their own process permissions. Diagnostics launched from a valid Setup use its compiled read-only host even if compiler tools are unavailable. The installer still requires compiler tools for local app construction.
- Diagnostic schema **3** records Setup’s actual passive IOHIDCheckAccess state, its file name, declared launcher context and the native host’s own result. A granted GUI with refused HID access gets different guidance: create a report rather than repeatedly toggling the same setting. Read-only diagnostics do not reset permissions. Dev.4 adds only the separately confirmed Setup-only reset described above.

## Test plan — no Terminal input

1. Keep the working beta7.1 backup and quit other keyboard-light controllers. Open one fixed local copy of the new Setup. Leave automatic updates off.
2. Open **Keyboard access…**. If access is already denied despite the matching System Settings entry being enabled, choose **Reset Setup permission…** and read the separate confirmation. Cancel must do nothing.
3. After a successful reset, quit Setup and reopen **the same copy**. Choose Keyboard access → Request access, explicitly approve that Setup in Input Monitoring and reopen if macOS requests it. Do not move, rebuild or replace this copy between reset and approval.
4. Run the read-only diagnostic first. Compare the new GUI/host permission results and native signing fingerprint. Share the reviewed report if still refused; do not keep repeating resets. A successful reset alone is not acceptance.
5. Only after access is allowed, try Install/Update. The real read-only BF protocol probe must succeed before replacement. Test normal on/off, brightness, timeout and wake after successful installation. The controller may need its own permission; the Setup reset deliberately does not touch it.
6. Verify Cancel, reset failure and duplicate/busy actions using mocks. Real tester acceptance must separately establish that only Setup's entry is affected. Keep Touch Bar and updater acceptance separate from backlight and permission recovery.

## Verification and limits

Local regression coverage includes 58 standalone production-HID cases, 64 native bridge cases (including forbidden Setup writes), 38 isolated-tool cases, real Swift native entry points with a mock backend, signature/source/version mismatch fixtures, the GUI consent/recovery controls in all eight languages and the existing installer/state/update regressions. The dev.4 GUI fixture also checks reset confirmation/Cancel, success/failure/tool-launch error, duplicate busy actions and restored controls. Tests do not request or reset real permissions or run physical HID writes.

Local verification passed: 41 regression tests and the native macOS build, including all eight controller and eight Setup localizations. Shell syntax and the unchanged canonical driver body were also checked before packaging. Dev.3 native-host diagnostic execution is now confirmed on Intel Sequoia, but permission recovery failed. Dev.4 consent/reset/regrant behavior and successful installation remain **pending hardware confirmation**. This is a candidate implementation, not a claim that the issue is resolved.

## Published dev.3 test package (failed recovery)

I published dev.3 as a prerelease, without replacing stable 1.2.0 or merging main. Its source is `7d1609fc259261b623864b98190a63039ce92264`; the ZIP SHA-256 is `25e3fb363d4f782585080b0e3b0f659d846e9a10f6408fc601017adc0273eff6`. GitHub Actions [run 45169965666](https://github.com/EasyCompZLD/EasyComp-Keyboard-Light---For-headless-Apple-MacBook-Pro-s-with-T2-Chip/actions/runs/45169965666) passed for that commit. GitHub's uploaded asset digest matches the local archive.

I also verified the signed archive after extraction, its bundled source/digest and x86_64/arm64 Setup slices. The real native Setup worker queried passive permission status on the development Mac without opening devices, requesting permission or writing reports. This does not establish the tester's TCC attribution or hardware result. The local Intel cross-link warning described below also occurred for dev.3. The tester subsequently confirmed dev.3 diagnostic launch on Intel Sequoia; successful permission recovery and installation were not established.

## Earlier dev.2 observations (historical)

The dev.2 package was built from 51acfe4; its source fingerprint was `9ab8f71d37a64b0c00d5f056922f18afd6500529296fbb6c182d7ceeb4030b7d`. Its local 38 tests and native build passed, but the tester’s actual permission recovery **failed**. Its linker warned about an arm64-only libswiftCompatibilityPacks archive during Intel cross-linking. The later screenshot establishes that this dev.2 Setup did launch on Intel Sequoia; it does not establish the new dev.3 worker behavior.

The earlier packet/selection/rollback comparisons remain applicable. Stable and candidate Setup are ad-hoc signed with no TeamIdentifier; code-signature verification here is an integrity check, not independent publisher authentication or proof of TCC attribution. I have not reset permissions or changed the working stable release.
