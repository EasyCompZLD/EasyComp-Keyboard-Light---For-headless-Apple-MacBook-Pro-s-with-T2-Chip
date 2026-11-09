# EasyComp Keyboard Light v1.2.0-beta6 — Pre-release

**No display. No ambient light sensor. Still a glowing keyboard. 💡**

This is an **experimental update** for EasyComp Keyboard Light, the open-source macOS menu bar utility that restores keyboard illumination on our headless **2019 16-inch MacBook Pro (MacBookPro16,1 / A2141)** via the Apple T2 USB-HID interface.

## What's new

- **One-click graphical installer:** double-click a launcher; the macOS setup wizard builds and opens automatically, with progress and understandable error messages.
- **Automatic prerequisites:** reuse an installed Xcode or Command Line Tools. If missing, launch the official Apple installation prompt, requiring user approval.
- **8-language setup:** English, Dutch, German, French, Spanish, Italian, Portuguese and Polish. Includes translated buttons, messages, and clickable installer, diagnostic, build-check and uninstall commands.
- **Touch Bar background handling:** illumination-key events are now listened for on a dedicated event-tap runloop, independently from the open/closed state of the menu bar menu. **Please test and report whether this works on your Mac.**
- **Safer installation and upgrades:** stage the new build and check compatibility before replacing an existing installation, with best-effort recovery.
- **Development diagnostics:** when installation fails, a local, privacy-conscious report explains why, with a link to our GitHub issue form. No automatic upload.
- **Experimental T2 compatibility discovery:** read-only HID checks and explicit opt-in for unvalidated Mac models. Other models are not yet confirmed working.
- **Recorded installation and demonstration:** `Assets/EasyComp Keyboardlight install and demo.mp4` (76 seconds).

## Installation

1. Download and extract the attached **EasyComp-Keyboard-Light-v1.2.0-beta6-GitHub-Ready.zip** release asset. This is recommended because it preserves executable permissions on the double-clickable `.command` launchers. GitHub-generated source archives may not retain those permissions when files were uploaded through the browser.
2. Double-click **`Install.command`** (automatic language detection), or a language-specific launcher such as `Install - English.command` / `Installeren - Nederlands.command`.
3. The native macOS wizard will open automatically after its local build. Click **Install** and follow the steps.
4. If macOS requires approval for the downloaded script or Apple's developer tools, review and confirm the system prompts.

Requires an Intel Mac running macOS with working Xcode or Apple Command Line Tools (automatically requested if genuinely missing). The app is built locally, not notarized or Developer ID-signed, and runs after login. SIP and FileVault do not need to be disabled.

## Compatibility and status

- **Confirmed HID control method:** `MacBookPro16,1 / A2141`, 2019 16-inch Intel T2, macOS Tahoe 26.
- **New wizard, event-tap and expanded-model paths:** experimental; further device testing and feedback welcome.
- **Other T2 MacBooks:** do not assume compatibility. Follow the safe diagnosis and experimental opt-in instructions.
- **Apple Silicon:** not supported.

The existing **v1.1.0 remains the stable release**. Publish this beta with GitHub's **Set as a pre-release** box selected.

## Demo and support

**[▶ Watch installation and demo (MP4)](https://github.com/EasyCompZLD/EasyComp-Keyboard-Light---For-headless-Apple-MacBook-Pro-s-with-T2-Chip/blob/main/Assets/EasyComp%20Keyboardlight%20install%20and%20demo.mp4)** — video stored in the repository's `Assets/` directory.

If the installation fails, use `Probleemrapport.command` (or the command in your language) and open an issue at:
https://github.com/EasyCompZLD/EasyComp-Keyboard-Light---For-headless-Apple-MacBook-Pro-s-with-T2-Chip/issues/new

**EasyComp Zeeland** · MIT License · Independent of Apple Inc.
