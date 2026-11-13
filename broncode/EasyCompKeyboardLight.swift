// EasyComp Keyboard Light v1.2.1-dev.1
// Native menu bar utility for compatible headless Intel T2 MacBooks.
// HID hardware control is delegated to the separately verified C helper.
import AppKit
import CoreGraphics
import Foundation
import Darwin
import CryptoKit

// Updates trust this repository over HTTPS, not arbitrary URLs or release text.
// GitHub's asset digest checks downloaded bytes; ad-hoc signing is not publisher authentication.
struct UpdateVersion: Comparable, Equatable {
    let parts: [Int]
    init?(_ text: String) {
        let value = text.hasPrefix("v") ? String(text.dropFirst()) : text
        let fields = value.split(separator: ".", omittingEmptySubsequences: false)
        guard fields.count == 3, fields.allSatisfy({ !$0.isEmpty && $0.count <= 8 && $0.allSatisfy({ $0.isASCII && $0.isNumber }) }),
              fields.allSatisfy({ $0.count == 1 || $0.first != "0" }) else { return nil }
        parts = fields.compactMap { Int($0) }
        if parts.count != 3 { return nil }
    }
    static func < (a: Self, b: Self) -> Bool { a.parts.lexicographicallyPrecedes(b.parts) }
}

struct UpdateRelease: Decodable {
    struct Asset: Decodable {
        let name: String
        let browser_download_url: String
        let digest: String?
        let size: Int
        let state: String
    }
    let tag_name: String
    let draft: Bool
    let prerelease: Bool
    let assets: [Asset]
    static let repository = "EasyCompZLD/EasyComp-Keyboard-Light---For-headless-Apple-MacBook-Pro-s-with-T2-Chip"
    static let archiveName = "EasyComp-Keyboard-Light.zip"
    static let maxBytes = 64 * 1024 * 1024
    var candidate: Asset? {
        let matches = assets.filter { $0.name == Self.archiveName }
        guard !draft, !prerelease, tag_name.hasPrefix("v"), UpdateVersion(tag_name) != nil,
              matches.count == 1, let asset = matches.first, asset.state == "uploaded",
              asset.size > 0, asset.size <= Self.maxBytes,
              asset.browser_download_url == "https://github.com/\(Self.repository)/releases/download/\(tag_name)/\(Self.archiveName)",
              let digest = asset.digest, digest.hasPrefix("sha256:"), digest.count == 71,
              digest.dropFirst(7).allSatisfy({ "0123456789abcdef".contains($0) }) else { return nil }
        return asset
    }
    func isNewer(than installed: String) -> Bool {
        let fields = installed.split(separator: "-", maxSplits: 1)
        guard let local = fields.first.flatMap({ UpdateVersion(String($0)) }),
              let remote = UpdateVersion(tag_name), candidate != nil else { return false }
        return remote > local || (remote == local && fields.count == 2)
    }
}

enum UpdateFailure: Error { case invalidRelease, invalidArchive, invalidBundle, processFailed }

// Check ZIP central directory paths, types and expansion limits before extraction.
// Symlinks, traversal, duplicate paths, ZIP64 and encrypted archives are rejected.
enum UpdateArchive {
    static func validate(_ data: Data) throws {
        let bytes = [UInt8](data)
        func number(_ offset: Int, _ count: Int) throws -> Int {
            guard offset >= 0, offset + count <= bytes.count else { throw UpdateFailure.invalidArchive }
            return (0..<count).reduce(0) { $0 | (Int(bytes[offset + $1]) << (8 * $1)) }
        }
        guard bytes.count >= 22 else { throw UpdateFailure.invalidArchive }
        var end: Int?
        for i in stride(from: bytes.count - 22, through: max(0, bytes.count - 65557), by: -1) {
            if try number(i, 4) == 0x06054b50, i + 22 + (try number(i + 20, 2)) == bytes.count { end = i; break }
        }
        guard let e = end, try number(e + 4, 4) == 0 else { throw UpdateFailure.invalidArchive }
        let count = try number(e + 10, 2)
        var offset = try number(e + 16, 4)
        let directoryEnd = offset + (try number(e + 12, 4))
        guard count > 0, count <= 4096, try number(e + 8, 2) == count, directoryEnd == e else { throw UpdateFailure.invalidArchive }
        var paths = Set<String>(), expanded = 0
        for _ in 0..<count {
            guard try number(offset, 4) == 0x02014b50, try number(offset + 8, 2) & 1 == 0,
                  [0, 8].contains(try number(offset + 10, 2)), try number(offset + 34, 2) == 0 else { throw UpdateFailure.invalidArchive }
            let nameLength = try number(offset + 28, 2)
            let size = try number(offset + 24, 4)
            let mode = (try number(offset + 38, 4)) >> 16
            let type = mode & 0xf000
            guard [0, 0x8000, 0x4000].contains(type), size < 128 * 1024 * 1024,
                  offset + 46 + nameLength <= directoryEnd else { throw UpdateFailure.invalidArchive }
            let nameBytes = bytes[(offset + 46)..<(offset + 46 + nameLength)]
            guard let path = String(bytes: nameBytes, encoding: .utf8),
                  !path.contains("\\"), !path.contains("\0"), !path.contains("\n"), !path.contains("\r"),
                  path.hasPrefix("EasyComp Keyboard Light Setup.app/"),
                  path.split(separator: "/", omittingEmptySubsequences: false).allSatisfy({ $0 != "." && $0 != ".." }),
                  paths.insert(path).inserted else { throw UpdateFailure.invalidArchive }
            expanded += size
            guard expanded <= 128 * 1024 * 1024 else { throw UpdateFailure.invalidArchive }
            // Local header must name the same entry: extraction must not see different paths.
            let local = try number(offset + 42, 4)
            let localNameLength = try number(local + 26, 2)
            let localExtra = try number(local + 28, 2)
            let compressed = try number(offset + 20, 4)
            guard try number(local, 4) == 0x04034b50, localNameLength == nameLength,
                  local + 30 + localNameLength + localExtra + compressed <= (try number(e + 16, 4)),
                  bytes[(local + 30)..<(local + 30 + localNameLength)].elementsEqual(nameBytes),
                  try number(local + 6, 2) == number(offset + 8, 2),
                  try number(local + 8, 2) == number(offset + 10, 2) else { throw UpdateFailure.invalidArchive }
            offset += 46 + nameLength + (try number(offset + 30, 2)) + (try number(offset + 32, 2))
        }
        guard offset == directoryEnd else { throw UpdateFailure.invalidArchive }
    }
}

private final class UpdateRedirects: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        let allowed = request.url?.scheme == "https" && ["github.com", "release-assets.githubusercontent.com"].contains(request.url?.host ?? "")
        completionHandler(allowed ? request : nil)
    }
}

enum GitHubUpdater {
    struct Staged { let workspace: URL; let app: URL; let version: String }
    static func validateDownload(_ data: Data, asset: UpdateRelease.Asset) throws {
        let digest = "sha256:" + SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        guard data.count == asset.size, data.count <= UpdateRelease.maxBytes, digest == asset.digest else { throw UpdateFailure.invalidArchive }
        try UpdateArchive.validate(data)
    }
    private static func run(_ executable: String, _ arguments: [String]) throws {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: executable)
        task.arguments = arguments
        task.standardInput = FileHandle.nullDevice
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        try task.run()
        let deadline = Date().addingTimeInterval(30)
        while task.isRunning && Date() < deadline { Thread.sleep(forTimeInterval: 0.05) }
        if task.isRunning {
            task.terminate()
            let stopDeadline = Date().addingTimeInterval(2)
            while task.isRunning && Date() < stopDeadline { Thread.sleep(forTimeInterval: 0.05) }
            if task.isRunning { kill(task.processIdentifier, SIGKILL) }
            task.waitUntilExit()
            throw UpdateFailure.processFailed
        }
        guard task.terminationStatus == 0 else { throw UpdateFailure.processFailed }
    }
    static func stage(installed: String) async throws -> Staged? {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 120
        configuration.httpShouldSetCookies = false
        configuration.urlCredentialStorage = nil
        let session = URLSession(configuration: configuration, delegate: UpdateRedirects(), delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        var request = URLRequest(url: URL(string: "https://api.github.com/repos/\(UpdateRelease.repository)/releases/latest")!)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        let (metadata, response) = try await session.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200, metadata.count <= 1024 * 1024 else { throw UpdateFailure.invalidRelease }
        let release = try JSONDecoder().decode(UpdateRelease.self, from: metadata)
        guard release.isNewer(than: installed), let asset = release.candidate else { return nil }
        let (download, downloadResponse) = try await session.download(from: URL(string: asset.browser_download_url)!)
        defer { try? FileManager.default.removeItem(at: download) }
        guard (downloadResponse as? HTTPURLResponse)?.statusCode == 200,
              (try download.resourceValues(forKeys: [.fileSizeKey])).fileSize == asset.size else { throw UpdateFailure.invalidArchive }
        let data = try Data(contentsOf: download)
        try validateDownload(data, asset: asset)
        let workspace = FileManager.default.temporaryDirectory.appendingPathComponent("ecz-update-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        var retained = false
        defer { if !retained { try? FileManager.default.removeItem(at: workspace) } }
        let archive = workspace.appendingPathComponent("update.zip")
        try data.write(to: archive, options: .atomic)
        try run("/usr/bin/ditto", ["-x", "-k", archive.path, workspace.path])
        let app = workspace.appendingPathComponent("EasyComp Keyboard Light Setup.app")
        let version = String(release.tag_name.dropFirst())
        guard let bundle = Bundle(url: app), bundle.bundleIdentifier == "nl.easycompzeeland.KeyboardLight.Setup",
              bundle.object(forInfoDictionaryKey: "ECZAutomaticUpdateProtocol") as? Int == 1,
              bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String == version,
              bundle.object(forInfoDictionaryKey: "ECZDevelopmentVersion") as? String == version else {
            throw UpdateFailure.invalidBundle
        }
        let infoURL = app.appendingPathComponent("Contents/Resources/Project/broncode/Info.plist")
        guard let info = try PropertyListSerialization.propertyList(from: Data(contentsOf: infoURL), format: nil) as? [String: Any],
              info["CFBundleIdentifier"] as? String == "nl.easycompzeeland.KeyboardLight",
              info["CFBundleShortVersionString"] as? String == version,
              info["ECZDevelopmentVersion"] as? String == version else { throw UpdateFailure.invalidBundle }
        try run("/usr/bin/codesign", ["--verify", "--deep", "--strict", app.path])
        retained = true
        return Staged(workspace: workspace, app: app, version: version)
    }
}

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
    private let automaticUpdateItem = NSMenuItem()
    private let checkUpdateItem = NSMenuItem()
    private let updateStatusItem = NSMenuItem()
    private var updateTimer: Timer?
    private var updateTask: Task<Void, Never>?
    private var updateBusy = false
    private var updateStatusKey = "update.ready"
    private var updateGeneration = UUID()
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
        let timer = Timer(timeInterval: 60, repeats: true) { [weak self] _ in self?.checkAutomaticUpdate() }
        updateTimer = timer
        RunLoop.main.add(timer, forMode: .common)
        checkAutomaticUpdate()
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
        automaticUpdateItem.target = self
        automaticUpdateItem.action = #selector(toggleAutomaticUpdates)
        menu.addItem(automaticUpdateItem)
        checkUpdateItem.target = self
        checkUpdateItem.action = #selector(checkUpdatesNow)
        menu.addItem(checkUpdateItem)
        updateStatusItem.isEnabled = false
        menu.addItem(updateStatusItem)

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
        automaticUpdateItem.title = T("update.automatic")
        checkUpdateItem.title = T("update.check")
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
        automaticUpdateItem.state = UserDefaults.standard.bool(forKey: "automaticUpdates") ? .on : .off
        checkUpdateItem.isEnabled = !updateBusy
        updateStatusItem.title = T(updateStatusKey)
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

    @objc private func toggleAutomaticUpdates() {
        let enabled = !UserDefaults.standard.bool(forKey: "automaticUpdates")
        UserDefaults.standard.set(enabled, forKey: "automaticUpdates")
        if enabled {
            UserDefaults.standard.removeObject(forKey: "lastUpdateAttempt")
            checkUpdates(manual: false)
        }
        else {
            updateGeneration = UUID()
            updateTask?.cancel()
            // Keep the operation busy until its cleanup completes, so checks never overlap.
            // After handoff there is no task left: disabling must also unlock manual checks.
            if updateTask == nil { updateBusy = false }
            updateStatusKey = "update.ready"
        }
        refreshTranslations()
    }
    @objc private func checkUpdatesNow() { checkUpdates(manual: true) }
    private func checkAutomaticUpdate() {
        let store = UserDefaults.standard
        guard store.bool(forKey: "automaticUpdates"), !sleeping, sessionActive,
              Date().timeIntervalSince(store.object(forKey: "lastUpdateAttempt") as? Date ?? .distantPast) >= 3600 else { return }
        checkUpdates(manual: false)
    }
    private func checkUpdates(manual: Bool) {
        guard !updateBusy, !terminating else { return }
        updateBusy = true
        updateStatusKey = "update.checking"
        let generation = UUID()
        updateGeneration = generation
        UserDefaults.standard.set(Date(), forKey: "lastUpdateAttempt")
        let installed = Bundle.main.object(forInfoDictionaryKey: "ECZDevelopmentVersion") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        refreshTranslations()
        updateTask = Task { @MainActor [weak self] in
            do {
                let staged = try await GitHubUpdater.stage(installed: installed)
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { if let staged = staged { try? FileManager.default.removeItem(at: staged.workspace) }; return }
                    self.updateTask = nil
                    self.updateBusy = false
                    guard self.updateGeneration == generation, !self.terminating else {
                        if let staged = staged { try? FileManager.default.removeItem(at: staged.workspace) }; return
                    }
                    guard let staged = staged else { self.updateStatusKey = "update.current"; self.refreshTranslations(); return }
                    guard manual || (UserDefaults.standard.bool(forKey: "automaticUpdates") && !self.sleeping && self.sessionActive) else {
                        try? FileManager.default.removeItem(at: staged.workspace)
                        self.updateStatusKey = "update.ready"; self.refreshTranslations(); return
                    }
                    if manual {
                        let alert = NSAlert()
                        alert.messageText = String(format: self.T("update.available"), staged.version)
                        alert.informativeText = self.T("update.installBody")
                        alert.addButton(withTitle: self.T("update.install"))
                        alert.addButton(withTitle: self.T("update.later"))
                        if alert.runModal() != .alertFirstButtonReturn {
                            try? FileManager.default.removeItem(at: staged.workspace)
                            self.updateStatusKey = "update.ready"; self.refreshTranslations(); return
                        }
                    }
                    guard self.updateGeneration == generation, !self.terminating, !self.sleeping, self.sessionActive,
                          manual || UserDefaults.standard.bool(forKey: "automaticUpdates") else {
                        try? FileManager.default.removeItem(at: staged.workspace)
                        self.updateStatusKey = "update.ready"; self.refreshTranslations(); return
                    }
                    self.updateBusy = true
                    self.updateStatusKey = "update.installing"
                    self.refreshTranslations()
                    let configuration = NSWorkspace.OpenConfiguration()
                    configuration.createsNewApplicationInstance = true
                    configuration.arguments = [manual ? "--confirmed-update" : "--automatic-update",
                                               "--update-version=" + staged.version,
                                               "--update-language=" + LanguageManager.shared.effectiveCode]
                    NSWorkspace.shared.openApplication(at: staged.app, configuration: configuration) { [weak self] _, error in
                        DispatchQueue.main.async {
                            guard let self = self else { return }
                            if error != nil {
                                try? FileManager.default.removeItem(at: staged.workspace)
                                self.updateBusy = false; self.updateStatusKey = "update.failed"; self.refreshTranslations()
                            }
                        }
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 60) { [weak self] in
                        guard let self = self, self.updateGeneration == generation, self.updateBusy else { return }
                        // A successful installer stops this process. If it is still here, permit retry.
                        self.updateBusy = false; self.updateStatusKey = "update.failed"; self.refreshTranslations()
                    }
                }
            } catch {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.updateTask = nil; self.updateBusy = false
                    if self.updateGeneration == generation { self.updateStatusKey = "update.failed" }
                    self.refreshTranslations()
                    NSLog("EasyComp update check/download failed; installed app retained")
                }
            }
        }
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
        updateGeneration = UUID()
        updateTask?.cancel()
        updateTimer?.invalidate()
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
