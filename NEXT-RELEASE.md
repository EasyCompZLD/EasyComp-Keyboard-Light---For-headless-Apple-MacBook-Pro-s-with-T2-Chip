# EasyComp Keyboard Light 1.2.1 — draft, not published

I am adding optional automatic updates from my GitHub releases. Enable **Automatically install stable updates** in the menu to check hourly and install a verified newer stable version through Setup. You can also choose **Check for updates…** and decide whether to install. No Terminal commands are required.

I verify the GitHub asset digest, release version, download URL, ZIP paths and Setup identity before handing off to the existing installer and rollback. Drafts, betas, downgrades and unvalidated devices are refused. The updater is initially off and needs no GitHub account. See [update behavior and trust limits](AUTO-UPDATES.md).

The published 1.2.0 app has no updater. Install the updater-equipped version once through Setup; subsequent stable releases can then update automatically. This draft does not change the already published 1.2.0 archive. End-to-end update acceptance is still required before I publish this version.

## HID access recovery — Issue #7

I have added an explicit Setup recovery flow when macOS refuses keyboard HID access. It distinguishes access denial from an unsupported descriptor, offers Request access and Retry installation, and repeats the read-only probe before replacement. The permission request only happens after a click. Diagnostic reports now record the process permission status, Setup context and HID source fingerprint. Successful A2141 feature access does not acquire a new Input Monitoring prerequisite.

The tester reports stable 1.2.0 failing while beta7.1 still works. I have verified that their HID code differs only in the version comment. The exact reason for the different macOS access decisions is still unconfirmed; I do not claim a tested hardware fix from the regression fixtures. See [Issue #7 acceptance](ISSUE7-ACCESS-RECOVERY.md).

## Thanks to my testers

Thank you to [@mjesticfalco](https://github.com/mjesticfalco) for the MacBookPro15,4 diagnostics and physical tests that helped me deliver Butterfly backlight compatibility. I test the original A2141 / MacBookPro16,1 through EasyComp Zeeland. I will add other testers as their contributions are documented.
