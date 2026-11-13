# Beta7.1 integration acceptance

Stable promotion: I approved version 1.2.0 on 13 November 2026 using the evidence below, without requesting further tester confirmation. See [stable release scope](RELEASE-ACCEPTANCE.md). Remaining checks below are still unconfirmed, not failed.

The Issue #2 report [6825954957](https://github.com/EasyCompZLD/EasyComp-Keyboard-Light---For-headless-Apple-MacBook-Pro-s-with-T2-Chip/issues/2#issuecomment-6825954957) confirms the exact `MacBookPro15,4 / 05ac:027d / 0001:0006 / BF-v1 / 0:32:512` configuration, two accepted B0 32/0 sequences and visible minimum lighting followed by off. The normal backend now integrates that protocol behind those same strict model/interface/configuration gates.

## Hardware follow-up — 13 November 2026

Source: [mjesticfalco's beta7.1 follow-up](https://github.com/EasyCompZLD/EasyComp-Keyboard-Light---For-headless-Apple-MacBook-Pro-s-with-T2-Chip/issues/2#issuecomment-6838177188), on the previously reported MacBookPro15,4 / Sequoia 15.8.3 setup. The comment follows the beta7.1 download instructions; it does not include a new diagnostic report or build hash.

| Check | Reported result |
|---|---|
| Compilation and menu bar app launch | Compiles normally; menu bar app appears. No installer error reported; rollback/update paths were not separately tested. |
| Backlight on | Working. |
| 10–100% brightness steps | Tester is quite sure they work; some levels are hard to distinguish. Qualified visual evidence, not a measurement of every step. |
| Idle timeout | Working; selected duration and input device are not specified. |
| Return from sleep | Backlight responds after sleep; exact level restoration and manual-off state are not specified. |

Still unconfirmed: explicit manual off in the integrated app, app restart/login and preference persistence, 15/30-second timing separately, Never, restoration of the exact chosen brightness through each input device, manual-off protection across activity/sleep, lights going off before sleep, Touch Bar with menu open/closed/another app frontmost, session/lock/permission behavior and fresh A2141 regression. These are separate checks, not evidence that the tester encountered a defect. Keep issue #2 open pending my review; do not request the entire successful test again.

## Tester follow-up checklist

The original checklist below is retained for reproduction; consult the results above before requesting further tests.

Use the ordinary Setup app, rather than the isolated Issue #2 test tool:

1. Preserve a copy of the installed app if one exists. Quit old controllers and the standalone test tool.
2. Extract the new beta7.1 ZIP locally, open Setup, choose language and Install/Update. Accept the experimental-model warning only when testing intentionally. A read-only probe must succeed before installation proceeds.
3. Check app launch, manual off/on, 10% through 100% brightness, and changing direction between steps. The helper values expected for the ten steps are 51, 102, 154, 205, 256, 307, 358, 410, 461 and 512. These are protocol/software expectations, not completed physical tests.
4. Check persistence after app restart, 15/30-second idle-off, activity restoration, Never and manual-off protection.
5. Check sleep/wake and session behavior. Record the original Touch Bar buttons with the menu open, closed and another app frontmost; do not infer Touch Bar compatibility from successful HID brightness writes.
6. Create the diagnostic report in Setup, review it and attach it with actual observations to issue #2. Keep the issue open until the integrated installer and brightness behavior are accepted.

## A2141 regression

The Magic descriptor functions and complete Magic write branch must compare identically against commit `5f2de80`. Automated HID fixtures check the exact original power/brightness packets, off and read-only probe behavior, plus rejection of a nonconforming Magic descriptor. Physical A2141 acceptance remains separate from those software checks.

The installer rollback and application state machine are unchanged; only release metadata changes in the installer/wizard/app sources. Normal VID/PID matching remains scoped, and dictionary allocation/partial construction must fail closed rather than submitting an incomplete HID match.

## Release boundary

This is a compatibility prerelease from the existing `dev/beta` branch, not a new development branch or stable release. Main and previous release assets must not be overwritten. Release publication requires the my instruction; no issue comment or tester message is sent automatically.

## Local verification

- `python3 -m unittest discover -s tests -v`: 36 passed, zero failures/skips.
- 45 production-HID fixture scenarios: read-only probe/diagnose, off, all ten brightness steps, model/VID/PID/usage/descriptor/configuration/uniqueness gates, access/output errors and exact Magic packet regression.
- 38 retained isolated-tool scenarios and the existing native GUI/state/localization/installer checks also pass. No real HID helper is run by these fixtures.
- `bash Controleer-build.command`: native app, setup, research tool, metadata and all sixteen localization tables passed.
- Compared with `5f2de80`: Magic usage/descriptor functions, complete Magic write branch and report writer are identical. Installer/app state logic differs only in version labels.
- Physical evidence now includes the original two minimum/off cycles and the successful integrated-app follow-up above. Brightness evidence retains the tester's qualification. Remaining explicit checks and fresh A2141 physical acceptance are not marked complete.
