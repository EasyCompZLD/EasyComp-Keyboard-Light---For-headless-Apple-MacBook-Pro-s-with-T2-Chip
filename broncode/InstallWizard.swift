// EasyComp Keyboard Light — native multilingual setup wizard v1.2.0.
// The eight language bundles ship with the wizard; no online translation service.
import AppKit
import Foundation

private let issuePage = "https://github.com/EasyCompZLD/EasyComp-Keyboard-Light---For-headless-Apple-MacBook-Pro-s-with-T2-Chip/issues/new?template=installation_failure.md"
private let versionText = "1.2.0"

private final class WizardLanguage {
    static let supported: [(code: String, nativeName: String)] = [
        ("en", "English"), ("nl", "Nederlands"), ("de", "Deutsch"),
        ("fr", "Français"), ("es", "Español"), ("it", "Italiano"),
        ("pt", "Português"), ("pl", "Polski")
    ]
    var code: String

    init(requested: String?) {
        if let requested = requested?.lowercased(),
           Self.supported.contains(where: { $0.code == requested }) {
            code = requested
            return
        }
        code = "en"
        for preferred in Locale.preferredLanguages {
            let candidate = String(preferred.lowercased().split(separator: "-").first ?? "en")
            if Self.supported.contains(where: { $0.code == candidate }) {
                code = candidate
                break
            }
        }
    }
    func text(_ key: String) -> String {
        for lang in [code, "en"] {
            guard let path = Bundle.main.path(forResource: lang, ofType: "lproj"),
                  let translations = Bundle(path: path) else { continue }
            let found = translations.localizedString(forKey: "wizard." + key, value: nil, table: "Localizable")
            if found != "wizard." + key { return found }
        }
        return key
    }
    func format(_ key: String, _ args: CVarArg...) -> String {
        String(format: text(key), arguments: args)
    }
}

enum SetupOperation { case install, report, build, uninstall }

final class InstallationWizard: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private let project: URL
    private let language: WizardLanguage
    private var explicitLanguage: Bool
    private var window: NSWindow!
    private var subtitleLabel: NSTextField!
    private var intro: NSTextField!
    private var status: NSTextField!
    private var details: NSTextView!
    private var progress: NSProgressIndicator!
    private var installButton: NSButton!
    private var reportButton: NSButton!
    private var copyButton: NSButton!
    private var issuesButton: NSButton!
    private var closeButton: NSButton!
    private var languageLabel: NSTextField!
    private var languagePopup: NSPopUpButton!
    private var openButton: NSButton!
    private var removeButton: NSButton!
    private var buildButton: NSButton!
    private var detailsButton: NSButton!
    private var detailsScroll: NSScrollView!
    private var overview: NSTextField!
    private var welcomeAlert: NSAlert?
    private var preparingControllerStop = false
    private var running: Process?
    private var fullLog = ""
    private var reportURL: URL?
    private var modelName = "Unknown"
    private var architecture = "Unknown"
    private var startedAt = Date()
    private var statusKey = "ready"
    private var lastExitCode: Int32 = 0

    init(projectDirectory: String, languageCode: String?) {
        project = URL(fileURLWithPath: projectDirectory, isDirectory: true)
        language = WizardLanguage(requested: languageCode)
        explicitLanguage = languageCode != nil && languageCode != "auto"
        super.init()
    }
    private func T(_ key: String) -> String { language.text(key) }
    private func F(_ key: String, _ args: CVarArg...) -> String {
        String(format: language.text(key), arguments: args)
    }

    private func label(_ title: String, frame: NSRect, size: CGFloat, bold: Bool = false) -> NSTextField {
        let field = NSTextField(labelWithString: title)
        field.frame = frame
        field.font = bold ? NSFont.boldSystemFont(ofSize: size) : NSFont.systemFont(ofSize: size)
        field.lineBreakMode = .byWordWrapping
        field.maximumNumberOfLines = 0
        return field
    }
    private func button(_ title: String, frame: NSRect, action: Selector) -> NSButton {
        let result = NSButton(title: title, target: self, action: action)
        result.frame = frame
        result.bezelStyle = .rounded
        return result
    }
    private func tool(_ command: String, arguments: [String]) -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: command)
        task.arguments = arguments
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            task.waitUntilExit()
            return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unknown"
        } catch { return "Unknown" }
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        modelName = tool("/usr/sbin/sysctl", arguments: ["-n", "hw.model"])
        architecture = tool("/usr/bin/uname", arguments: ["-m"])
        NSApp.setActivationPolicy(.regular)
        let size = NSSize(width: 860, height: 575)
        window = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                          styleMask: [.titled, .closable, .miniaturizable],
                          backing: .buffered, defer: false)
        window.delegate = self
        window.center()
        window.isReleasedWhenClosed = false
        let content = NSView(frame: NSRect(origin: .zero, size: size))
        window.contentView = content
        content.addSubview(label("EasyComp Keyboard Light", frame: NSRect(x: 26, y: 525, width: 515, height: 34), size: 25, bold: true))
        subtitleLabel = label("", frame: NSRect(x: 28, y: 499, width: 790, height: 22), size: 12)
        subtitleLabel.textColor = .secondaryLabelColor
        content.addSubview(subtitleLabel)
        languageLabel = label("", frame: NSRect(x: 568, y: 537, width: 85, height: 24), size: 12)
        content.addSubview(languageLabel)
        languagePopup = NSPopUpButton(frame: NSRect(x: 655, y: 531, width: 177, height: 30), pullsDown: false)
        for (code, nativeName) in WizardLanguage.supported {
            languagePopup.addItem(withTitle: nativeName)
            languagePopup.lastItem?.representedObject = code
            if code == language.code { languagePopup.selectItem(at: languagePopup.numberOfItems - 1) }
        }
        languagePopup.target = self
        languagePopup.action = #selector(selectLanguage(_:))
        content.addSubview(languagePopup)

        intro = label("", frame: NSRect(x: 28, y: 428, width: 800, height: 67), size: 13)
        content.addSubview(intro)
        status = label("", frame: NSRect(x: 28, y: 396, width: 800, height: 30), size: 13, bold: true)
        content.addSubview(status)
        progress = NSProgressIndicator(frame: NSRect(x: 28, y: 370, width: 800, height: 13))
        progress.style = .bar
        progress.isIndeterminate = true
        progress.isDisplayedWhenStopped = false
        content.addSubview(progress)

        let scroll = NSScrollView(frame: NSRect(x: 28, y: 130, width: 800, height: 225))
        scroll.borderType = .bezelBorder
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        details = NSTextView(frame: NSRect(x: 0, y: 0, width: 786, height: 270))
        details.isEditable = false
        details.isSelectable = true
        details.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        scroll.documentView = details
        detailsScroll = scroll
        detailsScroll.isHidden = true
        content.addSubview(scroll)
        overview = label("", frame: NSRect(x: 40, y: 155, width: 775, height: 180), size: 15)
        overview.textColor = .secondaryLabelColor
        content.addSubview(overview)
        openButton = button("", frame: NSRect(x: 26, y: 79, width: 170, height: 34), action: #selector(openInstalledApp))
        removeButton = button("", frame: NSRect(x: 208, y: 79, width: 170, height: 34), action: #selector(uninstall))
        buildButton = button("", frame: NSRect(x: 390, y: 79, width: 200, height: 34), action: #selector(checkBuild))
        detailsButton = button("", frame: NSRect(x: 602, y: 79, width: 226, height: 34), action: #selector(toggleDetails))
        buildButton.isHidden = true
        for control in [openButton, removeButton, buildButton, detailsButton] { content.addSubview(control!) }

        installButton = button("", frame: NSRect(x: 26, y: 22, width: 125, height: 34), action: #selector(install))
        installButton.keyEquivalent = "\r"
        content.addSubview(installButton)
        reportButton = button("", frame: NSRect(x: 163, y: 22, width: 176, height: 34), action: #selector(makeReport))
        content.addSubview(reportButton)
        copyButton = button("", frame: NSRect(x: 351, y: 22, width: 157, height: 34), action: #selector(copyReport))
        copyButton.isEnabled = false
        content.addSubview(copyButton)
        issuesButton = button("", frame: NSRect(x: 520, y: 22, width: 171, height: 34), action: #selector(openIssues))
        content.addSubview(issuesButton)
        closeButton = button("", frame: NSRect(x: 704, y: 22, width: 124, height: 34), action: #selector(closeWizard))
        content.addSubview(closeButton)
        refreshTranslations()
        #if !ECZ_TESTS
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        #endif
        // Bootstrap declares success only after the native window has been shown.
        if CommandLine.arguments.count > 2, !CommandLine.arguments[1].hasPrefix("-") {
            let readyMarker = URL(fileURLWithPath: CommandLine.arguments[2])
            try? Data("window-ready".utf8).write(to: readyMarker, options: .atomic)
        }
        #if !ECZ_TESTS
        DispatchQueue.main.async { [weak self] in self?.chooseInitialLanguage() }
        #endif
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    private func refreshTranslations() {
        window.title = "EasyComp Keyboard Light — " + T("title")
        subtitleLabel.stringValue = F("subtitle", versionText)
        intro.stringValue = F("intro", modelName, architecture)
        languageLabel.stringValue = T("languageLabel") + ":"
        let installed = FileManager.default.fileExists(atPath: installedApp.path)
        installButton.title = T(installed ? "update" : "install")
        openButton.title = T("openApp")
        removeButton.title = T("uninstall")
        buildButton.title = T("checkBuild")
        detailsButton.title = T(detailsScroll.isHidden ? "showDetails" : "hideDetails")
        overview.stringValue = T("overview")
        if running == nil && !preparingControllerStop {
            openButton.isEnabled = installed
            removeButton.isEnabled = installed
        }
        welcomeAlert?.messageText = T("chooseLanguage")
        welcomeAlert?.informativeText = T("languageFirst")
        welcomeAlert?.buttons.first?.title = T("continue")
        welcomeAlert?.buttons.last?.title = T("cancel")
        reportButton.title = T("report")
        copyButton.title = T("copy")
        issuesButton.title = T("issues")
        closeButton.title = T("close")
        if fullLog.isEmpty { details.string = T("details") }
        switch statusKey {
        case "failedStatus": status.stringValue = F("failedStatus", lastExitCode)
        default: status.stringValue = T(statusKey)
        }
    }
    @objc private func selectLanguage(_ sender: NSPopUpButton) {
        guard let selected = sender.selectedItem?.representedObject as? String,
              WizardLanguage.supported.contains(where: { $0.code == selected }) else { return }
        language.code = selected
        explicitLanguage = true
        refreshTranslations()
    }

    private var installedApp: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications/EasyComp Keyboard Light.app")
    }
    private var busy: Bool { running != nil || preparingControllerStop }

    private func languageChooser() -> NSAlert {
        let alert = NSAlert()
        alert.messageText = T("chooseLanguage")
        alert.informativeText = T("languageFirst")
        let popup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 280, height: 32))
        for (code, name) in WizardLanguage.supported {
            popup.addItem(withTitle: name)
            popup.lastItem?.representedObject = code
            if code == language.code { popup.selectItem(at: popup.numberOfItems - 1) }
        }
        popup.target = self
        popup.action = #selector(selectWelcomeLanguage(_:))
        alert.accessoryView = popup
        alert.addButton(withTitle: T("continue"))
        alert.addButton(withTitle: T("cancel"))
        return alert
    }
    private func chooseInitialLanguage() {
        let alert = languageChooser()
        welcomeAlert = alert
        let answer = alert.runModal()
        welcomeAlert = nil
        guard answer == .alertFirstButtonReturn else { NSApp.terminate(nil); return }
        explicitLanguage = true
    }
    @objc private func selectWelcomeLanguage(_ sender: NSPopUpButton) {
        selectLanguage(sender)
        if let selected = sender.selectedItem?.representedObject as? String,
           let item = languagePopup.itemArray.first(where: { ($0.representedObject as? String) == selected }) {
            languagePopup.select(item)
        }
    }
    @objc private func toggleDetails() {
        detailsScroll.isHidden.toggle()
        overview.isHidden = !detailsScroll.isHidden
        buildButton.isHidden = detailsScroll.isHidden
        refreshTranslations()
    }
    private func setBusy(_ value: Bool) {
        for button in [installButton, reportButton, closeButton, buildButton, removeButton, openButton] {
            button?.isEnabled = !value
        }
        languagePopup.isEnabled = !value
        copyButton.isEnabled = !value && reportURL != nil
        if !value { refreshTranslations() }
    }
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if busy { showError(T("busy")); return false }
        return true
    }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if busy { showError(T("busy")); return .terminateCancel }
        return .terminateNow
    }

    private func start(_ script: String, arguments: [String], operation: SetupOperation) {
        if busy { return }
        let file = project.appendingPathComponent(script)
        guard FileManager.default.fileExists(atPath: file.path) else {
            showError(F("missing", script))
            return
        }
        fullLog = ""
        reportURL = nil
        details.string = ""
        startedAt = Date()
        setBusy(true)
        switch operation {
        case .install: statusKey = "installing"
        case .report: statusKey = "diagnosing"
        case .build: statusKey = "checkingBuild"
        case .uninstall: statusKey = "uninstalling"
        }
        refreshTranslations()
        progress.startAnimation(nil)
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/bash")
        p.arguments = [file.path] + arguments
        p.currentDirectoryURL = project
        p.standardInput = FileHandle.nullDevice
        // Pass selected language to CLI utilities and, on successful installation, to the app preference.
        var environment = ProcessInfo.processInfo.environment
        let originalPath = environment["PATH"] ?? ""
        environment["PATH"] = "/usr/bin:/bin:/usr/sbin:/sbin:" + originalPath
        environment.removeValue(forKey: "SDKROOT")
        environment.removeValue(forKey: "TOOLCHAINS")
        // The installer also scans known toolchain locations itself. A stale
        // DEVELOPER_DIR from the Finder session will be repaired there.
        if explicitLanguage { environment["ECZ_INSTALL_LANGUAGE"] = language.code }
        else { environment.removeValue(forKey: "ECZ_INSTALL_LANGUAGE") }
        p.environment = environment
        let output = Pipe()
        p.standardOutput = output
        p.standardError = output
        running = p
        do {
            try p.run()
            // Drain the pipe on one worker. Final state is delivered only after
            // every output chunk, so report discovery cannot race process exit.
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                var pendingBytes = Data()
                func deliver(_ data: Data) {
                    let chunk = String(decoding: data, as: UTF8.self)
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        self.fullLog += chunk
                        self.details.string += chunk
                        self.details.scrollToEndOfDocument(nil)
                        if operation == .install {
                            for index in 1...4 where self.fullLog.contains("ECZ_STEP:\(index)") {
                                self.statusKey = "step\(index)"
                            }
                        }
                        self.refreshTranslations()
                    }
                }
                while true {
                    let data = output.fileHandleForReading.availableData
                    if data.isEmpty { break }
                    pendingBytes.append(data)
                    if let newline = pendingBytes.lastIndex(of: 10) {
                        let end = pendingBytes.index(after: newline)
                        deliver(Data(pendingBytes[..<end]))
                        pendingBytes.removeSubrange(..<end)
                    }
                }
                if !pendingBytes.isEmpty { deliver(pendingBytes) }
                p.waitUntilExit()
                DispatchQueue.main.async { [weak self] in
                    self?.didFinish(statusCode: p.terminationStatus, operation: operation)
                }
            }
        } catch {
            running = nil
            progress.stopAnimation(nil)
            setBusy(false)
            showError(F("startError", error.localizedDescription))
        }
    }
    private func discoverReport() -> URL? {
        let marker = "Saved report: "
        for line in fullLog.components(separatedBy: .newlines).reversed() where line.hasPrefix(marker) {
            let path = String(line.dropFirst(marker.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            if FileManager.default.fileExists(atPath: path) { return URL(fileURLWithPath: path) }
        }
        let folder = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads")
        let entries = (try? FileManager.default.contentsOfDirectory(at: folder,
                               includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        return entries.filter { $0.lastPathComponent.hasPrefix("EasyComp-Keyboard-Light-Report-") &&
                                $0.pathExtension == "txt" &&
                                ((try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast) >= startedAt.addingTimeInterval(-5) }
                      .max { a,b in
                          ((try? a.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast) <
                          ((try? b.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast)
                      }
    }
    private func didFinish(statusCode: Int32, operation: SetupOperation) {
        running = nil
        progress.stopAnimation(nil)
        reportURL = (operation == .report || (operation == .install && statusCode != 0))
            ? discoverReport() : nil
        setBusy(false)
        copyButton.isEnabled = reportURL != nil
        if statusCode == 0 {
            switch operation {
            case .install: statusKey = "done"
            case .report: statusKey = "reportDone"
            case .build: statusKey = "buildDone"
            case .uninstall: statusKey = "uninstallDone"
            }
            if operation == .report, let url = reportURL,
               let text = try? String(contentsOf: url, encoding: .utf8) {
                // Explicit diagnosis reveals the report for review before copying.
                details.string = text
                detailsScroll.isHidden = false
                overview.isHidden = true
                buildButton.isHidden = false
            }
            refreshTranslations()
            if operation == .install {
                let message = NSAlert()
                message.messageText = T("doneTitle")
                message.informativeText = T("doneBody")
                message.addButton(withTitle: "OK")
                message.runModal()
            }
        } else {
            statusKey = "failedStatus"
            lastExitCode = statusCode
            refreshTranslations()
            let message = NSAlert()
            message.alertStyle = .warning
            message.messageText = T(operation == .install ? "failedTitle" : "actionFailed")
            message.informativeText = T(operation == .install ? "failedBody" : "actionFailedBody")
            message.addButton(withTitle: "OK")
            message.runModal()
        }
    }
    private func showError(_ description: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "EasyComp Keyboard Light"
        alert.informativeText = description
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    @objc private func install() {
        let supported = modelName == "MacBookPro16,1" || modelName == "MacBookPro15,4"
        let potential = modelName.hasPrefix("MacBookPro15,") || modelName.hasPrefix("MacBookPro16,") ||
                        modelName.hasPrefix("MacBookAir8,") || modelName == "MacBookAir9,1"
        if architecture != "x86_64" || !potential {
            showError(F("unsupported", modelName))
            return
        }
        if !supported {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = F("betaTitle", modelName)
            alert.informativeText = T("betaBody")
            alert.addButton(withTitle: T("yes"))
            alert.addButton(withTitle: T("cancel"))
            if alert.runModal() != .alertFirstButtonReturn { return }
        }
        prepareControllerStop(operation: .install, arguments: supported ? [] : ["--experimental"])
    }
    @objc private func makeReport() { start("Probleemrapport.command", arguments: [], operation: .report) }
    @objc private func checkBuild() { start("Controleer-build.command", arguments: [], operation: .build) }
    @objc private func openInstalledApp() {
        guard !busy else { return }
        NSWorkspace.shared.openApplication(at: installedApp, configuration: NSWorkspace.OpenConfiguration()) { [weak self] _, error in
            if let error = error { DispatchQueue.main.async { self?.showError(error.localizedDescription) } }
        }
    }
    private func uninstallConfirmation() -> NSAlert {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = T("uninstallTitle")
        alert.informativeText = T("uninstallBody")
        alert.addButton(withTitle: T("uninstall"))
        alert.addButton(withTitle: T("cancel"))
        alert.buttons.first?.hasDestructiveAction = true
        alert.buttons.first?.keyEquivalent = ""
        alert.buttons.last?.keyEquivalent = "\r"
        return alert
    }
    @objc private func uninstall() {
        guard !busy else { return }
        guard uninstallConfirmation().runModal() == .alertFirstButtonReturn else { return }
        prepareControllerStop(operation: .uninstall, arguments: [])
    }
    private func prepareControllerStop(operation: SetupOperation, arguments: [String]) {
        guard !busy else { return }
        preparingControllerStop = true
        setBusy(true)
        statusKey = operation == .install ? "installing" : "uninstalling"
        refreshTranslations()
        for app in NSRunningApplication.runningApplications(withBundleIdentifier: "nl.easycompzeeland.KeyboardLight") { app.terminate() }
        waitForControllerExit(attempt: 0, operation: operation, arguments: arguments)
    }
    private func waitForControllerExit(attempt: Int, operation: SetupOperation, arguments: [String]) {
        let apps = NSRunningApplication.runningApplications(withBundleIdentifier: "nl.easycompzeeland.KeyboardLight")
        if apps.isEmpty {
            preparingControllerStop = false
            start(operation == .install ? "Installeer.command" : "Verwijder.command", arguments: arguments, operation: operation)
        } else if attempt >= 50 {
            preparingControllerStop = false
            setBusy(false)
            statusKey = "ready"
            refreshTranslations()
            showError(T("quitFirst"))
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.waitForControllerExit(attempt: attempt + 1, operation: operation, arguments: arguments)
            }
        }
    }
    @objc private func copyReport() {
        guard let url = reportURL, let contents = try? String(contentsOf: url, encoding: .utf8) else {
            showError(T("reportMissing"))
            return
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(contents, forType: .string)
        status.stringValue = T("copied")
    }
    @objc private func openIssues() {
        if let url = URL(string: issuePage) { NSWorkspace.shared.open(url) }
    }
    @objc private func closeWizard() {
        if busy { showError(T("busy")); return }
        NSApp.terminate(nil)
    }
}

#if !ECZ_TESTS
let app = NSApplication.shared
let bundledProject = Bundle.main.resourceURL!.appendingPathComponent("Project")
let fallbackProject = FileManager.default.fileExists(atPath: bundledProject.path)
    ? bundledProject : Bundle.main.bundleURL.deletingLastPathComponent()
let dir = CommandLine.arguments.count > 1 && !CommandLine.arguments[1].hasPrefix("-")
    ? CommandLine.arguments[1] : fallbackProject.path
let requested = CommandLine.arguments.count > 3 ? CommandLine.arguments[3] : nil
let delegate = InstallationWizard(projectDirectory: dir, languageCode: requested)
app.delegate = delegate
app.run()

#endif
