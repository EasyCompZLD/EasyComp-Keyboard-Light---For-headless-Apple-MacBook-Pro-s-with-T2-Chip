# Draft reply for issue #2 — not posted

Hi @mjesticfalco,

Thank you! Your follow-up confirms that macOS can read the expected Butterfly configuration: 8 bytes, version 1, off 0, minimum 32 and maximum 512.

I've prepared a separate, controlled compatibility test app. It does not install or replace EasyComp Keyboard Light, and no Terminal commands are needed.

Please extract the attached `Issue2-Butterfly-Compatibility-Test.zip` locally and open **EasyComp Keyboard Light Issue 2 Test.app**. Quit any other keyboard-light controller first.

1. Click **Run read-only probe** and review the report. If the interface or configuration does not match, stop and share that report.
2. Only after reviewing a successful probe, tick the confirmation checkbox. You can then explicitly request a two-second pulse at the reported minimum brightness, followed by an off request.
3. Record what the actual keyboard LEDs did using **Physical observation**, then share the generated report from Downloads. The minimum may be faint; choose “Uncertain / too dim to judge” if you cannot tell.

The app reports the device-open, configuration-read and output return codes. An accepted output request alone will not be counted as working lighting. If macOS rejects the output report, the test stops instead of trying other reports.

This is still an experiment: output support is not yet confirmed, and the normal installer remains unchanged. Thanks again for helping validate it safely!
