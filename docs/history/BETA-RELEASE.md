> Historical snapshot. For current development, see [the single beta workflow](../../BETA-DEVELOPMENT.md).

# EasyComp Keyboard Light v1.2.0-beta6 — experimental

**Automatic Apple prerequisite handling plus eight-language guided installation.**

- **New in beta6 — prerequisites:** detects already installed Xcode from native Finder-wizard processes (including the restricted PATH case reported on MacBookPro16,1). Starts the official Apple Command Line Tools installer only if required, then automatically resumes; Apple approval is still required. The check also distinguishes missing compilers from a first-launch/Xcode-license problem.
- **Regression fix:** the HID backend again opens an IOHIDManager strictly scoped to Apple `05ac:8102` before probing the known-good A2141 descriptor and feature reports 1/3. Beta2 opened a manager matching all Apple HID endpoints and could return `0xe00002c7` (`kIOReturnUnsupported`).
- **Eight-language setup:** all wizard buttons, notifications and stage labels have translations for English, Dutch, German, French, Spanish, Italian, Portuguese and Polish. Eight visible installer launchers and localized advanced-command folders provide clickable actions with native-language names.
- **Guided installation:** double-click `Start-Installatie.command` (creates a native `EasyComp Keyboard Light Setup.app`) for a native AppKit window with progress, error details, diagnostic report and direct GitHub Issues link. The native setup window opens **automatically** immediately after the build; no second manual launch is needed. Uses existing Xcode or Command Line Tools automatically; if neither works, launches the official Apple install dialog and resumes after confirmation.
- **Safer upgrade:** build, validate and ad-hoc-sign the new app in a staging directory before replacing the existing installation, with best-effort rollback on a late failure. User preferences are preserved.
- **Background Touch Bar listener:** dedicated event-tap CFRunLoop, independent of status-menu tracking (first introduced beta1).
- **Experimental Butterfly protocol:** targeted Apple internal keyboard PID matching, strict descriptor and read-only config validation before any output; unvalidated hardware requires explicit opt-in.
- **Privacy-oriented diagnostics:** local report on install failure, copy/paste to an Issue. No automatic upload.

### Important

**The A2141 HID report method worked in v1.1.0; this new installer, event handling and broader-model backend are not yet hardware validated.** Keep the published v1.1.0 release as stable, publish this as a **pre-release**.

### Testing

Double-click `Install.command` (automatically follows macOS), or a language-specific launcher (creates a native `EasyComp Keyboard Light Setup.app`) in the extracted folder, or use:

```bash
bash Controleer-build.command
bash Installeer.command
```

Test the original Touch Bar illumination buttons with the menu closed and opened. Test installation on A2141 first; use other Intel T2 models only with explicit experimental consent and a successful read-only probe.
