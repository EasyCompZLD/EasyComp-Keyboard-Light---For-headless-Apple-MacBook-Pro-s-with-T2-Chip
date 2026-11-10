# EasyComp Keyboard Light — Install in your language

**One double-click. No Terminal command to type.** Extract this entire ZIP first. Choose a file:

| Language | Installation file |
| --- | --- |
| 🇬🇧 English | `Install - English.command` |
| 🇳🇱 Nederlands | `Installeren - Nederlands.command` |
| 🇩🇪 Deutsch | `Installieren - Deutsch.command` |
| 🇫🇷 Français | `Installer - Français.command` |
| 🇪🇸 Español | `Instalar - Español.command` |
| 🇮🇹 Italiano | `Installa - Italiano.command` |
| 🇵🇹 Português | `Instalar - Português.command` |
| 🇵🇱 Polski | `Zainstaluj - Polski.command` |

Or run **`Install.command`** to use your macOS language automatically. A graphical wizard will open, with a language dropdown, install button and diagnostic/report controls.

Find **`Languages/<your language>/`** for localized clickable Build Check, Diagnostic Report, Hardware Check and Uninstall scripts.

The wizard is built locally on your Mac with Apple Command Line Tools. On first launch macOS may request permission to open an unnotarized `.command` script. Review the project source if you prefer. No administrator privileges, SIP changes or network access are required. Nothing is uploaded automatically.

**Experimental beta:** only `MacBookPro16,1` has a hardware-proven HID control method. Other T2 MacBooks are experimental and must pass protocol checks before any LED commands are sent.

**Prerequisites:** The setup automatically uses your existing Xcode or Apple Command Line Tools. If both are missing, it opens Apple's installation dialog and resumes once you approve and complete it.
