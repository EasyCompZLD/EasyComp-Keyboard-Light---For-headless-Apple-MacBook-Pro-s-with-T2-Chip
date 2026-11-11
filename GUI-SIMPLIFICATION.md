# Single-beta GUI consolidation

The active development branch is `dev/beta`, working version `1.2.0-beta`. Existing changes are cumulative; scheduling and the complete lock policy remain on the same backlog. The earlier beta7 branch and documentation are archived rather than maintained as separate active versions.

## User workflow

The single package `dist/beta/EasyComp-Keyboard-Light-Beta.zip` contains **EasyComp Keyboard Light Setup.app**. Users extract it locally, double-click the app, select one of eight languages and continue. No Terminal input is required. The precompiled universal Setup app opens before any developer-tool checks; installation can request Apple's official tool installer through its GUI if needed.

The main window offers:

- Install or update, with the existing model/experimental checks, read-only protocol gate and installer staging/rollback.
- Open the installed menu bar app.
- Create a local diagnostic report, review it in the window and explicitly copy it when ready. Nothing is uploaded automatically.
- Uninstall with translated confirmation; Cancel is the default. The controller is asked to quit first. Preferences are kept.
- Show/hide technical details. The optional native build check is under details, rather than a normal first-run task.

Concurrent actions and closing during an active operation are blocked. Child output is drained before completion/report discovery and buffered at line boundaries to preserve UTF-8 split across pipe reads. Updates and uninstalls wait for the controller to exit instead of removing a running app. The preserved internal installer still performs its own read-only HID validation before installing.

## Source checkout

`Start.command` is the single source starter. It builds the same wizard using local temporary caches/source snapshots and stores it in local Application Support instead of on an SMB share. Source bootstrap needs developer tools to compile this GUI; the normal prebuilt download avoids that dependency before language selection.

Previous per-language starters are retained under `legacy/` with corrected paths. They are not included in the normal package. Backend `.command` scripts remain canonical developer/internal tools, not separate user workflows. Historical documentation is under `docs/history/`.

## Validation and remaining acceptance

The cumulative macOS suite includes production Swift policy execution, C argument/configuration fixtures, installer safety/prerequisite guards, all localization tables and a real AppKit fixture. The AppKit fixture verifies all eight language choices, translated control titles and title widths, collapsed details, removal confirmation defaults, serialized operation state and report discovery after the harmless child process exits. It never runs installation, removal or HID writes. GUI checks need AppKit/WindowServer access and were run outside the execution sandbox.

The package build compiles the Intel controller and universal setup, includes the complete internal backend, signs the app, archives it locally and verifies the signature after extracting the ZIP read back from the network share. The native build checker also validates both app metadata files, all sixteen localization tables and the icon.

Actual installation/update, Apple tool-install prompts, removal, launch-at-login, the headless A2141, Touch Bar behavior, and MacBookPro15,4 compatibility still require the [hardware acceptance](HARDWARE-ACCEPTANCE.md) run. The native GUI fixture is not a claim that those physical/end-to-end checks passed. Main, published releases and Issue #2 are unchanged; no publication is authorized by this consolidation.

Final local checks for this revision: **33 macOS tests passed, zero failures/skips**; native build and all command/script syntax checks passed. Both metadata plists and all sixteen localization tables validated. The HID implementation is unchanged from `2901799` apart from its development-version comment. Physical/end-to-end acceptance remains pending.
