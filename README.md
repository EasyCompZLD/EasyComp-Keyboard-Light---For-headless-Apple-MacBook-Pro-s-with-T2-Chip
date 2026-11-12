# EasyComp Keyboard Light

<img src="Assets/AppIcon.png" alt="EasyComp Keyboard Light" width="120" align="right">

A native macOS menu bar app for keyboard backlight control on headless Intel MacBooks with an Apple T2 chip. Swift + C, eight languages, no kernel extensions or SIP changes.

**No Terminal commands required — setup is now more user friendly.**

**One development beta:** `1.2.0-beta` on `dev/beta`. The last published release remains `v1.2.0-beta6`. Current changes are local development and still require hardware acceptance.

## Start here

The current development package is `dist/beta/EasyComp-Keyboard-Light-Beta.zip`.

1. Copy the ZIP to a local folder and extract it.
2. Double-click **EasyComp Keyboard Light Setup.app**.
3. Choose your language, then click **Continue**.
4. Click **Install** or **Install / Update**.

No Terminal commands are needed. The setup app opens directly, before developer tools are checked. If Apple Command Line Tools are missing, installation opens Apple's official dialog; approve it there and setup continues. Normal macOS security approval may be required because this development app is ad-hoc signed, not notarized.

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
| MacBookPro16,1 / A2141 Magic HID method | Hardware-proven method; current beta changes need physical acceptance |
| Original Touch Bar controls | Monitoring implemented; event emission and physical response still require testing |
| MacBookPro15,4 / Issue #2 | BF configuration read confirmed; production writes remain disabled. [Isolated opt-in LED test](ISSUE2-COMPATIBILITY.md) awaits hardware results |
| Other T2 models | Experimental; no compatibility claim without hardware evidence |
| Ambient-light adjustment | Unsupported without a reliable sensor/data source |
| Sunset/sunrise schedules and complete lock policy | Backlog within the same beta |

No LED commands are allowed for an unvalidated interface. The proven A2141 report bytes and installer rollback protections are retained. See [Issue #2](https://github.com/EasyCompZLD/EasyComp-Keyboard-Light---For-headless-Apple-MacBook-Pro-s-with-T2-Chip/issues/2) for the pending Butterfly investigation.

## Development and testing

Use the existing checkout and `dev/beta`:

```sh
python3 -m unittest discover -s tests -v
bash Controleer-build.command
bash scripts/build-beta.sh
```

These are developer commands; users use the Setup app. Automated tests target macOS. The build creates a universal setup GUI containing the backend for Intel T2 installation. It signs and verifies the ZIP without installing, launching a controller or changing keyboard lighting.

See [development workflow and backlog](BETA-DEVELOPMENT.md), [hardware acceptance](HARDWARE-ACCEPTANCE.md) and [contributing](CONTRIBUTING.md). Generated artifacts and caches stay out of Git. Previous beta notes are retained in [docs/history](docs/history/).

Do not publish, tag, merge to `main` or close the compatibility issue before the required acceptance and publication authorization.

## Privacy and troubleshooting

Use **Diagnostic report** in Setup. Reports stay local and are never uploaded automatically. Review a report before copying it to a public issue; remove personal data if present. No serial numbers, typed text or hardware UUIDs are intentionally collected.

Only run one keyboard-light controller at a time. Setup asks the running controller to quit before updating or uninstalling and waits for it to exit. Uninstall keeps saved preferences.

[License](LICENSE) · [GitHub Releases](https://github.com/EasyCompZLD/EasyComp-Keyboard-Light---For-headless-Apple-MacBook-Pro-s-with-T2-Chip/releases)
