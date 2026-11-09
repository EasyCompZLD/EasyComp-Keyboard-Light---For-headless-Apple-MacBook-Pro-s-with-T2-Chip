# EasyComp Keyboard Light v1.2.0-beta6 — test instructions

1. Extract the complete ZIP, including the `Languages`, `scripts` and `broncode` folders.
2. Double-click `Install.command` to follow macOS language, or choose a localized starter:
   - English: `Install - English.command`
   - Nederlands: `Installeren - Nederlands.command`
   - Deutsch: `Installieren - Deutsch.command`
   - Français: `Installer - Français.command`
   - Español: `Instalar - Español.command`
   - Italiano: `Installa - Italiano.command`
   - Português: `Instalar - Português.command`
   - Polski: `Zainstaluj - Polski.command`
3. The native setup wizard is compiled using existing Apple Xcode or Command Line Tools and **opens automatically**. No second manual launch is required.
4. Choose a language from the dropdown if needed, then click the translated Install button.
5. Check the keyboard backlight, and test Touch Bar illumination keys with the status menu **closed** as well as opened.
6. For compatibility problems, choose the translated Diagnostic Report action; review the local report, then optionally paste into GitHub Issues.

The `Languages` folder contains five commands per language: Install, Build Check, Diagnostic Report, Read-only Hardware Check, and Uninstall (with confirmation). Internal `.command` filenames stay unchanged to preserve a single maintained implementation.

**Important:** beta6 has passed source-level, shell syntax, Swift parse and simulated prerequisite-detection tests, **not a native macOS build or real-hardware test** in this environment. The v1.1.0 HID method is known to work on an A2141; new model support and the independent Touch Bar event loop are still experimental. Preserve your stable release until beta6 is accepted on hardware.

7. New in beta6: if Xcode already exists, the wizard must recognize it without prompting for Apple Command Line Tools. If neither toolchain exists, confirm the Apple system dialog; the wizard should continue by itself afterwards.

The prerequisite simulator has no access to real Apple developer tools on this build host. Hardware and real macOS installer acceptance must still be verified on a Mac.
