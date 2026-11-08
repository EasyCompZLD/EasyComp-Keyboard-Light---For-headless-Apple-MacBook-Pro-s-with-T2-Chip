# EasyComp Keyboard Light v1.1.0

**No display. No light sensor. Still a glowing keyboard.** 💡

Apple's normal macOS keyboard-backlight control can disappear when the ambient light sensor goes away with a MacBook's display. On our headless **2019 16-inch MacBook Pro (MacBookPro16,1 / A2141)**, the keyboard LEDs still work: **direct USB-HID commands to the T2 backlight interface turn them on, set brightness and turn them off**.

In other words: macOS effectively gives headless owners the *metaphorical middle finger* with its usual controls, but the hardware doesn't require the screen sensor to illuminate. This is an observed software limitation, not evidence of Apple's intent.

### What’s included

- Native macOS menu bar controls: brightness, up/down, on/off
- Per-user automatic start and saved brightness restoration
- New native application icon, with editable SVG source
- 8 UI languages: English, Dutch, German, French, Spanish, Italian, Portuguese and Polish
- Automatic macOS language detection and manual selection
- Optional support for original Touch Bar illumination events (when macOS still emits them)
- Local installation scripts, source code, MIT license and documentation

### Supported hardware

**Validated HID approach:** MacBookPro16,1 / A2141 · Intel T2 · macOS Tahoe 26. Other models are not yet tested; the installer refuses them by default. The v1.1.0 UI and localization update should be verified on-device before marking this release stable.

### Installation from source

Download the project source archive, extract it, and from Terminal in the folder run:

```bash
bash Controleer-build.command
bash Installeer.command
```

Requires Apple Command Line Tools. Builds `~/Applications/EasyComp Keyboard Light.app` locally. Not notarized or Developer ID-signed. FileVault and SIP remain enabled. No telemetry or network access.

### Known limitations

- Only the A2141 model is intentionally supported at present
- Touch Bar illumination buttons depend on macOS still publishing illumination key events; menu bar controls work independently
- No separate settings window; settings are in the menu bar
- The app starts after logging in, not at FileVault preboot

Developed by **EasyComp Zeeland** · MIT License · Independent of Apple.
