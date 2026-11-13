// EasyComp Keyboard Light v1.2.0
// Native menu bar utility for compatible headless Intel T2 MacBooks.
// HID hardware control is delegated to the separately verified C helper.
import AppKit
import CoreGraphics
import Foundation
import Darwin

private let agentLabel = Bundle.main.bundleIdentifier ?? "nl.easycompzeeland.KeyboardLight"
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

// Pure policy shared by the app and executable regression tests.
enum BacklightPolicy {
    static func effectiveLevel(powered: Bool, brightness: Double, idleOff: Bool,
                               sleeping: Bool, sessionActive: Bool) -> Double {
        (powered && !idleOff && !sleeping && sessionActive) ? brightness : 0
    }
    static func step(current: Double, delta: Double) -> Int {
        Int((max(0, min(1, current + delta)) * 10).rounded())
    }
    static func idleOff(powered: Bool, timeout: Int, suspended: Bool,
                        idle: TimeInterval?, sinceAdjustment: TimeInterval?) -> Bool {
        guard powered, timeout > 0, !suspended,
              let idle = idle, idle.isFinite, idle >= 0 else { return false }
        return min(idle, sinceAdjustment ?? idle) >= Double(timeout)
    }
}

// Deduplicate delivery through multiple monitors by the original event timestamp,
// not the delivery time: genuine rapid presses and auto-repeat must survive.
struct IlluminationEvents {
    private var recent: [(Int, TimeInterval)] = []
    mutating func accept(code: Int, timestamp: TimeInterval) -> Bool {
        guard [21, 22, 23].contains(code), timestamp.isFinite else { return false }
        if recent.contains(where: { $0.0 == code && abs($0.1 - timestamp) < 0.000001 }) { return false }
        recent.append((code, timestamp))
        if recent.count > 32 { recent.removeFirst() }
        return true
    }
}

// Main-thread write coordination. A generation change invalidates hardware state
// even if an older helper completes successfully after wake or session changes.
struct BacklightWrites {
    private(set) var busy = false
    private var requested = false
    private var generation: UInt64 = 0
    private var lastLevel: Double?
    mutating func invalidate() { generation &+= 1; lastLevel = nil }
    mutating func begin(level: Double) -> UInt64? {
        if busy { requested = true; return nil }
        guard lastLevel != level else { return nil }
        busy = true
        requested = false
        return generation
    }
    mutating func complete(level: Double, generation: UInt64, succeeded: Bool) -> Bool {
        busy = false
        lastLevel = succeeded && generation == self.generation ? level : nil
        let again = requested
        requested = false
        return again
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
    private let idleStatusItem = NSMenuItem()
    private let timeoutItem = NSMenuItem()
    private var timeoutChoices = [NSMenuItem]()
    private let timeoutOptions: [(seconds: Int, key: String)] = [
        (0, "idle.never"),
        (15, "idle.15s"),
        (30, "idle.30s"),
        (60, "idle.1m"),
        (300, "idle.5m"),
        (600, "idle.10m"),
        (1800, "idle.30m")
    ]
    private var languageOptions = [NSMenuItem]()
    private var monitorThread: Thread?
    private var fallbackMonitor: Any?
    private var localMonitor: Any?
    private var idleTimer: Timer?
    private var timeoutSeconds = 30 // User-configurable; 0 means never.
    private var idleOff = false
    private var sleeping = false
    private var sessionActive = true
    private var terminating = false
    private var lastLocalAdjustmentUptime: TimeInterval = 0
    private var illuminationEvents = IlluminationEvents()
    private let eventDiagnostics = CommandLine.arguments.contains("--diagnose-events")
    private var pending: DispatchWorkItem?
    private var activeProcess: Process?
    private var writes = BacklightWrites()
    private var helperWatchdog: DispatchWorkItem?
    private enum HIDState { case ready, succeeded, failed(Int32), couldNotStart, autostartFailed }
    private enum TouchBarState { case starting, listening, accessDenied, keyReceived }
    private var hidState: HIDState = .ready
    private var touchBarState: TouchBarState = .starting

    private var brightness = 0.5 // 0.1 ... 1.0, supported by the proven helper
    private var powered = true
    private var helperURL: URL {
        Bundle.main.executableURL!.deletingLastPathComponent()
            .appendingPathComponent("ecz-t2-backlight")
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
        if store.object(forKey: "idleTimeoutSeconds") != nil {
            let saved = store.integer(forKey: "idleTimeoutSeconds")
            if timeoutOptions.contains(where: { $0.seconds == saved }) {
                timeoutSeconds = saved
            }
        }
        configureMenu()
        watchSystemPowerState()
        startIdleMonitoring()
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
        let timeoutMenu = NSMenu()
        timeoutMenu.autoenablesItems = false
        for option in timeoutOptions {
            let item = NSMenuItem(title: "", action: #selector(selectTimeout(_:)), keyEquivalent: "")
            item.representedObject = option.seconds
            item.target = self
            timeoutMenu.addItem(item)
            timeoutChoices.append(item)
        }
        timeoutItem.submenu = timeoutMenu
        menu.addItem(timeoutItem)
        idleStatusItem.isEnabled = false
        menu.addItem(idleStatusItem)

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
        timeoutItem.title = T("idle.timeout.title")
        for (index, option) in timeoutChoices.enumerated() {
            option.title = T(timeoutOptions[index].key)
        }
        for option in languageOptions {
            if let code = option.representedObject as? String {
                option.title = code == "system" ? T("language.system") :
                    (LanguageManager.languages.first(where: { $0.code == code })?.name ?? code)
            }
        }
        refreshMenu()
    }

    private func refreshMenu() {
        let level = effectiveLevel() > 0 ? Int((brightness * 100).rounded()) : 0
        levelItem.title = "\(T("brightness.label")): \(level)%"
        powerItem.title = powered ? T("power.off") : T("power.on")
        slider.doubleValue = Double(level)
        let idleStatusKey = !powered ? "idle.status.manualoff"
            : (sleeping || !sessionActive) ? "idle.status.suspended"
            : timeoutSeconds == 0 ? "idle.status.disabled"
            : idleOff ? "idle.status.off" : "idle.status.active"
        idleStatusItem.title = T(idleStatusKey)
        loginItem.state = FileManager.default.fileExists(atPath: agentURL.path) ? .on : .off
        statusItem.button?.toolTip = "\(T("brightness.tooltip")): \(level)%"
        for option in timeoutChoices {
            option.state = (option.representedObject as? Int) == timeoutSeconds ? .on : .off
        }
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

    @objc private func selectTimeout(_ sender: NSMenuItem) {
        guard let seconds = sender.representedObject as? Int,
              timeoutOptions.contains(where: { $0.seconds == seconds }) else { return }
        timeoutSeconds = seconds
        UserDefaults.standard.set(seconds, forKey: "idleTimeoutSeconds")
        updateIdleState()
        refreshMenu()
    }

    private func effectiveLevel() -> Double {
        BacklightPolicy.effectiveLevel(powered: powered, brightness: brightness,
                                      idleOff: idleOff, sleeping: sleeping, sessionActive: sessionActive)
    }

    // Quartz reports time since the last HID input, even while this menu bar
    // app is not frontmost. No key data is stored, captured or transmitted.
    private func systemIdleSeconds() -> TimeInterval? {
        guard let anyInput = CGEventType(rawValue: UInt32.max) else { return nil }
        let seconds = CGEventSource.secondsSinceLastEventType(
            .combinedSessionState, eventType: anyInput)
        return seconds.isFinite && seconds >= 0 ? seconds : nil
    }

    private func registerLocalAdjustment() {
        lastLocalAdjustmentUptime = ProcessInfo.processInfo.systemUptime
        if idleOff {
            idleOff = false
            scheduleWrite(delay: 0)
        }
    }

    private func startIdleMonitoring() {
        // Common run-loop modes keep the timer responsive while a menu is open.
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateIdleState()
        }
        idleTimer = timer
        RunLoop.main.add(timer, forMode: .common)
        updateIdleState()
    }

    private func updateIdleState() {
        let sinceAdjustment = lastLocalAdjustmentUptime > 0
            ? max(0, ProcessInfo.processInfo.systemUptime - lastLocalAdjustmentUptime) : nil
        let shouldTurnOff = BacklightPolicy.idleOff(
            powered: powered, timeout: timeoutSeconds, suspended: sleeping || !sessionActive,
            idle: systemIdleSeconds(), sinceAdjustment: sinceAdjustment)
        if idleOff != shouldTurnOff {
            idleOff = shouldTurnOff
            refreshMenu()
            scheduleWrite(delay: 0)
        }
    }

    private func watchSystemPowerState() {
        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(self, selector: #selector(systemWillSleep(_:)),
                           name: NSWorkspace.willSleepNotification, object: nil)
        center.addObserver(self, selector: #selector(systemDidWake(_:)),
                           name: NSWorkspace.didWakeNotification, object: nil)
        center.addObserver(self, selector: #selector(sessionResigned(_:)),
                           name: NSWorkspace.sessionDidResignActiveNotification, object: nil)
        center.addObserver(self, selector: #selector(sessionActivated(_:)),
                           name: NSWorkspace.sessionDidBecomeActiveNotification, object: nil)
    }

    @objc private func systemWillSleep(_ notification: Notification) {
        sleeping = true
        writes.invalidate()
        refreshMenu()
        scheduleWrite(delay: 0)
    }

    @objc private func systemDidWake(_ notification: Notification) {
        sleeping = false
        writes.invalidate() // Hardware state may have changed during sleep.
        registerLocalAdjustment()
        updateIdleState()
        scheduleWrite(delay: 0.2)
    }

    @objc private func sessionResigned(_ notification: Notification) {
        // Session activation is independent of the physical sleep state.
        sessionActive = false
        refreshMenu()
        scheduleWrite(delay: 0)
    }

    @objc private func sessionActivated(_ notification: Notification) {
        sessionActive = true
        writes.invalidate()
        registerLocalAdjustment()
        updateIdleState()
        scheduleWrite(delay: 0.2)
    }

    @objc private func sliderMoved(_ sender: NSSlider) {
        let step = Int((sender.doubleValue / 10).rounded())
        if step <= 0 {
            powered = false
        } else {
            powered = true
            brightness = Double(step) / 10.0
        }
        registerLocalAdjustment()
        save()
        scheduleWrite(delay: 0.08)
    }

    @objc private func togglePower() {
        powered.toggle()
        registerLocalAdjustment()
        save()
        scheduleWrite(delay: 0)
    }
    @objc private func brighterAction() { changeBrightness(by: 0.1) }
    @objc private func dimmerAction() { changeBrightness(by: -0.1) }

    private func changeBrightness(by delta: Double) {
        let current = powered ? brightness : 0.0
        let step = BacklightPolicy.step(current: current, delta: delta)
        if step == 0 {
            powered = false
        } else {
            brightness = Double(step) / 10.0
            powered = true
        }
        registerLocalAdjustment()
        save()
        scheduleWrite(delay: 0.02)
    }

    // Coalesce repeated changes; at most one HID helper runs at a time.
    private func scheduleWrite(delay: TimeInterval) {
        guard !terminating else { return }
        pending?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.performWrite() }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func performWrite() {
        guard !terminating else { return }
        let level = effectiveLevel() // Never replay a stale queued on-command after sleep/off.
        guard let generation = writes.begin(level: level) else { return }
        let task = Process()
        task.executableURL = helperURL
        task.arguments = level <= 0 ? ["off"] : ["on", String(level)]
        // The helper writes its bounded protocol diagnostics to stdout.
        let errorPipe = Pipe()
        task.standardOutput = errorPipe
        task.standardError = errorPipe
        activeProcess = task
        task.terminationHandler = { [weak self] ended in
            let data = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let info = String(data: data, encoding: .utf8) ?? ""
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.activeProcess = nil
                self.helperWatchdog?.cancel()
                let again = self.writes.complete(level: level, generation: generation,
                                                succeeded: ended.terminationStatus == 0)
                if ended.terminationStatus == 0 {
                    self.hidState = .succeeded
                } else {
                    self.hidState = .failed(ended.terminationStatus)
                    NSLog("EasyComp Keyboard Light: HID error %@", info.trimmingCharacters(in: .whitespacesAndNewlines))
                }
                self.refreshMenu()
                if again { self.scheduleWrite(delay: 0) }
            }
        }
        do {
            try task.run()
            let watchdog = DispatchWorkItem {
                guard task.isRunning else { return }
                NSLog("EasyComp Keyboard Light: HID helper exceeded 5 seconds")
                task.terminate()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    if task.isRunning { kill(task.processIdentifier, SIGKILL) }
                }
            }
            helperWatchdog = watchdog
            DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: watchdog)
        } catch {
            _ = writes.complete(level: level, generation: generation, succeeded: false)
            activeProcess = nil
            hidState = .couldNotStart
            refreshMenu()
            NSLog("EasyComp Keyboard Light: %@", error.localizedDescription)
        }
    }

    private func receiveIllumination(_ event: NSEvent, source: String) {
        guard event.type == .systemDefined, event.subtype.rawValue == 8 else { return }
        let code = (event.data1 >> 16) & 0xffff
        let state = (event.data1 >> 8) & 0xff
        guard state == 0x0a, [illuminationUp, illuminationDown, illuminationToggle].contains(code) else { return }
        let timestamp = event.timestamp
        DispatchQueue.main.async { [weak self] in
            guard let self = self, !self.terminating else { return }
            if self.eventDiagnostics {
                NSLog("EasyComp illumination: source=%@ code=%d timestamp=%.6f", source, code, timestamp)
            }
            self.handleIllumination(code: code, timestamp: timestamp)
        }
    }

    private func listenForIlluminationKeys() {
        fallbackMonitor = NSEvent.addGlobalMonitorForEvents(matching: .systemDefined) { [weak self] event in
            self?.receiveIllumination(event, source: "global")
        }
        // A global AppKit monitor excludes events delivered to this application.
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .systemDefined) { [weak self] event in
            self?.receiveIllumination(event, source: "local")
            return event
        }
        let worker = Thread { [weak self] in self?.runIlluminationEventTap() }
        worker.name = "EasyComp Keyboard Light – Touch Bar events"
        worker.qualityOfService = .userInitiated
        monitorThread = worker
        worker.start()
    }

    // All tap resources belong exclusively to this worker. Retry after a failed
    // creation or invalidation, including permission changes and wake/session changes.
    private func runIlluminationEventTap() {
        let mask: CGEventMask = CGEventMask(1) << 14 // NX_SYSDEFINED
        let callback: CGEventTapCallBack = { _, kind, event, userInfo in
            guard kind.rawValue == 14, let userInfo = userInfo,
                  let e = NSEvent(cgEvent: event) else { return Unmanaged.passUnretained(event) }
            let owner = Unmanaged<KeyboardLightApp>.fromOpaque(userInfo).takeUnretainedValue()
            owner.receiveIllumination(e, source: "tap")
            return Unmanaged.passUnretained(event)
        }
        var port: CFMachPort?
        var source: CFRunLoopSource?
        var lastListening: Bool?
        let loop = CFRunLoopGetCurrent()
        while !Thread.current.isCancelled {
            if let current = port, !CFMachPortIsValid(current) {
                if let old = source { CFRunLoopRemoveSource(loop, old, .commonModes) }
                source = nil
                port = nil
            }
            if port == nil {
                port = CGEvent.tapCreate(tap: .cgSessionEventTap,
                    place: .headInsertEventTap, options: .listenOnly,
                    eventsOfInterest: mask, callback: callback,
                    userInfo: Unmanaged.passUnretained(self).toOpaque())
                if let current = port {
                    source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, current, 0)
                    if let source = source { CFRunLoopAddSource(loop, source, .commonModes) }
                    else { CFMachPortInvalidate(current); port = nil }
                }
            }
            if let current = port { CGEvent.tapEnable(tap: current, enable: true) }
            let listening = port.map { CGEvent.tapIsEnabled(tap: $0) } ?? false
            if lastListening != listening {
                lastListening = listening
                let permitted = CGPreflightListenEventAccess()
                NSLog("EasyComp illumination monitor: listening=%d listenAccess=%d", listening ? 1 : 0, permitted ? 1 : 0)
                DispatchQueue.main.async { [weak self] in
                    guard let self = self, !self.terminating else { return }
                    self.touchBarState = listening ? .listening : .accessDenied
                    self.refreshMenu()
                }
            }
            if source != nil {
                CFRunLoopRunInMode(.defaultMode, 1, false)
            } else {
                Thread.sleep(forTimeInterval: 1)
            }
        }
        if let source = source { CFRunLoopRemoveSource(loop, source, .commonModes) }
        if let port = port { CFMachPortInvalidate(port) }
    }

    private func handleIllumination(code: Int, timestamp: TimeInterval) {
        guard illuminationEvents.accept(code: code, timestamp: timestamp) else { return }
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
    func applicationWillTerminate(_ notification: Notification) {
        terminating = true
        pending?.cancel()
        idleTimer?.invalidate()
        helperWatchdog?.cancel()
        activeProcess?.terminate()
        monitorThread?.cancel()
        if let monitor = fallbackMonitor { NSEvent.removeMonitor(monitor) }
        if let monitor = localMonitor { NSEvent.removeMonitor(monitor) }
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }
    @objc private func quitApp() { NSApplication.shared.terminate(nil) }
}

#if !ECZ_TESTS
let application = NSApplication.shared
let delegate = KeyboardLightApp()
application.delegate = delegate
application.setActivationPolicy(.accessory)
application.run()

#endif
