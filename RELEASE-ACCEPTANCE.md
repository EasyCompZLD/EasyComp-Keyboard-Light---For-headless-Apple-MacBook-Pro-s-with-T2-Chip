# Version 1.2.0 release scope and acceptance

The repository owner explicitly approved stable publication on **13 November 2026**, based on existing A2141 operation and the successful MacBookPro15,4 integrated-app follow-up. Additional tester confirmation was not required by the owner. This supersedes the earlier requirement to keep the entire application in beta until every matrix row is checked.

## Evidence

- MacBookPro16,1 / A2141: proven Magic-HID backlight method. The protocol functions and report bytes are preserved from beta7.1. Fresh exhaustive A2141 acceptance is not claimed.
- MacBookPro15,4 / Sequoia 15.8.3: [isolated minimum/off test](https://github.com/EasyCompZLD/EasyComp-Keyboard-Light---For-headless-Apple-MacBook-Pro-s-with-T2-Chip/issues/2#issuecomment-6825954957) and [integrated-app follow-up](https://github.com/EasyCompZLD/EasyComp-Keyboard-Light---For-headless-Apple-MacBook-Pro-s-with-T2-Chip/issues/2#issuecomment-6838177188). The tester reports normal compilation, menu bar app launch, lighting, idle timeout and wake response. The tester is quite sure 10–100% steps work, while noting that some differences are hard to distinguish.
- Stable promotion changes release metadata, packaging and recognition of the confirmed model in the installer; it does not change HID report bytes, brightness calculations or the lighting state machine. Unknown models still require experimental confirmation and successful protocol validation.

## Unconfirmed or future behavior

Original Touch Bar illumination controls are implemented but **not hardware-confirmed**. They are not part of the stable compatibility claim. Manual-off protection and preference persistence are implemented and regression-tested, but the external tester did not separately confirm them. Exact restoration, individual timeout modes, permissions, session/lock behavior and the complete hardware matrix remain documented checks. No new failures are inferred from missing confirmations.

Sunset/sunrise schedules, custom schedules and the complete optional lock policy remain future work. Automatic ambient-light adaptation has no reliable physical sensor source. Other T2 models remain experimental.

The software is ad-hoc signed, not notarized. The normal Setup GUI requires no Terminal input and may open Apple's developer-tool installation dialog. Stable publication does not alter these installation requirements.

## Verification record

Current 1.2.0 release validation: **36 macOS tests passed, zero failures/skips**, including 45 production-HID fixture scenarios and 38 isolated-tool scenarios. The native macOS build, both app metadata files, all sixteen localization tables and the icon passed. Shell syntax, documentation links, version consistency and the unchanged HID/state-machine comparison are also checked before publication. Tests use HID mocks; no physical HID writes are made by the automated suite.

The stable package is `dist/release/EasyComp-Keyboard-Light.zip`; `BUILD-INFO.txt` and `SHA256SUMS.txt` identify the release build. The single builder is `scripts/build-release.sh`; `scripts/build-beta.sh` remains a compatibility entry point. Version suffixes select prerelease packaging. Main, earlier tags and earlier release assets are preserved. Issue closure and tester replies are separate owner-authorized actions.
