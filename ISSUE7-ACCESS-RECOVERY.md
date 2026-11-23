# Issue #7 — native HID execution candidate

**Working build:** `1.2.1-dev.3`, build 14, on the existing `dev/beta` branch. Unreleased; no stable compatibility claim. The updater remains off by default and is not needed for this test.

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
- Diagnostic schema **3** records Setup’s actual passive IOHIDCheckAccess state, its file name, declared launcher context and the native host’s own result. A granted GUI with refused HID access gets different guidance: create a report rather than repeatedly toggling the same setting. No permission resets or system-security changes are performed.

## Test plan — no Terminal input

1. Keep the working beta7.1 backup and quit other keyboard-light controllers. Extract the new candidate locally, open its Setup, choose language and Install/Update. Leave automatic updates off.
2. Approve the **current new Setup** if macOS requests it; ad-hoc identity is not guaranteed to retain a previous build’s permission. If permission is already allowed, do not repeatedly toggle it. Reopen only if macOS requests that.
3. Confirm that the installer log now identifies the signed Setup read-only executable, not the old anonymous temporary helper. A real successful BF probe must precede replacement. A host/signature/source mismatch must stop with exit 10, without a fallback or replacement.
4. If it fails, create a fresh diagnostic report in the same Setup. Schema 3 must show “Setup GUI Input Monitoring” separately from the host’s state. Share the reviewed report and whether Setup launched normally; the app name helps distinguish renamed copies without collecting full user paths.
5. If installation succeeds, test off/on, brightness, timeout and wake. The controller now uses its own signed executable’s worker. If it requests its own Input Monitoring permission, that is separate from Setup; use its menu action. Do not infer Touch Bar support from backlight success.
6. Test declined access, Cancel, unsupported interfaces and old/mismatched hosts: no unsafe write or skipped validation is allowed. Retain the older app/settings when a probe fails. Test A2141 normal feature access without making denied ListenEvent permission a preemptive gate.

## Verification and limits

Local regression coverage includes 58 standalone production-HID cases, 64 native bridge cases (including forbidden Setup writes), 38 isolated-tool cases, real Swift native entry points with a mock backend, signature/source/version mismatch fixtures, the GUI consent/recovery controls in all eight languages and the existing installer/state/update regressions. Tests do not request real permissions or run physical HID writes.

Local verification passed: 41 regression tests and the native macOS build, including all eight controller and eight Setup localizations. Shell syntax and the unchanged canonical driver body were also checked before packaging. TCC attribution and successful native-host operation on MacBookPro15,4 / Sequoia 15.8.3 remain **pending hardware confirmation**. This is a candidate implementation, not a claim that the issue is resolved.

## Earlier dev.2 observations (historical)

The dev.2 package was built from 51acfe4; its source fingerprint was `9ab8f71d37a64b0c00d5f056922f18afd6500529296fbb6c182d7ceeb4030b7d`. Its local 38 tests and native build passed, but the tester’s actual permission recovery **failed**. Its linker warned about an arm64-only libswiftCompatibilityPacks archive during Intel cross-linking. The later screenshot establishes that this dev.2 Setup did launch on Intel Sequoia; it does not establish the new dev.3 worker behavior.

The earlier packet/selection/rollback comparisons remain applicable. Stable and candidate Setup are ad-hoc signed with no TeamIdentifier; code-signature verification here is an integrity check, not independent publisher authentication or proof of TCC attribution. I have not reset permissions or changed the working stable release.
