# Contributing to EasyComp Keyboard Light

Thanks for helping improve this small open-source project.

## Before reporting an issue

- Confirm your model identifier with `sysctl -n hw.model`.
- Check your macOS version and whether the display/ALS is physically disconnected.
- Describe what works: menu controls, actual keyboard LEDs, Touch Bar illumination buttons, login startup.
- Share concise diagnostics, with **serial numbers, hardware UUIDs, account names, tokens and personal data redacted**.
- Only MacBookPro16,1 / A2141 is currently supported. Reports from other T2 Macs are welcome as research, not evidence of compatibility.

## Pull requests

- Keep hardware handling conservative and preserve descriptor checks before HID feature writes.
- Do not add SMC register writes or instructions to disable SIP/FileVault without extensive evidence and a clear discussion.
- Maintain translations when adding UI strings.
- Run `bash Controleer-build.command` on a supported Mac before submitting if possible.
- Explain what you tested and what remains unverified.

By contributing, you agree that your contribution is distributed under the project's MIT License.
