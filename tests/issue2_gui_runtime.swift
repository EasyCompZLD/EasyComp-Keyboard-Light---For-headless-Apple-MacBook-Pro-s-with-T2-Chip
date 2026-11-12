// Real GUI and state policy with a harmless executable fixture, never a HID helper.
func checkIssue2(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() { fatalError(message) }
}
var gate = Issue2TestFlow()
checkIssue2(!gate.allows(.pulse) && !gate.begin(.off), "No writes before probe")
checkIssue2(gate.begin(.probe) && !gate.begin(.probe), "One action at a time")
checkIssue2(!gate.finish(.probe, status: 0, output: "not ECZ_ISSUE2_PROBE_OK"), "Exact marker required")
checkIssue2(gate.begin(.probe), "Retry probe")
checkIssue2(!gate.finish(.probe, status: 7, output: "ECZ_ISSUE2_PROBE_OK"), "Exit status must succeed too")
checkIssue2(gate.begin(.probe), "Retry valid probe")
checkIssue2(gate.finish(.probe, status: 0, output: "ECZ_ISSUE2_PROBE_OK\n"), "Valid probe")
checkIssue2(!gate.allows(.pulse), "Probe is not consent")
gate.confirmed = true
checkIssue2(gate.begin(.pulse) && !gate.confirmed, "Consume explicit consent")
checkIssue2(!gate.finish(.pulse, status: 0, output: "unrelated"), "Pulse success marker required")
checkIssue2(!gate.validated && !gate.allows(.off), "Failed test requires fresh probe")

extension Issue2CompatibilityTest {
    func verifyReadOnlyHostGate() {
        probe()
        checkIssue2(!flow.busy && !probeButton.isEnabled && !pulseButton.isEnabled, "Unsupported host cannot run actions")
    }
    func verifyGUIFixture(helper: URL, directory: URL) {
        window.contentView!.layoutSubtreeIfNeeded()
        let actionsFile = directory.appendingPathComponent("actions")
        func actions() -> [String] { ((try? String(contentsOf: actionsFile, encoding: .utf8)) ?? "").split(separator: "\n").map(String.init) }
        func wait() {
            let deadline = Date().addingTimeInterval(5)
            while flow.busy && Date() < deadline { RunLoop.main.run(until: Date().addingTimeInterval(0.01)) }
            checkIssue2(!flow.busy, "Fixture action must finish")
        }
        checkIssue2(!consent.isEnabled && !pulseButton.isEnabled && !offButton.isEnabled, "LED controls initially locked")
        pulse()
        checkIssue2(actions().isEmpty, "Unconfirmed pulse must not start even a fixture")
        probe()
        checkIssue2(flow.busy && !probeButton.isEnabled && !closeButton.isEnabled, "Busy action lock")
        checkIssue2(!windowShouldClose(window) && applicationShouldTerminate(NSApp) == .terminateCancel, "Do not interrupt a running test by closing")
        pulse()
        wait()
        checkIssue2(flow.validated && !flow.confirmed && consent.isEnabled && !pulseButton.isEnabled, "Review before write")
        checkIssue2(actions() == ["probe"], "Probe ran without writes")
        consent.state = .on
        confirmProbe()
        checkIssue2(pulseButton.isEnabled && offButton.isEnabled, "Explicit confirmation unlocks test")
        pulse()
        wait()
        checkIssue2(flow.validated && !flow.confirmed && !pulseButton.isEnabled, "No automatic second pulse")
        checkIssue2(actions() == ["probe", "pulse"], "Exactly one user-requested pulse")
        sendOff()
        checkIssue2(actions() == ["probe", "pulse"], "Off also requires explicit consent")
        consent.state = .on
        confirmProbe()
        sendOff()
        wait()
        checkIssue2(actions() == ["probe", "pulse", "off"], "Explicit off action")
        observation.selectItem(at: 1)
        recordObservation()
        checkIssue2(reportURL != nil && reportURL!.deletingLastPathComponent().path == reportFolder.path, "Local fixture report only")
        let report = try! String(contentsOf: reportURL!, encoding: .utf8)
        checkIssue2(report.contains("Physical observation (user supplied): Yes") && report.contains("ECZ_ISSUE2_PULSE_ACCEPTED"), "Keep API acceptance and physical observation separate")
        checkIssue2(!report.contains(FileManager.default.homeDirectoryForCurrentUser.path), "No home path in report")
        try! Data("#!/bin/bash\nprintf 'configuration not validated\\n'\nexit 0\n".utf8).write(to: helper)
        probe()
        wait()
        checkIssue2(!flow.validated && !consent.isEnabled && !pulseButton.isEnabled && !offButton.isEnabled, "Missing marker locks GUI")
    }
}
let application = NSApplication.shared
let directory = URL(fileURLWithPath: ProcessInfo.processInfo.environment["ECZ_ISSUE2_FIXTURE"]!)
let helper = directory.appendingPathComponent("fixture-helper")
let script = """
#!/bin/bash
printf '%s\\n' "$1" >> "$ECZ_ISSUE2_FIXTURE/actions"
case "$1" in
  probe) printf 'Configuration: off=0 min=32 max=512\\nECZ_ISSUE2_PROBE_OK\\n' ;;
  pulse) test "$2" = '--confirm-probe=0:32:512' || exit 2; printf 'ECZ_ISSUE2_PULSE_ACCEPTED\\n' ;;
  off) test "$2" = '--confirm-probe=0:32:512' || exit 2; printf 'ECZ_ISSUE2_OFF_ACCEPTED\\n' ;;
  *) exit 2 ;;
esac
"""
try! Data(script.utf8).write(to: helper)
try! FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: helper.path)
let unsupported = Issue2CompatibilityTest(helperURL: helper, model: "MacBookPro16,1", reportFolder: directory.appendingPathComponent("unsupported"), controllersAreRunning: { false })
unsupported.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
unsupported.verifyReadOnlyHostGate()
let fixture = Issue2CompatibilityTest(helperURL: helper, model: "MacBookPro15,4", reportFolder: directory.appendingPathComponent("reports"), controllersAreRunning: { false })
fixture.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
fixture.verifyGUIFixture(helper: helper, directory: directory)
print("Issue2 GUI fixture passed; no hardware helper launched.")
