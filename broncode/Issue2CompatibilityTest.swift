// Standalone, opt-in hardware research tool. Never installs the production app.
import AppKit
import Foundation
import Darwin

struct Issue2TestFlow {
    enum Action: String { case probe, pulse, off }
    private(set) var busy = false
    private(set) var validated = false
    var confirmed = false
    func allows(_ action: Action) -> Bool { !busy && (action == .probe || (validated && confirmed)) }
    mutating func begin(_ action: Action) -> Bool {
        guard allows(action) else { return false }
        busy = true
        confirmed = false
        if action == .probe { validated = false }
        return true
    }
    @discardableResult
    mutating func finish(_ action: Action, status: Int32, output: String) -> Bool {
        busy = false
        confirmed = false
        let marker: String
        switch action {
        case .probe: marker = "ECZ_ISSUE2_PROBE_OK"
        case .pulse: marker = "ECZ_ISSUE2_PULSE_ACCEPTED"
        case .off: marker = "ECZ_ISSUE2_OFF_ACCEPTED"
        }
        let accepted = status == 0 && output.components(separatedBy: .newlines).contains(marker)
        if action == .probe { validated = accepted }
        else if !accepted { validated = false }
        return accepted
    }
}

final class Issue2CompatibilityTest: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private let helperURL: URL
    private let model: String
    private let reportFolder: URL
    private let controllersAreRunning: () -> Bool
    private var reportURL: URL?
    private var reportHeader = ""
    private var transcript = ""
    private var flow = Issue2TestFlow()
    private var active: Process?
    private var watchdog: DispatchWorkItem?
    private var timedOut = false
    private var window: NSWindow!
    private let probeButton = NSButton(title: "1. Run read-only probe", target: nil, action: nil)
    private let consent = NSButton(checkboxWithTitle: "I reviewed the matching probe (off=0, min=32, max=512) and agree to a short LED test.", target: nil, action: nil)
    private let pulseButton = NSButton(title: "2. Test minimum light for 2 seconds", target: nil, action: nil)
    private let offButton = NSButton(title: "Send Off only", target: nil, action: nil)
    private let copyButton = NSButton(title: "Copy report", target: nil, action: nil)
    private let showButton = NSButton(title: "Show report in Finder", target: nil, action: nil)
    private let closeButton = NSButton(title: "Close", target: nil, action: nil)
    private let status = NSTextField(wrappingLabelWithString: "")
    private let saved = NSTextField(wrappingLabelWithString: "")
    private let log = NSTextView()
    private let observation = NSPopUpButton()
    private let spinner = NSProgressIndicator()
    private var isTargetModel: Bool { model == "MacBookPro15,4" }

    init(helperURL: URL? = nil, model: String? = nil, reportFolder: URL? = nil,
         controllersAreRunning: @escaping () -> Bool = {
             ["nl.easycompzeeland.KeyboardLight", "nl.easycompzeeland.KeyboardLight.Beta7Test"]
                 .contains { !NSRunningApplication.runningApplications(withBundleIdentifier: $0).isEmpty }
         }) {
        self.helperURL = helperURL ?? Bundle.main.executableURL!.deletingLastPathComponent().appendingPathComponent("Issue2Helper")
        self.model = model ?? Self.readModel()
        self.reportFolder = reportFolder ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads")
        self.controllersAreRunning = controllersAreRunning
        super.init()
    }
    private static func readModel() -> String {
        var length = 0
        guard sysctlbyname("hw.model", nil, &length, nil, 0) == 0, length > 0, length < 256 else { return "Unknown" }
        var bytes = [CChar](repeating: 0, count: length)
        guard sysctlbyname("hw.model", &bytes, &length, nil, 0) == 0 else { return "Unknown" }
        return String(cString: bytes)
    }
    private func row(_ views: [NSView]) -> NSStackView {
        let result = NSStackView(views: views)
        result.orientation = .horizontal
        result.alignment = .centerY
        result.spacing = 12
        return result
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 900, height: 720),
            styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "EasyComp Keyboard Light — Issue #2 compatibility test"
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        let title = NSTextField(labelWithString: "MacBookPro15,4 — controlled Butterfly test")
        title.font = .boldSystemFont(ofSize: 21)
        let intro = NSTextField(wrappingLabelWithString:
            "This is an experiment, not an installer. Close other keyboard-light controllers first.\nThe probe is read-only. Output report support is unproven; only the confirmed minimum and off values can be tested. The pulse ends with an off request; prior brightness is not restored.")
        intro.font = .systemFont(ofSize: 13)
        for (button, action) in [(probeButton, #selector(probe)), (consent, #selector(confirmProbe)),
                                (pulseButton, #selector(pulse)), (offButton, #selector(sendOff)),
                                (copyButton, #selector(copyReport)), (showButton, #selector(showReport)),
                                (closeButton, #selector(closeTool))] {
            button.target = self
            button.action = action
            if button !== consent { button.bezelStyle = .rounded }
        }
        spinner.style = .spinning
        spinner.controlSize = .small
        spinner.isDisplayedWhenStopped = false
        spinner.setContentHuggingPriority(.required, for: .horizontal)
        status.font = .systemFont(ofSize: 13, weight: .semibold)
        saved.font = .systemFont(ofSize: 11)
        saved.textColor = .secondaryLabelColor
        let scroll = NSScrollView()
        scroll.borderType = .bezelBorder
        scroll.hasVerticalScroller = true
        log.isEditable = false
        log.isSelectable = true
        log.isVerticallyResizable = true
        log.isHorizontallyResizable = false
        log.autoresizingMask = [.width]
        log.textContainer?.widthTracksTextView = true
        log.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        scroll.documentView = log
        observation.addItems(withTitles: ["Not checked", "Yes — minimum light appeared, then went off", "No visible change", "Light stayed on or behaved unexpectedly", "Uncertain / too dim to judge"])
        observation.target = self
        observation.action = #selector(recordObservation)
        let stack = NSStackView(views: [title, intro, probeButton, consent,
            row([pulseButton, offButton, spinner]), status, scroll,
            row([NSTextField(labelWithString: "Physical observation:"), observation]),
            row([copyButton, showButton, closeButton]), saved])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        window.contentView!.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: window.contentView!.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: window.contentView!.bottomAnchor, constant: -20),
            scroll.widthAnchor.constraint(equalTo: stack.widthAnchor),
            scroll.heightAnchor.constraint(equalToConstant: 180),
            intro.widthAnchor.constraint(equalTo: stack.widthAnchor),
            status.widthAnchor.constraint(equalTo: stack.widthAnchor),
            saved.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
        #if arch(x86_64)
        let architecture = "x86_64"
        #else
        let architecture = "arm64"
        #endif
        let build = Bundle.main.url(forResource: "BUILD-INFO", withExtension: "txt")
            .flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? "Development fixture/build identifier unavailable."
        reportHeader = """
        EasyComp Keyboard Light — Issue #2 isolated compatibility test
        Model: \(model)
        macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)
        Architecture: \(architecture)
        No installation, administrator access, network upload, serial numbers or keystroke capture.
        Build provenance:
        \(build)
        """
        append("Read-only probe required. LED controls are locked until a successful probe is reviewed and confirmed.\n")
        status.stringValue = isTargetModel ? "Start with the read-only probe. No LED command has been sent." : "This hardware test is restricted to MacBookPro15,4. Hardware actions are disabled."
        refresh()
        #if !ECZ_TESTS
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        #endif
    }
    private var reportText: String {
        reportHeader + "\n\n" + transcript + "\nPhysical observation (user supplied): " + (observation.titleOfSelectedItem ?? "Not checked") + "\n"
    }
    private func append(_ text: String) {
        transcript += text
        log.string = transcript
        log.scrollToEndOfDocument(nil)
        saveReport()
    }
    private func saveReport() {
        do {
            if reportURL == nil {
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.dateFormat = "yyyyMMdd-HHmmss"
                let name = "ECZ-KeyboardLight-Issue2-Compatibility-\(formatter.string(from: Date()))-\(ProcessInfo.processInfo.processIdentifier).txt"
                try FileManager.default.createDirectory(at: reportFolder, withIntermediateDirectories: true)
                reportURL = reportFolder.appendingPathComponent(name)
            }
            try Data(reportText.utf8).write(to: reportURL!, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: reportURL!.path)
            saved.stringValue = "Local report: \(reportURL!.lastPathComponent). Review before sharing; nothing is uploaded."
        } catch {
            saved.stringValue = "Could not save the local report. Use Copy report to preserve the results."
            reportURL = nil
        }
    }
    private func refresh() {
        probeButton.isEnabled = isTargetModel && flow.allows(.probe)
        consent.isEnabled = isTargetModel && flow.validated && !flow.busy
        consent.state = flow.confirmed ? .on : .off
        pulseButton.isEnabled = isTargetModel && flow.allows(.pulse)
        offButton.isEnabled = isTargetModel && flow.allows(.off)
        closeButton.isEnabled = !flow.busy
        observation.isEnabled = !flow.busy
        copyButton.isEnabled = !flow.busy
        showButton.isEnabled = !flow.busy && reportURL != nil
        if flow.busy { spinner.startAnimation(nil) } else { spinner.stopAnimation(nil) }
    }
    @objc private func confirmProbe() {
        flow.confirmed = flow.validated && consent.state == .on
        refresh()
    }
    @objc private func probe() { run(.probe) }
    @objc private func pulse() { run(.pulse) }
    @objc private func sendOff() { run(.off) }
    private func run(_ action: Issue2TestFlow.Action) {
        guard isTargetModel && flow.allows(action) else { return }
        guard !controllersAreRunning() else {
            status.stringValue = "Close the other keyboard-light controller before running this test. Nothing was started."
            return
        }
        guard flow.begin(action) else { return }
        if action == .pulse { observation.selectItem(at: 0) }
        timedOut = false
        append("\nAction: \(action.rawValue). \(action == .probe ? "Read-only." : "User confirmed the validated configuration and explicitly requested this LED experiment.")\n")
        status.stringValue = action == .probe ? "Reading configuration. No LED writes." : "Running the requested test. Wait for the off attempt and completion."
        refresh()
        let process = Process()
        process.executableURL = helperURL
        process.arguments = action == .probe ? ["probe"] : [action.rawValue, "--confirm-probe=0:32:512"]
        process.standardInput = FileHandle.nullDevice
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        active = process
        do {
            try process.run()
            let timeout = DispatchWorkItem { [weak self] in
                guard let self = self, self.active === process, process.isRunning else { return }
                self.timedOut = true
                self.append("Helper deadline exceeded. Requesting termination; off cleanup cannot be guaranteed.\n")
                process.terminate()
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    if process.isRunning { kill(process.processIdentifier, SIGKILL) }
                }
            }
            watchdog = timeout
            DispatchQueue.main.asyncAfter(deadline: .now() + 12, execute: timeout)
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                let output = String(decoding: data, as: UTF8.self)
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.watchdog?.cancel()
                    self.active = nil
                    let code: Int32 = self.timedOut ? 124 : process.terminationStatus
                    self.append(output + "Helper exit: \(code)\n")
                    let accepted = self.flow.finish(action, status: code, output: output)
                    if code != 0 {
                        self.status.stringValue = "Test stopped (code \(code)). No compatibility claim. Review the report; run a fresh probe before any further LED request."
                    } else if !accepted {
                        self.status.stringValue = "Expected success marker missing. LED controls remain locked; review the report."
                    } else if action == .probe && self.flow.validated {
                        self.status.stringValue = "Probe matches off=0, min=32, max=512. Read the report, then tick the confirmation to unlock the test."
                    } else {
                        self.status.stringValue = "HID requests were accepted. This does not prove visible light operation: record what the keyboard actually did below."
                    }
                    self.refresh()
                }
            }
        } catch {
            active = nil
            flow.finish(action, status: 255, output: "")
            append("Could not start the bundled helper. No HID action was started.\n")
            status.stringValue = "Could not start the helper. LED controls remain locked."
            refresh()
        }
    }
    @objc private func recordObservation() { saveReport() }
    @objc private func copyReport() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(reportText, forType: .string)
    }
    @objc private func showReport() {
        if let url = reportURL { NSWorkspace.shared.activateFileViewerSelecting([url]) }
    }
    @objc private func closeTool() { NSApp.terminate(nil) }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    func windowShouldClose(_ sender: NSWindow) -> Bool { !flow.busy }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply { flow.busy ? .terminateCancel : .terminateNow }
}

#if !ECZ_TESTS
let app = NSApplication.shared
let delegate = Issue2CompatibilityTest()
app.delegate = delegate
app.run()
#endif
