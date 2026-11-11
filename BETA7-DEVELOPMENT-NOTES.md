# EasyComp Keyboard Light v1.2.0-beta7 development build

Status: **testing build**, not a production release. Do not replace the existing beta6 release asset until the Mac hardware checks pass.

## Review update — 11 November 2026

See [development review](DEVELOPMENT-REVIEW-2026-11-11.md) for the confirmed brightness-step defect, event-monitor and write-queue fixes, current automated results and Apple behavior comparison. See [hardware acceptance](HARDWARE-ACCEPTANCE.md) for the isolated Intel test app and physical validation matrix. This supersedes the earlier validation counts below; beta7 is still not a release.

## Changes

- User-configurable keyboard backlight idle timeout: Never, 15 seconds, 30 seconds (default), 1 minute, 5 minutes, 10 minutes or 30 minutes.
- Automatic light restoration when user activity resumes. Manual power off and the last manually selected brightness remain independent of the idle state.
- Lights are commanded off for system sleep and user session switching; resume on wake/unlock.
- Passive global NSEvent listener supplements the independent session event tap for illumination button events, with a short duplicate-event guard.
- Restore the verified beta6 staged installer (`Installeer.command`) so existing source-safety and tool-prerequisite tests pass.
- Update GitHub Actions checkout to v5 to eliminate the Node.js 20 deprecation warning.
- All eight app languages have the new timeout menu and state strings.
- New source-level regression tests; 30 Python tests pass here. Swift source parses, but **must be compiled on macOS** to validate AppKit and CoreGraphics APIs.

## Limitations

- A missing or disconnected ambient-light sensor prevents the original automatic light-sensor adjustment from functioning. This update does not simulate a physical ambient-light sensor.
- Original Touch Bar buttons require macOS to continue generating illumination events. A passive event listener cannot restore keys that macOS no longer emits. Test on the actual headless T2 Mac.
- Do not commit a beta7 release tag or publish an asset until the installer, idle timeout, wake/resume, and Touch Bar have been tested on hardware.

## Local validation

```sh
python3 -m unittest discover -s tests -v
bash Controleer-build.command
```

To test on the headless Mac, launch the current installer after applying these changes to the repository; first copy the current installed app to a backup if you need a rollback path.
