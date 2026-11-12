> Status update: the tester confirmed two minimum/off cycles in [comment 6825954957](https://github.com/EasyCompZLD/EasyComp-Keyboard-Light---For-headless-Apple-MacBook-Pro-s-with-T2-Chip/issues/2#issuecomment-6825954957). Beta7.1 now integrates the exact protocol into the regular backend; see [integrated acceptance](BETA7.1-ACCEPTANCE.md). The instructions below describe the original isolated tool at commit `5f2de80`, not the new production gate.

# Issue #2 — isolated Butterfly compatibility test

**Research tool, not an installer or a compatibility claim.** The regular beta and production HID helper still refuse LED writes to PID `027d`. This experiment is built separately from the same `dev/beta` checkout. It does not create a second development beta or change A2141 control.

## Confirmed evidence

On 12 November 2026, [mjesticfalco's follow-up](https://github.com/EasyCompZLD/EasyComp-Keyboard-Light---For-headless-Apple-MacBook-Pro-s-with-T2-Chip/issues/2#issuecomment-6810254280) reported:

- MacBookPro15,4, macOS 15.8.3.
- One matching `05ac:027d` primary keyboard collection `0001/0006`.
- Input signature `ff00/000f`, report `BF`.
- Feature GetReport `BF`: success, length 8, ID `BF`, version 1.
- Configuration: off 0, minimum 32, maximum 512.

The original follow-up does not separately print the device-open status or numeric IOKit status. The new test records both explicitly. A successful configuration read confirms neither output-report support nor visible illumination.

The six-byte output layout (`B0`, version 1, little-endian brightness, zero rate) already exists in the Butterfly implementation and is described by the [Linux Apple HID driver](https://github.com/torvalds/linux/blob/master/drivers/hid/hid-apple.c). No new report bytes or private T2 commands are invented. Its accessibility through macOS remains the purpose of this opt-in experiment.

## Build and delivery

Developer command:

```sh
bash scripts/build-issue2-test.sh
```

Output: `dist/issue2/Issue2-Butterfly-Compatibility-Test.zip`, containing one native **EasyComp Keyboard Light Issue 2 Test.app**. It has its own bundle ID, no autostart, no settings migration and no installation step. The GUI is universal; its HID helper is Intel x86_64. It is an English-language support tool for this tester; the normal application and setup retain all eight translations.

The build does not run the helper or change keyboard lighting. Signatures are verified after extracting the archive copied through the network share. `BUILD-INFO.txt` and source hashes identify the tested revision. The tool is ad-hoc signed, not a notarized public release.

Do not post to GitHub, send the tester a message, or publish a release automatically. The repository owner can share the ZIP and the instructions below after reviewing the package.

## Tester instructions — no Terminal commands

1. Copy the ZIP to your local Mac and extract it there. Double-click **EasyComp Keyboard Light Issue 2 Test.app**, using macOS's normal opening approval if prompted for this ad-hoc signed research build. Only MacBookPro15,4 can run hardware actions.
2. Quit any other keyboard-light controllers, including a previous beta test app. The tool checks known controller bundle IDs and uses a per-user helper lock to prevent simultaneous copies of this experiment. Do not run controllers in another user session during the test.
3. Click **1. Run read-only probe**. This does not issue SetReport commands. Review the device-open result, feature-read result, returned report length and configuration in the window. The expected values are exactly `off=0, min=32, max=512`.
4. Stop and share the report if anything differs. LED buttons remain locked after a failed or ambiguous probe. Review the successful probe before ticking the explicit confirmation checkbox.
5. Only then click **2. Test minimum light for 2 seconds**. The helper reopens and revalidates the exact interface/configuration. It attempts brightness 32, waits two seconds and attempts off 0. There is no high-brightness option, report sweep or automatic retry. This changes the light state and does not restore an unknown previous brightness.
6. An accepted HID request is not proof of working LEDs. Select the **Physical observation** that matches what the keyboard actually did. If the off request fails, the physical state remains uncertain. A separate **Send Off only** action is available only after a fresh successful probe and explicit confirmation when a prior action failed.
7. A private local report is saved in Downloads as `ECZ-KeyboardLight-Issue2-Compatibility-<timestamp>-<process>.txt`. Use **Show report in Finder** or **Copy report**. Review it before sharing on issue #2. No report is uploaded automatically.

A running helper gets a 12-second deadline. The GUI blocks closing while it runs so a normal pulse can attempt off; a termination request also asks the C helper to attempt off after an accepted low-light request. Forced termination, device removal or an IOKit failure can prevent cleanup; the report must not claim the light is off in that case. A timed-out action invalidates the GUI's probe approval.

## Boundaries and outcomes

- Exact model and `05ac:027d` primary `0001/0006` match only; no `8102`, `027b`, broad Apple matching or seized keyboard input.
- Exactly one input descriptor with `ff00/000f`, BF, 120 bits, count 15 and range 0–255; ambiguity is refused before opening a candidate.
- Fresh feature configuration before every user-requested action, with the same opened device retained for the pulse and off sequence; exactly 8 bytes, BF/version 1, values 0/32/512.
- Only user-confirmed `pulse` and `off` modes permit output, with values 32 and 0 only. The CLI helper also requires the explicit reviewed-probe argument; its default is read-only probe.
- Status 2: missing/invalid confirmation; 3: unsupported host/resource setup; 4: lock/manager access; 5: unknown/ambiguous interface; 6: device-open failure; 7: configuration failure; 8: output failure; 9: interrupted test; GUI 124: deadline exceeded.

A successful pulse and confirmed physical response are grounds for a subsequent reviewed integration into the normal beta. An unsupported output result is useful diagnostic evidence, not permission to try other reports. Keep issue #2 open until physical compatibility validation is complete.

## Local verification — 12 November 2026

- Full macOS regression suite: 35 tests passed, no failures/skips.
- C helper: 38 fixture scenarios with every HID API replaced; model/interface/configuration/confirmation gates, output failures, interruption and timer-failure cleanup covered.
- Native GUI fixture: probe alone cannot authorize writes; explicit confirmation is consumed per action; failed/malformed probes lock controls; reports separate API acceptance from user observation.
- `bash Controleer-build.command`: main app, setup, research helper/GUI, metadata and all eight app/eight setup translations compiled/validated.
- Production `HIDBacklight.c`, menu bar app, installer and setup GUI are unchanged from the prior revision. The normal installer still refuses PID 027d output compatibility.
- Real LED response, actual macOS permissions and successful output on the tester's Sequoia system remain pending. No real HID helper was run during verification.
