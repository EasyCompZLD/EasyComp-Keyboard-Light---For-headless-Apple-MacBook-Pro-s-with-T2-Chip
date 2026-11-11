> Historical review of the earlier beta7 work. Current development is consolidated on `dev/beta`; see [the single beta workflow](BETA-DEVELOPMENT.md). The old build names and counts below describe that earlier review.

# Development review — 11 November 2026

Base: beta7 commit `b5762d2`, following installer fix `073cdac`. Work remains local on `dev/beta7-timeout-touchbar-20261111-review`; main and public releases are unchanged.

## Findings and changes

- **Confirmed brightness defect:** `min(1, (current + delta) * 10)` capped the rounded step at 1, forcing plus/minus and illumination events to 10%. Clamp the normalized brightness before scaling. Executable Swift assertions cover all eleven brightness levels.
- **Touch Bar delivery gaps:** Apple's global AppKit monitor excludes events addressed to the monitoring app. Add a local monitor. Previously a failed tap exited its worker permanently; retry creation and reenable disabled taps on a dedicated run loop. Keep tap resources on that worker, and UI/state changes on the main queue. Remove both AppKit monitors and cancel the worker on termination.
- **Duplicate handling:** replace the delivery-time 65 ms guard, which dropped rapid real presses and could accept delayed duplicates, with bounded deduplication using original illumination event timestamps and keycodes.
- **HID queue:** evaluate the desired level when executing, coalesce pending intents, skip identical successful targets, invalidate cached hardware state across sleep/wake/session activation and ignore stale completion generations. Bound a stuck helper with a 5-second watchdog and termination escalation. Capture the helper's actual stdout diagnostics on failure.
- **Power/session separation:** a session activation must not erase a physical sleep state. Manual power and last brightness stay independent of transient idle/power states. Lock notifications are not equated with a complete lock policy.
- **Idle status:** all eight translations distinguish manual off, suspended session/sleep and Never. Existing preference keys remain unchanged. A test bundle uses its own bundle ID for login startup.
- **Network checkout:** regression tests resolve localized folder names from directory entries, respecting SMB Unicode normalization. Build checks use disposable compiler caches and source copies. Python caches are ignored; existing files/archives are preserved.
- **Input validation:** reject non-finite CLI brightness before HID enumeration. Magic descriptor checks, report structures and report-writing code are unchanged.

These changes address demonstrable code defects. They do not prove that headless macOS emits original Touch Bar illumination events. Input Monitoring and Accessibility requirements must be measured on the target OS with the actual event sources.

## Issue #2

At review time GitHub issue #2 is open and has three comments. The second diagnostic request is the latest comment; no follow-up result is present. The first report confirms PID `027d` and input `ff00/000f`, but neither feature `BF` nor output `B0` support.

Add only the demonstrated PID to exact VID/PID enumeration. A separate branch inside device selection recognizes only the reported keyboard primary collection and input report shape for read-only configuration checks. It cannot reach the write implementation and cannot pass installer validation, even if the configuration reads successfully. Existing Butterfly write descriptor requirements remain unchanged pending evidence. Diagnostic output now includes GetReport status/length and decoded configuration values; failed writes no longer falsely state that no LED command was sent and do not trigger a write attempt on another device.

The Linux protocol source confirms the existing BF version-1 configuration layout and B0 output structure. Linux support does not prove those requests are accessible through macOS IOKit on this machine. No new bytes, PID `027b` support or alternative private commands are introduced.

## Apple behavior comparison

| Behavior | EasyComp status / limit |
|---|---|
| Manual power/brightness | Proven Magic protocol on A2141; updated GUI stepping needs physical retest |
| Configurable inactivity timeout | Implemented, default 30 seconds; policy tests execute; real devices/OS still need acceptance |
| Restore after activity | Retains exact manual level; input-source reliability needs hardware testing |
| Sleep/wake | Serialized off request and reevaluation; pre-sleep completion is not guaranteed by an asynchronous workspace notification |
| Session switching | Separate suspension state; physical multi-user acceptance pending |
| Lock/unlock | Full beta8 behavior and optional immediate-off remain planned; no unsupported lock-state claims |
| Original Touch Bar buttons | Event monitoring improved; physical emission, permissions and response unproven |
| Brightness steps | Fixed 10% steps plus off; user-configurable step size not implemented |
| macOS Settings / Control Center | No integration provided; no public extension point established in this review |
| Ambient-light adjustment | Unsupported without a reliable sensor/data source |
| Sunset/sunrise and custom schedule | Beta8 planned; neither is a measurement of ambient light |

Beta8's two agreed additions are not implemented in this beta7 stabilization revision. They need a separate implementation and acceptance pass after the current hardware results; no release prerequisite is marked complete prematurely.

## Verification and acceptance

See `HARDWARE-ACCEPTANCE.md` for the isolated test app, exact hardware matrix, safe event logging and pending Butterfly evidence. Final automated results:

- `python3 -m unittest discover -s tests -v`: 34 discovered, 32 passed, 2 Linux-only checks skipped on macOS; no failures. Includes executable Swift policies, C argument/configuration fixtures with HID manager creation and writes forbidden, localization completeness and the retained installer checks.
- `bash Controleer-build.command`: passed for the native app, C helper, setup wizard, Info.plist, 8 app/8 wizard localization files and icon. The final run used execution outside the sandbox because sandboxed iconutil failed; isolated icon conversion outside the sandbox confirmed that cause.
- All project `.command` files and `scripts/*.sh` files: Bash syntax passed.
- Compared against `b5762d2`: Magic usage/descriptor validation and the complete Magic report-writing branch are byte-for-byte unchanged. Installer and its rollback code are unchanged.
- `bash scripts/build-beta7-test.sh`: Intel x86_64 test app/helper compiled, ad-hoc signed, archived and signatures verified after extracting the ZIP from the network share. The local artifact is `dist/beta7-test-20261111-165606/Beta7-Test-App.zip`; it was not installed or started.
- Physical A2141, Touch Bar, sleep/lock, real input-device and tester Butterfly acceptance: pending. No current GitHub Actions run was triggered or claimed. The current execution host is arm64 macOS 27.2.1, not the Intel A2141 or the tester's Sequoia machine. No live keyboard lighting is changed by the checks.

## Sources

- [Apple: global event monitor semantics and Accessibility caveat](https://developer.apple.com/documentation/appkit/nsevent/addglobalmonitorforevents(matching:handler:).md)
- [Apple: event tap API](https://developer.apple.com/documentation/coregraphics/cgevent/tapcreate(tap:place:options:eventsofinterest:callback:userinfo:))
- [Apple: listen-event access preflight](https://developer.apple.com/documentation/coregraphics/cgpreflightlisteneventaccess().md)
- [Linux: separate Apple backlight protocol implementations](https://github.com/torvalds/linux/blob/master/drivers/hid/hid-apple.c)
- [Issue #2 and hardware reports](https://github.com/EasyCompZLD/EasyComp-Keyboard-Light---For-headless-Apple-MacBook-Pro-s-with-T2-Chip/issues/2)
