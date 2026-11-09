// EasyComp Keyboard Light — native multilingual setup wizard v1.2.0-beta6.
// The eight language bundles ship with the wizard; no online translation service.
import AppKit
import Foundation

private let issuePage = "https://github.com/EasyCompZLD/EasyComp-Keyboard-Light---For-headless-Apple-MacBook-Pro-s-with-T2-Chip/issues/new?template=installation_failure.md"
private let versionText = "1.2.0-beta6"

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

final class InstallationWizard: NSObject, NSApplicationDelegate {
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

        let scroll = NSScrollView(frame: NSRect(x: 28, y: 84, width: 800, height: 273))
        scroll.borderType = .bezelBorder
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        details = NSTextView(frame: NSRect(x: 0, y: 0, width: 786, height: 270))
        details.isEditable = false
        details.isSelectable = true
        details.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        scroll.documentView = details
        content.addSubview(scroll)

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
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        // Bootstrap declares success only after the native window has been shown.
        if CommandLine.arguments.count > 2 {
            let readyMarker = URL(fileURLWithPath: CommandLine.arguments[2])
            try? Data("window-ready".utf8).write(to: readyMarker, options: .atomic)
        }
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    private func refreshTranslations() {
        window.title = "EasyComp Keyboard Light — " + T("title")
        subtitleLabel.stringValue = F("subtitle", versionText)
        intro.stringValue = F("intro", modelName, architecture)
        languageLabel.stringValue = T("languageLabel") + ":"
        installButton.title = T("install")
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

    private func start(_ script: String, arguments: [String], installing: Bool) {
        if running != nil { return }
        let file = project.appendingPathComponent(script)
        guard FileManager.default.fileExists(atPath: file.path) else {
            showError(F("missing", script))
            return
        }
        fullLog = ""
        reportURL = nil
        details.string = ""
        startedAt = Date()
        installButton.isEnabled = false
        reportButton.isEnabled = false
        copyButton.isEnabled = false
        closeButton.isEnabled = false
        statusKey = installing ? "installing" : "diagnosing"
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
        output.fileHandleForReading.readabilityHandler = { [weak self] fileHandle in
            let data = fileHandle.availableData
            if data.isEmpty { fileHandle.readabilityHandler = nil; return }
            let chunk = String(decoding: data, as: UTF8.self)
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.fullLog += chunk
                self.details.string += chunk
                self.details.scrollToEndOfDocument(nil)
                for index in 1...4 where chunk.contains("ECZ_STEP:\(index)") {
                    self.statusKey = "step\(index)"
                }
                self.refreshTranslations()
            }
        }
        p.terminationHandler = { [weak self] ended in
            DispatchQueue.main.async { [weak self] in
                self?.didFinish(statusCode: ended.terminationStatus, installing: installing)
            }
        }
        running = p
        do { try p.run() }
        catch {
            running = nil
            progress.stopAnimation(nil)
            installButton.isEnabled = true
            reportButton.isEnabled = true
            closeButton.isEnabled = true
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
    private func didFinish(statusCode: Int32, installing: Bool) {
        running = nil
        progress.stopAnimation(nil)
        installButton.isEnabled = true
        reportButton.isEnabled = true
        closeButton.isEnabled = true
        reportURL = discoverReport()
        copyButton.isEnabled = reportURL != nil
        if statusCode == 0 {
            statusKey = installing ? "done" : "reportDone"
            refreshTranslations()
            if installing {
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
            message.messageText = T("failedTitle")
            message.informativeText = T("failedBody")
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
        let supported = modelName == "MacBookPro16,1"
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
        start("Installeer.command", arguments: supported ? [] : ["--experimental"], installing: true)
    }
    @objc private func makeReport() { start("Probleemrapport.command", arguments: [], installing: false) }
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
        if running != nil { showError(T("busy")); return }
        NSApp.terminate(nil)
    }
}

let app = NSApplication.shared
let dir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : Bundle.main.bundleURL.deletingLastPathComponent().path
let requested = CommandLine.arguments.count > 3 ? CommandLine.arguments[3] : nil
let delegate = InstallationWizard(projectDirectory: dir, languageCode: requested)
app.delegate = delegate
app.run()
