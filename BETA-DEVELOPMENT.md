# EasyComp Keyboard Light — single development beta

**Active branch:** `dev/beta`

**Working version:** `1.2.0-beta` (see `VERSION`)

**Application:** `EasyComp Keyboard Light.app`

**Bundle ID / LaunchAgent:** `nl.easycompzeeland.KeyboardLight`

**Current package:** `dist/beta/EasyComp-Keyboard-Light-Beta.zip`

There is one maintained Swift + C codebase and one cumulative macOS regression suite. The previous beta7 work and its review fixes are already in this branch. Existing production preferences are retained through the same app identity and preference keys. The build script no longer creates a separate Beta7 Test app or preference domain.

## Current implementation

- Proven A2141 Magic HID report method and conservative interface validation.
- Manual power and brightness, with corrected 10% steps and remembered brightness.
- Persistent inactivity timeout: Never, 15 seconds, 30 seconds (default), 1, 5, 10 or 30 minutes.
- Activity restoration, manual-off protection, sleep/wake and session reevaluation.
- Serialized/coalesced HID writes, stale-command protection, helper watchdog and diagnostics.
- Local/global illumination-event monitors plus a recovering background event tap.
- Native installer, staging/rollback, prerequisite handling and eight interface languages.
- Issue #2 PID `027d` read-only diagnostics. LED writes remain blocked pending protocol validation.

Implementation does not imply hardware acceptance. Original Touch Bar event emission and the updated sleep/input behavior still need physical testing. MacBookPro15,4 compatibility is not confirmed; the second tester report confirms the BF configuration (0/32/512), while output and physical LEDs remain unverified. See [the isolated compatibility test](ISSUE2-COMPATIBILITY.md).

## One workflow

From the official checkout:

```sh
git switch dev/beta
python3 -m unittest discover -s tests -v
bash Controleer-build.command
bash scripts/build-beta.sh
```

The automated suite targets macOS. The two Linux-only tests have been removed; macOS rejection guards in the shipping installer remain unchanged. No Linux execution is required.

The build command verifies the Intel x86_64 controller build and compiles a universal native Setup app for macOS 13 or later. The single ZIP contains that Setup app and its internal backend, with eight translated GUI languages. It verifies the ZIP after a shared-volume roundtrip and updates the single package in `dist/beta/`. It does not install, start the app or send HID commands. `BUILD-INFO.txt` identifies the source commit and source hashes. Generated packages and caches are ignored by Git. Older timestamped `dist/beta7-test-*` artifacts are historical and are not the active package.

Follow [hardware acceptance](HARDWARE-ACCEPTANCE.md) before installation/release approval. Use the Setup GUI for the actual update; it invokes `Installeer.command` internally so its staging and rollback apply. That installer runs the read-only protocol probe before accepting the device. Setup asks a running controller to quit before updating and waits for it to exit. Technical output is collapsed by default; diagnostics, app launch and confirmed uninstallation are in the GUI. `Start.command` is the single source-based starter; old language-specific launchers are preserved in `legacy/`.

## Backlog within this beta

These items are planned work on the same beta, rather than a separate beta8 codebase:

1. Finish A2141 acceptance of timeout, activity sources, monitor permissions, Touch Bar and sleep/session behavior.
2. Run the isolated Issue #2 compatibility test after the tester reviews its fresh probe. The second report confirms BF configuration reads; integrate into the normal beta only after output and physical LED validation.
3. Add manual, local sunset/sunrise and custom-schedule modes, including intervals across midnight. Location requires permission; no online API or account.
4. Complete lock/unlock behavior: normal timeout by default, optional immediate off, permitted activity on the lock screen where macOS allows it, and persistent manual off.

Ambient-light adaptation remains unsupported without a reliable data source. No private T2 commands or Control Center integration are claimed.

## History and release policy

`archive/beta7-20261110` preserves the former branch pointer; it is not an active development branch. Previous notes and release/upload instructions are retained in [docs/history](docs/history/). The [dated technical review](DEVELOPMENT-REVIEW-2026-11-11.md) records the earlier investigation and validation.

The published `v1.2.0-beta6` release and `main` remain unchanged. Do not create a new release/tag, push, merge to main or close issue #2 without the required hardware acceptance and explicit publication instruction. Future beta fixes and agreed additions accumulate here; build numbers/commit hashes distinguish test builds without introducing parallel beta variants.

## GUI consolidation

See [the GUI simplification review](GUI-SIMPLIFICATION.md) for the single Setup app, language-first flow, internal backend packaging, safe action lifecycle and acceptance limits.

Latest local validation: 35 macOS tests passed (including 38 mocked HID scenarios for the isolated Issue #2 tool) with no failures or skips; native build, eight app/eight setup language tables and shell syntax passed. Hardware/end-to-end installation acceptance is still pending.
