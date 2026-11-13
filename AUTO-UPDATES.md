# Automatic stable updates — unreleased 1.2.1 development

I am adding this feature after stable 1.2.0. It is **not present in the published 1.2.0 app**: the updater-equipped version must first be installed through Setup. I have not published a new release for this development work.

## User workflow

- **Automatically install stable updates** is off initially. Enabling it allows public GitHub checks and automatic installation through the existing Setup app. The preference persists across updates.
- The running app checks on launch when due and then hourly, while awake in the active user session. A release is picked up at the next check, not instantly when published. No background server, GitHub token or account is required.
- **Check for updates…** explicitly checks now. If a verified newer version is available, the user chooses Install update or Later. This does not enable automatic updates.
- Only newer stable versions from my fixed GitHub repository are eligible. Drafts, prereleases, malformed versions, missing digests, duplicate assets, unrelated download URLs and downgrades are refused. A stable release can replace an installed development build of the same version.
- Setup stops the existing controller, runs the read-only HID gate, compiles/stages the replacement and uses the existing rollback. The installer restarts the app; no Terminal input is needed. The exact language preference (including system default), login-item choice and existing lighting preferences are retained. Updates do not start while sleeping or in an inactive session.
- Automatic installation requires a previously installed app, the same advertised package version, the enabled preference and one of the two confirmed Intel models. It never enables experimental model support silently. The new Setup must advertise update protocol 1.

## Download trust and limits

I use GitHub's [latest-release API](https://docs.github.com/en/rest/releases/releases#get-the-latest-release) and [asset SHA-256 digest](https://docs.github.com/en/rest/releases/assets). The ZIP must match the digest and size, contain the expected Setup app and controller metadata, and pass code-signature verification. Only HTTPS GitHub downloads and the GitHub release-asset CDN are allowed. The ZIP is checked before extraction for traversal, symlinks, duplicate paths, unsupported formats and expansion limits.

The trust boundary is my GitHub repository/account over HTTPS. The SHA-256 digest detects mismatched bytes; **ad-hoc code signing does not independently authenticate me as publisher**. A compromised repository could publish a matching malicious package. This feature does not claim Developer ID signing, notarization or an independently signed update feed.

No network request is made by the updater until automatic updates are enabled or Check for updates is selected. Network/check failures leave the installed controller running. Disabling automatic updates invalidates an unfinished check. Setup handles installation errors visibly and attempts to reopen the retained/rolled-back app. Temporary staging uses a private local folder; successful handoff files remain available to Setup in macOS temporary storage.

## Acceptance

Automated fixtures cover version/release selection, digest/URL constraints, archive checks and Setup handoff policy without network access, installation or HID writes. Current local verification: **38 macOS tests passed, zero failures/skips**, including generated adversarial ZIP/release/digest fixtures, ten Setup handoff policy assertions and four login-item preservation cases. The native build and all sixteen localization tables passed without compiler warnings. The proven C HID source is unchanged from stable 1.2.0.

End-to-end acceptance remains separate: install the updater-equipped build on a confirmed Mac, enable the preference, publish a newer stable test version through the normal release process, observe one download and one controller replacement, verify restart/settings/manual-off, and repeat with offline access, invalid digest, disabled updates, a failed installer and inactive/sleeping sessions. Apple security approval or developer-tool installation may still require a normal macOS dialog. I do not mark this full update cycle as passed from fixtures alone.
