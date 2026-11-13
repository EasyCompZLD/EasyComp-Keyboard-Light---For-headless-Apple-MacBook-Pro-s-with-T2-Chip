# EasyComp Keyboard Light

<img src="Assets/AppIcon.png" alt="EasyComp Keyboard Light" width="120" align="right">

A native macOS menu bar app for keyboard backlight control on headless Intel MacBooks with an Apple T2 chip. Swift + C, eight languages, no kernel extensions or SIP changes.

**No Terminal commands required — setup is now more user friendly.**

**Stable version: 1.2.0.** [Download the Setup app](https://github.com/EasyCompZLD/EasyComp-Keyboard-Light---For-headless-Apple-MacBook-Pro-s-with-T2-Chip/releases/download/v1.2.0/EasyComp-Keyboard-Light.zip). Built from the single maintained codebase on `dev/beta`; previous beta releases remain available as history.

## Start here

The current local release package is `dist/release/EasyComp-Keyboard-Light.zip`.

1. Copy the ZIP to a local folder and extract it.
2. Double-click **EasyComp Keyboard Light Setup.app**.
3. Choose your language, then click **Continue**.
4. Click **Install** or **Install / Update**.

No Terminal commands are needed. The setup app opens directly, before developer tools are checked. If Apple Command Line Tools are missing, installation opens Apple's official dialog; approve it there and setup continues. Normal macOS security approval may be required because this app is ad-hoc signed, not notarized.

The same window lets you open the installed app, create/copy a local diagnostic report, open GitHub Issues or uninstall with confirmation. Technical output is hidden under **Show details**; the optional build check is there too. Existing settings are retained on update and uninstall.

The download contains **one setup app**. Backend scripts are bundled inside it. For developers using this source checkout, **Start.command** is the single source-based starter; it compiles the GUI first if needed. Previous language-specific starters are preserved under `legacy/`, not required for normal use.

## Demonstration

![EasyComp Keyboard Light demonstration](Assets/IMG_0919.gif)

[Watch or download the full video (WebM)](Assets/IMG_0919.webm)

## Features and current limits

- Manual power and brightness, with remembered settings and 10% steps.
- Idle timeout: Never, 15/30 seconds, 1/5/10/30 minutes; automatic restoration at the saved brightness.
- Manual-off protection and sleep/session reevaluation.
- Background illumination-event monitoring with recovery and optional targeted diagnostics.
- Native setup, safe staging/rollback and eight languages: English, Dutch, German, French, Spanish, Italian, Portuguese and Polish.

| Hardware / behavior | Status |
|---|---|
| MacBookPro16,1 / A2141 Magic HID method | Hardware-proven Magic method; report bytes preserved. Fresh full regression matrix is not separately hardware-confirmed |
| Original Touch Bar controls | Monitoring implemented; event emission and physical response still require testing |
| MacBookPro15,4 / Issue #2 | Supported backlight protocol; tester reports successful beta7.1 compilation/app launch, backlight, idle timeout and wake response on Sequoia 15.8.3. Brightness steps appear to work; some differences are hard to distinguish. [Evidence and remaining checks](BETA7.1-ACCEPTANCE.md) |
| Other T2 models | Experimental; no compatibility claim without hardware evidence |
| Ambient-light adjustment | Unsupported without a reliable sensor/data source |
| Sunset/sunrise schedules and complete lock policy | Future work in the same codebase |

No LED commands are allowed for an unvalidated interface. The proven A2141 report bytes and installer rollback protections are retained. See [Issue #2](https://github.com/EasyCompZLD/EasyComp-Keyboard-Light---For-headless-Apple-MacBook-Pro-s-with-T2-Chip/issues/2) for the Butterfly hardware evidence and remaining acceptance checks.

## Development and testing

Use the existing checkout and `dev/beta`:

```sh
python3 -m unittest discover -s tests -v
bash Controleer-build.command
bash scripts/build-release.sh
```

These are developer commands; users use the Setup app. Automated tests target macOS. The build creates a universal setup GUI containing the backend for Intel T2 installation. It signs and verifies the ZIP without installing, launching a controller or changing keyboard lighting.

See [development workflow and backlog](BETA-DEVELOPMENT.md), [hardware acceptance](HARDWARE-ACCEPTANCE.md) and [contributing](CONTRIBUTING.md). Generated artifacts and caches stay out of Git. Previous beta notes are retained in [docs/history](docs/history/).

I approved stable publication on 13 November 2026 using the recorded A2141 evidence and MacBookPro15,4 tester follow-up. [Release scope and acceptance limits](RELEASE-ACCEPTANCE.md) distinguish supported backlight operation from unconfirmed Touch Bar and edge cases. Future publication and merges require my authorization.

## Thanks to my testers

- [@mjesticfalco](https://github.com/mjesticfalco) — thank you for the MacBookPro15,4 / Sequoia 15.8.3 reports, safe Butterfly protocol tests, and confirmation of the integrated app, brightness steps, idle timeout and wake response. Your testing helped me bring this model into the release.

I test the original A2141 / MacBookPro16,1 through EasyComp Zeeland. I only list contributors whose testing is documented; I will add other testers when they contribute.

## Privacy and troubleshooting

Use **Diagnostic report** in Setup. Reports stay local and are never uploaded automatically. Review a report before copying it to a public issue; remove personal data if present. No serial numbers, typed text or hardware UUIDs are intentionally collected.

Only run one keyboard-light controller at a time. Setup asks the running controller to quit before updating or uninstalling and waits for it to exit. Uninstall keeps saved preferences.

[License](LICENSE) · [GitHub Releases](https://github.com/EasyCompZLD/EasyComp-Keyboard-Light---For-headless-Apple-MacBook-Pro-s-with-T2-Chip/releases)
