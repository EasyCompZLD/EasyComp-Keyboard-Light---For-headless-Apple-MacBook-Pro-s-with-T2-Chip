# EasyComp Keyboard Light - For headless Apple MacBook Pro’s with T2 Chip.

<img src="Assets/AppIcon.png" alt="EasyComp Keyboard Light application icon" width="144" align="right">

**No display. No ambient light sensor. Still a glowing keyboard.**

A free, open-source macOS menu bar app that restores **keyboard backlight control** on a headless **2019 16-inch MacBook Pro (A2141 / MacBookPro16,1, Intel T2)** by talking directly to its USB-HID backlight interface.

**Version 1.1.0 · macOS · Swift + C · 8 languages · MIT License · Made by EasyComp Zeeland**

[Installation](#installation) · [How it works](#how-it-works) · [Compatibility](#compatibility) · [Dutch instructions](LEESMIJ.md) · [License](LICENSE)

<h2>🎬 Live Demonstration</h2>

<p>See EasyComp Keyboard Light in action on a headless MacBook Pro.</p>

<img src="Assets/IMG_0919.gif" alt="EasyComp Keyboard Light Demo" width="500">


## Why this exists: an unnecessary software roadblock

Remove the broken display from a MacBook Pro, and you also remove its ambient light sensor. On the tested MacBook, **macOS then removes the normal keyboard-backlight controls**. The Touch Bar buttons no longer work through the usual path, System Settings offers no useful control, and Apple's CoreBrightness interface fails to report a usable brightness value.

It feels like Apple is giving headless Mac owners the *metaphorical middle finger*: no sensor, no keyboard light. **But here's the interesting part: the sensor isn't required for the backlight LEDs to work.**

We confirmed that on a real, headless MacBookPro16,1: writing the correct feature reports directly to the T2's USB-HID backlight interface **turns the keyboard lights on, changes their brightness and turns them off again**, without reconnecting the display or sensor.

> **macOS:** No ambient light sensor? No backlight controls.  
> **EasyComp Keyboard Light:** Hold my HID report. 💡

This describes the observed behavior and workaround on the tested machine. It does **not** claim that Apple deliberately designed the restriction to prevent headless use, or that the light sensor serves no other purpose.

## Features

- Native macOS menu bar utility with a brightness slider, 10% steps, and on/off control
- Dedicated application icon and a discreet menu bar keyboard symbol
- Saves brightness and restores the last level when the app starts after login
- Optional automatic start via a per-user LaunchAgent
- Listens for original Touch Bar keyboard-illumination key events **if macOS still emits them**; the menu bar controls work even if it doesn't
- Eight interface languages, selected automatically from macOS or manually in the menu: **English, Nederlands, Deutsch, Français, Español, Italiano, Português and Polski**
- Works locally: **no network calls, no telemetry, no root daemon, no kernel extension, no SIP or FileVault changes**

The app has **menu-based settings**. It does not currently include a separate settings window.

## Compatibility

| Configuration | Support |
| --- | --- |
| **MacBookPro16,1 / A2141** · 16-inch 2019 Intel MacBook Pro with T2 | **Direct HID backlight method confirmed on actual hardware** |
| macOS Tahoe 26 | Confirmed for the working HID method and prior menu bar version; check the updated v1.1.0 build on your Mac |
| Other Intel Macs with T2 | **Not verified**; the installer intentionally rejects other models |
| Apple Silicon | Not supported |
| FileVault pre-boot unlock screen | Not available; the app starts **after** macOS login |

The title describes the *type* of device this project targets; **support is presently limited to the specific tested A2141 model**. Other models may use different hardware or HID protocols. Please open an issue with technical findings rather than assuming compatibility.

## Installation

This is a **source-code release**, not a ready-made notarized `.app` or `.dmg` download.

1. Download the project ZIP from GitHub (**Code → Download ZIP**) and extract it.
2. Open Terminal in the extracted project folder.
3. Run:

   ```bash
   bash Controleer-build.command
   bash Installeer.command
   ```

4. Find **EasyComp Keyboard Light** in your menu bar. The app is installed in `~/Applications/EasyComp Keyboard Light.app`.

The installer uses Apple's local Command Line Tools. If they are not installed, use `xcode-select --install`, then retry. It compiles the native Swift app and the C HID helper, builds the icon, bundles translations and applies a local ad-hoc signature. Run the installer **as your normal user**, not with `sudo`.

### Update

Run `bash Installeer.command` again from the newer project folder. Existing app preferences, including brightness and language, are preserved. A rebuilt app may need renewed Input Monitoring permission for Touch Bar key events.

### Uninstall

```bash
bash Verwijder.command
```

Removes the app and login LaunchAgent; user preferences remain saved.

## How it works

The built-in keyboard backlight can be controlled through a specific **Apple T2 USB-HID** interface. The helper uses macOS IOKit HID functions and validates the device and feature descriptor before sending commands:

| Property | Value |
| --- | --- |
| Vendor / Product | `0x05AC : 0x8102` |
| Usage Page / Usage | `0xFF00 / 0x000F` |
| Power feature report | ID `3` (6-byte report) |
| Brightness feature report | ID `1` (9-byte report) |
| Confirmed brightness descriptor range | `100–14660` |

A direct HID write succeeded on the test Mac even when the normal macOS CoreBrightness path returned `-1.0000` after the display/sensor was removed. The method uses **no SMC register hacks or firmware changes**. HID behavior and access permissions can vary across macOS releases.

## Touch Bar controls and privacy

The app listens only for macOS **system-defined keyboard illumination events** (up/down/toggle), which are separate from typing. It does not capture text and has no analytics or network connection. Some macOS configurations stop emitting these events when the ambient light sensor is gone; if so, use the menu bar controls. macOS may request **Input Monitoring** access for event listening.

## Languages

Open the menu bar icon → **Language** → choose a language or **Automatic (macOS)**. Translation files are kept in `broncode/Localizations/*.lproj/Localizable.strings`. Contributions and proofreading are welcome.

## Project layout

- `broncode/EasyCompKeyboardLight.swift` — native menu bar app and event handling
- `broncode/HIDBacklight.c` — T2 HID descriptor validation and control
- `broncode/Info.plist` — app metadata
- `broncode/Localizations/` — eight UI translations
- `Assets/AppIcon.svg` — editable icon source
- `Assets/AppIcon.png` and `Assets/AppIcon.iconset/` — application icon resources
- `Installeer.command` — compile and install locally
- `Controleer-build.command` — build check
- `Verwijder.command` — uninstall
- `.github/workflows/build.yml` — macOS CI compile check
- `LEESMIJ.md` — Dutch instructions
- `GITHUB-HANDLEIDING.md` — manual browser publishing guide

## Contributing

Bug reports, compatible-device testing, translations and code contributions are welcome. Please include your **Mac model identifier, macOS version, relevant non-sensitive logs, and whether the backlight physically illuminated**. Read [CONTRIBUTING.md](CONTRIBUTING.md) before submitting a pull request. Never publish serial numbers, hardware UUIDs, passwords or personal data in issues.

## License and disclaimer

Released under the [MIT License](LICENSE). Copyright © 2026 **EasyComp Zeeland**.

This is an independent community project, **not affiliated with, endorsed by or supported by Apple**. Use at your own risk; the maintainers cannot guarantee support for every firmware or macOS version.
