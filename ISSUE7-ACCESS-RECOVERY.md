# Issue #7 — HID access refusal and recovery candidate

**Working build:** `1.2.1-dev.2`, build 13, on the existing `dev/beta` branch. This is an unreleased test candidate, not a replacement for stable 1.2.0. The optional updater remains off by default and is not required for this test.

## What I have established

- [mjesticfalco’s report](https://github.com/EasyCompZLD/EasyComp-Keyboard-Light---For-headless-Apple-MacBook-Pro-s-with-T2-Chip/issues/7) is from MacBookPro15,4 / Sequoia 15.8.3 (24H241), x86_64. Beta7.1 reportedly still operates the backlight. Stable 1.2.0 stops at `IOHIDManagerOpen` with `0xe00002e2`, before BF configuration validation or installing the menu bar app.
- [Apple’s IOReturn definitions](https://github.com/apple-oss-distributions/xnu/blob/main/iokit/IOKit/IOReturn.h) identify this as `kIOReturnNotPermitted`. It is distinct from an unsupported interface, exclusive access or a failed brightness write.
- Comparing the tagged beta7.1 and 1.2.0 C sources shows identical HID code apart from the version comment. Their installers differ only in version labels and recognition of the confirmed model without the experimental warning. This rules out changed report bytes as the source-level difference; it does not prove identical macOS permissions or signing identity at runtime.
- Apple’s public SDK header `IOKit/hidsystem/IOHIDLib.h` documents `IOHIDCheckAccess` and the explicit `IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)` request. Permission is process/context dependent. Setup, its helper and the installed controller must not be assumed to share the old beta’s effective access.

My leading hypothesis is an Input Monitoring or requester/signing-context difference. I have not established the exact runtime cause. An access check may say granted while an actual device operation is still refused; the test fixtures preserve that distinction.

## What changed

- An actual `kIOReturnNotPermitted` from manager open, device open or configuration read is recorded separately. When validation has failed without a write, the helper returns **9** and logs the current process’s permission status. Generic manager/device failures remain **4/6**, configuration errors **7** and a possible partial write **8**. Partial-write errors never become permission-retry requests.
- The new `permissions` helper command only queries the process’s access state. It opens no HID devices, requests no permission and sends no reports. There is no preemptive permission gate: successful feature-only A2141 operation continues even if ListenEvent access is denied.
- On an installation access failure, Setup offers translated Request access, Retry installation and Cancel actions. Cancel is the default. Only clicking Request access invokes the public permission API and opens Input Monitoring settings. Retry starts a fresh installer invocation and must pass its read-only protocol check before replacement or normal app startup. Legacy 4/6/7 reports containing the exact refusal code are also recognized; exit 8 is excluded.
- The installed controller shows an access-specific HID status. Its existing Input Monitoring menu action can explicitly request its own permission before opening settings. Background failures and diagnostics do not call the explicit permission-request API. macOS itself may present an access dialog during HID open calls, as documented by Apple.
- Report schema 2 adds a HID source SHA-256, permission state and Setup/CLI requester context. Reports remain local; no keystrokes, account names, serial numbers or network upload are added. A report made through Terminal can have different permissions from the failed Setup, so the context is recorded.
- Magic and Butterfly packets, strict VID/PID/usage/descriptor/configuration validation, brightness calculations, installer staging and rollback remain intact.

## Hardware acceptance for the tester

1. Keep the working beta7.1 app available. Quit other keyboard-light controllers before testing. Extract the candidate locally and open Setup, choose a language and Install/Update. Leave automatic updates off.
2. If access is refused, verify that the new report shows exit 9, the refusal code, permission state, Setup requester context and source fingerprint. No replacement or LED command is allowed after the failed probe. Existing app files/preferences must remain intact; Open app can reopen a retained installation.
3. Click Request access only when ready to grant it. In macOS Input Monitoring, enable the current Setup app. If macOS asks to quit and reopen it, do so before trying again. Use the normal macOS controls; no administrator script or permission reset is required by this candidate.
4. Click Retry installation, or reopen Setup and choose Install/Update. The read-only probe must actually succeed; a granted permission flag alone is never accepted as protocol validation. If refusal persists despite granted access, create a fresh report in the same Setup window and record how it was launched.
5. Once installation completes, check manual off/on, brightness, timeout and wake. If the installed controller itself reports denied access, use its Input Monitoring menu item; its context may differ from Setup’s. Record any relaunch requirement rather than claiming it is unnecessary.
6. Repeat with permission declined: Cancel must not request permission, no unsafe retry or replacement may occur, and diagnostics must still be available. Confirm A2141 control has no new mandatory permission prompt when its HID calls succeed. Original Touch Bar controls remain a separate unconfirmed feature.

## Verification boundary

Verified locally on **22 November 2026**: 38 Python regression tests passed, zero failures/skips; the native macOS build, all sixteen localization tables, shell syntax, version metadata, documentation links and exact packet/selection/rollback comparisons passed. No real permission request or physical HID write was made by these fixtures.

Local checks exercise 58 production-HID scenarios (including manager/device/read denial, generic errors, granted-but-refused context, read-only permission queries and exact Magic packet regression), plus the retained 38 isolated-tool scenarios. Native AppKit fixtures inspect recovery controls in all eight languages, default Cancel, explicit mocked permission/settings calls and error classification without requesting real permissions or running the installer.

The full Python suite, native build, shell syntax, sixteen localization tables, version metadata and exact protocol/rollback comparisons are checked before packaging. Actual TCC attribution, prompts, relaunch requirements and successful installation on the tester’s Sequoia machine remain **pending hardware confirmation**. I have not published a new release, overwritten stable assets or marked Issue #7 resolved.
