// Test the real AppKit controls and subprocess runner using harmless local fixtures.
extension InstallationWizard {
    func verifySetup(previewDirectory: URL?) {
        func check(_ value: @autoclosure () -> Bool, _ message: String) {
            if !value() { fatalError(message) }
        }
        window.appearance = NSAppearance(named: .aqua)
        check(detailsScroll.isHidden, "Technical logs must start collapsed")
        check(buildButton.isHidden, "Build check belongs to advanced details")
        check(!overview.isHidden, "Normal setup instructions must be visible")
        for (code, _) in WizardLanguage.supported {
            language.code = code
            refreshTranslations()
            check(!installButton.title.hasPrefix("wizard."), "Translated install button")
            check(openButton.title == T("openApp"), "Translated open button")
            check(removeButton.title == T("uninstall"), "Translated uninstall button")
            for button in [installButton, reportButton, copyButton, issuesButton, closeButton,
                           openButton, removeButton, buildButton, detailsButton] {
                check(button!.intrinsicContentSize.width <= button!.frame.width, "Button title must fit: \(button!.title)")
            }
            let removal = uninstallConfirmation()
            check(removal.buttons.count == 2 && removal.buttons.last?.keyEquivalent == "\r", "Removal defaults to cancel")
            check(removal.buttons.first?.hasDestructiveAction == true, "Removal is clearly destructive")
            check(!busy, "Constructing confirmation must not start removal")
            let chooser = languageChooser()
            chooser.window.appearance = NSAppearance(named: .aqua)
            check((chooser.accessoryView as? NSPopUpButton)?.numberOfItems == 8, "Eight language choices")
            check(chooser.buttons.first?.title == T("continue"), "Translated continuation")
            if let folder = previewDirectory, ["en", "nl", "fr", "pl"].contains(code) {
                try! FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                func render(_ view: NSView, name: String) {
                    view.layoutSubtreeIfNeeded()
                    let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds)!
                    view.cacheDisplay(in: view.bounds, to: bitmap)
                    try! bitmap.representation(using: .png, properties: [:])!.write(to: folder.appendingPathComponent(name))
                }
                render(window.contentView!, name: "setup-\(code).png")
                chooser.layout()
                render(chooser.window.contentView!, name: "language-\(code).png")
            }
        }
        toggleDetails()
        check(!detailsScroll.isHidden && !buildButton.isHidden && overview.isHidden, "Details disclosure")
        toggleDetails()
        let report = project.appendingPathComponent("fixture-report.txt")
        try! Data("Harmless diagnostic fixture".utf8).write(to: report)
        let fixture = project.appendingPathComponent("Fixture.command")
        try! Data("#!/bin/bash\nprintf 'fixture output\\n'\nprintf 'Saved report: %s\\n' \"$1\"\n".utf8).write(to: fixture)
        start("Fixture.command", arguments: [report.path], operation: .report)
        check(busy && !installButton.isEnabled && !removeButton.isEnabled && !languagePopup.isEnabled, "No concurrent actions")
        let deadline = Date().addingTimeInterval(10)
        while busy && Date() < deadline { RunLoop.main.run(until: Date().addingTimeInterval(0.01)) }
        check(!busy, "Fixture must finish")
        check(statusKey == "reportDone", "Correct completion state")
        check(reportURL == report && copyButton.isEnabled, "Report discovered after complete output drain")
        check(fullLog.contains("fixture output"), "Hidden log preserved")
        check(details.string == "Harmless diagnostic fixture" && !detailsScroll.isHidden, "Report must be available for review before copy")
        check(languagePopup.isEnabled && installButton.isEnabled, "Actions restored after completion")
        print("Native setup controls, eight languages, details disclosure and subprocess completion passed.")
    }
}
let testApp = NSApplication.shared
let projectPath = ProcessInfo.processInfo.environment["ECZ_GUI_FIXTURE"]!
let setup = InstallationWizard(projectDirectory: projectPath, languageCode: "en")
setup.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
let preview = ProcessInfo.processInfo.environment["ECZ_GUI_PREVIEW"].map { URL(fileURLWithPath: $0) }
setup.verifySetup(previewDirectory: preview)

func updateGate(_ requested: String = "1.3.0", _ packaged: String = "1.3.0", _ installed: String = "1.2.0", _ automatic: Bool = true, _ enabled: Bool = true, _ known: Bool = true) -> Bool {
    SetupUpdatePolicy.canInstall(requested: requested, packaged: packaged, installed: installed, automatic: automatic, enabled: enabled, knownModel: known)
}
precondition(updateGate())
precondition(!updateGate("1.3.0", "1.3.0", "1.3.0"))
precondition(!updateGate("1.3.0", "1.3.0", "1.4.0"))
precondition(updateGate("1.3.0", "1.3.0", "1.3.0-dev.1"))
precondition(!updateGate("1.3.0", "1.2.0"))
precondition(!updateGate("1.3.0", "1.3.0", "1.2.0", true, false))
precondition(updateGate("1.3.0", "1.3.0", "1.2.0", false, false))
precondition(!updateGate("1.3.0", "1.3.0", "1.2.0", true, true, false))
precondition(!updateGate("1.3.0", "1.3.0", ""))
precondition(!updateGate("1.3.0-beta1", "1.3.0-beta1"))
print("10 Setup update handoff policy assertions passed; no installation.")
