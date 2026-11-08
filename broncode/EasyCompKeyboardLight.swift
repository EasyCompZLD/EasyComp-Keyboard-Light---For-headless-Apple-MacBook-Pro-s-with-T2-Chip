// EasyComp Keyboard Light v1.1.0
// Native menu bar utility for headless MacBookPro16,1 (A2141, T2).
// HID hardware control is delegated to the separately verified C helper.
import AppKit
import CoreGraphics
import Foundation

private let agentLabel = "nl.easycompzeeland.KeyboardLight"
private let illuminationUp = 21
private let illuminationDown = 22
private let illuminationToggle = 23

// Runtime language selection. Default follows the macOS language preference.
// Each translation is shipped as a standard Localizable.strings in Contents/Resources.
private final class LanguageManager {
    static let shared = LanguageManager()
    static let languages: [(code: String, name: String)] = [
        ("nl", "Nederlands"), ("en", "English"), ("de", "Deutsch"),
        ("fr", "Français"), ("es", "Español"), ("it", "Italiano"),
        ("pt", "Português"), ("pl", "Polski")
    ]
    private let key = "AppLanguage"
    var selectedCode: String {
        get {
            let saved = UserDefaults.standard.string(forKey: key) ?? "system"
            return saved == "system" || Self.languages.contains(where: { $0.code == saved }) ? saved : "system"
        }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
    var effectiveCode: String {
        if selectedCode != "system" { return selectedCode }
        for preferred in Locale.preferredLanguages {
            // e.g. nl-NL, de-DE, pt-BR, en-GB, zh-Hans-CN
            let code = String(preferred.lowercased().split(separator: "-").first ?? "en")
            if Self.languages.contains(where: { $0.code == code }) { return code }
        }
        return "en"
    }
    func text(_ key: String) -> String {
        for lang in [effectiveCode, "en"] {
            guard let resourcePath = Bundle.main.path(forResource: lang, ofType: "lproj"),
                  let languageBundle = Bundle(path: resourcePath) else { continue }
            let value = languageBundle.localizedString(forKey: key, value: nil, table: "Localizable")
            if value != key { return value }
        }
        return key
    }
}

final class KeyboardLightApp: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let menu = NSMenu()
    private let slider = NSSlider()
    private let headerItem = NSMenuItem()
    private let levelItem = NSMenuItem()
    private let powerItem = NSMenuItem()
    private let brighterItem = NSMenuItem()
    private let dimmerItem = NSMenuItem()
    private let loginItem = NSMenuItem()
    private let privacyItem = NSMenuItem()
    private let accessItem = NSMenuItem()
    private let languageItem = NSMenuItem()
    private let quitItem = NSMenuItem()
    private let touchBarItem = NSMenuItem()
    private let messageItem = NSMenuItem()
    private var languageOptions = [NSMenuItem]()
    private var tap: CFMachPort?
    private var tapSource: CFRunLoopSource?
    private var fallbackMonitor: Any?
    private var pending: DispatchWorkItem?
    private var activeProcess: Process?
    private var queuedLevel: Double?
    private enum HIDState { case ready, succeeded, failed(Int32), couldNotStart, autostartFailed }
    private enum TouchBarState { case starting, listening, accessDenied, keyReceived }
    private var hidState: HIDState = .ready
    private var touchBarState: TouchBarState = .starting

    private var brightness = 0.5 // 0.1 ... 1.0, supported by the proven helper
    private var powered = true
    private var helperURL: URL {
        Bundle.main.executableURL!.deletingLastPathComponent()
            .appendingPathComponent("ecz-a2141-backlight")
    }
    private var agentURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(agentLabel).plist")
    }
    private func T(_ key: String) -> String { LanguageManager.shared.text(key) }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let store = UserDefaults.standard
        if store.object(forKey: "lastBrightness") != nil {
            brightness = max(0.1, min(1, store.double(forKey: "lastBrightness")))
        }
        if store.object(forKey: "powered") != nil {
            powered = store.bool(forKey: "powered")
        }
        configureMenu()
        listenForIlluminationKeys()
        refreshMenu()
        scheduleWrite(delay: 0.25)
    }

    private func configureMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let icon = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "Keyboard backlight") {
            icon.isTemplate = true
            statusItem.button?.image = icon
        } else {
            statusItem.button?.title = "⌨"
        }
        menu.autoenablesItems = false
        headerItem.isEnabled = false
        menu.addItem(headerItem)
        menu.addItem(.separator())

        levelItem.isEnabled = false
        menu.addItem(levelItem)
        let sliderItem = NSMenuItem()
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 268, height: 42))
        slider.minValue = 0
        slider.maxValue = 100
        slider.target = self
        slider.action = #selector(sliderMoved(_:))
        slider.frame = NSRect(x: 20, y: 7, width: 228, height: 28)
        slider.numberOfTickMarks = 11
        slider.allowsTickMarkValuesOnly = true
        slider.isContinuous = true
        view.addSubview(slider)
        sliderItem.view = view
        menu.addItem(sliderItem)

        powerItem.action = #selector(togglePower)
        powerItem.target = self
        menu.addItem(powerItem)
        brighterItem.action = #selector(brighterAction)
        brighterItem.target = self
        menu.addItem(brighterItem)
        dimmerItem.action = #selector(dimmerAction)
        dimmerItem.target = self
        menu.addItem(dimmerItem)

        menu.addItem(.separator())
        touchBarItem.isEnabled = false
        menu.addItem(touchBarItem)
        messageItem.isEnabled = false
        menu.addItem(messageItem)

        loginItem.action = #selector(toggleLogin)
        loginItem.target = self
        menu.addItem(loginItem)

        let languageMenu = NSMenu()
        languageMenu.autoenablesItems = false
        for (code, name) in [(code: "system", name: "") ] + LanguageManager.languages {
            let option = NSMenuItem(title: name, action: #selector(selectLanguage(_:)), keyEquivalent: "")
            option.representedObject = code
            option.target = self
            languageMenu.addItem(option)
            languageOptions.append(option)
        }
        languageItem.submenu = languageMenu
        menu.addItem(languageItem)

        privacyItem.action = #selector(openInputMonitoring)
        privacyItem.target = self
        menu.addItem(privacyItem)
        accessItem.action = #selector(openAccessibility)
        accessItem.target = self
        menu.addItem(accessItem)

        menu.addItem(.separator())
        quitItem.action = #selector(quitApp)
        quitItem.target = self
        menu.addItem(quitItem)
        statusItem.menu = menu
        refreshTranslations()
    }

    private func refreshTranslations() {
        headerItem.title = "EasyComp Keyboard Light"
        brighterItem.title = T("brightness.up")
        dimmerItem.title = T("brightness.down")
        loginItem.title = T("startup.login")
        privacyItem.title = T("privacy.input")
        accessItem.title = T("privacy.accessibility")
        languageItem.title = T("language")
        quitItem.title = T("app.quit")
        slider.toolTip = T("brightness.tooltip")
        for option in languageOptions {
            if let code = option.representedObject as? String {
                option.title = code == "system" ? T("language.system") :
                    (LanguageManager.languages.first(where: { $0.code == code })?.name ?? code)
            }
        }
        refreshMenu()
    }

    private func refreshMenu() {
        let level = powered ? Int((brightness * 100).rounded()) : 0
        levelItem.title = "\(T("brightness.label")): \(level)%"
        powerItem.title = powered ? T("power.off") : T("power.on")
        slider.doubleValue = powered ? brightness * 100 : 0
        loginItem.state = FileManager.default.fileExists(atPath: agentURL.path) ? .on : .off
        statusItem.button?.toolTip = "\(T("brightness.tooltip")): \(powered ? "\(level)%" : T("power.off.label"))"
        switch touchBarState {
        case .starting: touchBarItem.title = T("touchbar.starting")
        case .listening: touchBarItem.title = T("touchbar.listening")
        case .accessDenied: touchBarItem.title = T("touchbar.noaccess")
        case .keyReceived: touchBarItem.title = T("touchbar.received")
        }
        switch hidState {
        case .ready: messageItem.title = T("hid.ready")
        case .succeeded: messageItem.title = T("hid.success")
        case .failed(let code): messageItem.title = "\(T("hid.error")) \(code)"
        case .couldNotStart: messageItem.title = T("hid.launchfailed")
        case .autostartFailed: messageItem.title = T("startup.error")
        }
        for option in languageOptions {
            option.state = (option.representedObject as? String) == LanguageManager.shared.selectedCode ? .on : .off
        }
    }

    @objc private func selectLanguage(_ sender: NSMenuItem) {
        guard let code = sender.representedObject as? String else { return }
        LanguageManager.shared.selectedCode = code
        refreshTranslations()
    }

    private func save() {
        UserDefaults.standard.set(brightness, forKey: "lastBrightness")
        UserDefaults.standard.set(powered, forKey: "powered")
        refreshMenu()
    }

    @objc private func sliderMoved(_ sender: NSSlider) {
        let step = Int((sender.doubleValue / 10).rounded())
        if step <= 0 {
            powered = false
        } else {
            powered = true
            brightness = Double(step) / 10.0
        }
        save()
        scheduleWrite(delay: 0.08)
    }

    @objc private func togglePower() {
        powered.toggle()
        save()
        scheduleWrite(delay: 0)
    }
    @objc private func brighterAction() { changeBrightness(by: 0.1) }
    @objc private func dimmerAction() { changeBrightness(by: -0.1) }

    private func changeBrightness(by delta: Double) {
        let current = powered ? brightness : 0.0
        let next = max(0.0, min(1.0, (current + delta) * 10.0))
        let step = Int(next.rounded())
        if step == 0 {
            powered = false
        } else {
            brightness = Double(step) / 10.0
            powered = true
        }
        save()
        scheduleWrite(delay: 0.02)
    }

    // Coalesce repeated changes; at most one HID helper runs at a time.
    private func scheduleWrite(delay: TimeInterval) {
        pending?.cancel()
        let target = powered ? brightness : 0.0
        let work = DispatchWorkItem { [weak self] in self?.performWrite(target) }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func performWrite(_ level: Double) {
        if activeProcess != nil {
            queuedLevel = level
            return
        }
        let task = Process()
        task.executableURL = helperURL
        task.arguments = level <= 0 ? ["off"] : ["on", String(level)]
        task.standardOutput = FileHandle.nullDevice
        let errorPipe = Pipe()
        task.standardError = errorPipe
        activeProcess = task
        task.terminationHandler = { [weak self] ended in
            let data = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let info = String(data: data, encoding: .utf8) ?? ""
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.activeProcess = nil
                if ended.terminationStatus == 0 {
                    self.hidState = .succeeded
                } else {
                    self.hidState = .failed(ended.terminationStatus)
                    NSLog("EasyComp Keyboard Light: HID error %@", info.trimmingCharacters(in: .whitespacesAndNewlines))
                }
                self.refreshMenu()
                if let newest = self.queuedLevel {
                    self.queuedLevel = nil
                    self.performWrite(newest)
                }
            }
        }
        do {
            try task.run()
        } catch {
            activeProcess = nil
            hidState = .couldNotStart
            refreshMenu()
            NSLog("EasyComp Keyboard Light: %@", error.localizedDescription)
        }
    }

    // NX_KEYTYPE_ILLUMINATION_UP/DOWN/TOGGLE (21/22/23).
    // Only works if macOS still publishes the original Touch Bar events.
    private func listenForIlluminationKeys() {
        let mask: CGEventMask = CGEventMask(1) << 14 // NX_SYSDEFINED
        let cb: CGEventTapCallBack = { _, kind, event, userInfo in
            if kind == .tapDisabledByTimeout || kind == .tapDisabledByUserInput {
                if let userInfo = userInfo {
                    let owner = Unmanaged<KeyboardLightApp>.fromOpaque(userInfo).takeUnretainedValue()
                    if let port = owner.tap { CGEvent.tapEnable(tap: port, enable: true) }
                }
                return Unmanaged.passUnretained(event)
            }
            guard kind.rawValue == 14,
                  let e = NSEvent(cgEvent: event),
                  e.type == .systemDefined,
                  e.subtype.rawValue == 8,
                  let userInfo = userInfo else { return Unmanaged.passUnretained(event) }
            let code = (e.data1 >> 16) & 0xffff
            let state = (e.data1 >> 8) & 0xff
            if state == 0x0a && (code == illuminationUp || code == illuminationDown || code == illuminationToggle) {
                let owner = Unmanaged<KeyboardLightApp>.fromOpaque(userInfo).takeUnretainedValue()
                DispatchQueue.main.async { owner.handleIllumination(code: code) }
            }
            return Unmanaged.passUnretained(event)
        }
        tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
                                options: .listenOnly, eventsOfInterest: mask,
                                callback: cb, userInfo: Unmanaged.passUnretained(self).toOpaque())
        if let port = tap, let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0) {
            tapSource = source
            CFRunLoopAddSource(CFRunLoopGetMain(), source, CFRunLoopMode.commonModes)
            CGEvent.tapEnable(tap: port, enable: true)
            touchBarState = .listening
        } else {
            touchBarState = .accessDenied
            fallbackMonitor = NSEvent.addGlobalMonitorForEvents(matching: .systemDefined) { [weak self] e in
                guard e.subtype.rawValue == 8 else { return }
                let code = (e.data1 >> 16) & 0xffff
                let state = (e.data1 >> 8) & 0xff
                if state == 0x0a && (code == illuminationUp || code == illuminationDown || code == illuminationToggle) {
                    self?.handleIllumination(code: code)
                }
            }
        }
        refreshMenu()
    }

    private func handleIllumination(code: Int) {
        switch code {
        case illuminationUp: changeBrightness(by: 0.1)
        case illuminationDown: changeBrightness(by: -0.1)
        case illuminationToggle: togglePower()
        default: return
        }
        touchBarState = .keyReceived
        refreshMenu()
    }

    private func openSettings(_ pane: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") {
            NSWorkspace.shared.open(url)
        }
    }
    @objc private func openInputMonitoring() { openSettings("Privacy_ListenEvent") }
    @objc private func openAccessibility() { openSettings("Privacy_Accessibility") }

    @objc private func toggleLogin() {
        do {
            if FileManager.default.fileExists(atPath: agentURL.path) {
                try FileManager.default.removeItem(at: agentURL)
            } else {
                try FileManager.default.createDirectory(at: agentURL.deletingLastPathComponent(),
                                                        withIntermediateDirectories: true)
                let settings: [String: Any] = [
                    "Label": agentLabel,
                    "ProgramArguments": [Bundle.main.executableURL!.path],
                    "RunAtLoad": true,
                    "KeepAlive": false,
                    "LimitLoadToSessionType": "Aqua"
                ]
                let data = try PropertyListSerialization.data(fromPropertyList: settings,
                                                               format: .xml, options: 0)
                try data.write(to: agentURL, options: .atomic)
            }
            refreshMenu()
        } catch {
            hidState = .autostartFailed
            refreshMenu()
            NSLog("EasyComp Keyboard Light: launch agent error %@", error.localizedDescription)
        }
    }
    @objc private func quitApp() {
        pending?.cancel()
        NSApplication.shared.terminate(nil)
    }
}

let application = NSApplication.shared
let delegate = KeyboardLightApp()
application.delegate = delegate
application.setActivationPolicy(.accessory)
application.run()
