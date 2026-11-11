// Runs against production policy without starting NSApplication or the HID helper.
var checks = 0
func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    checks += 1
    if !condition() { fatalError(message) }
}
for level in 0...10 {
    let current = Double(level) / 10
    check(BacklightPolicy.step(current: current, delta: 0.1) == min(10, level + 1), "brightness up at \(level)")
    check(BacklightPolicy.step(current: current, delta: -0.1) == max(0, level - 1), "brightness down at \(level)")
}
for timeout in [15, 30, 60, 300, 600, 1800] {
    check(!BacklightPolicy.idleOff(powered: true, timeout: timeout, suspended: false, idle: Double(timeout) - 0.01, sinceAdjustment: nil), "before timeout")
    check(BacklightPolicy.idleOff(powered: true, timeout: timeout, suspended: false, idle: Double(timeout), sinceAdjustment: nil), "at timeout")
    check(!BacklightPolicy.idleOff(powered: true, timeout: timeout, suspended: false, idle: 0, sinceAdjustment: nil), "input restores light")
    check(!BacklightPolicy.idleOff(powered: true, timeout: timeout, suspended: false, idle: 9999, sinceAdjustment: 0), "local adjustment restores light")
}
check(!BacklightPolicy.idleOff(powered: false, timeout: 15, suspended: false, idle: 9999, sinceAdjustment: nil), "manual off")
check(!BacklightPolicy.idleOff(powered: true, timeout: 0, suspended: false, idle: 9999, sinceAdjustment: nil), "never")
check(!BacklightPolicy.idleOff(powered: true, timeout: 15, suspended: true, idle: 9999, sinceAdjustment: nil), "sleep handled separately")
for idle: Double? in [nil, .nan, .infinity, -1] {
    check(!BacklightPolicy.idleOff(powered: true, timeout: 15, suspended: false, idle: idle, sinceAdjustment: nil), "invalid idle sample")
}
// Validate the all-input CGEventType bridge used on this host, without capturing events.
check(CGEventType(rawValue: UInt32.max) != nil, "Quartz all-input constant must bridge")
for brightness in [0.1, 0.3, 0.7, 1.0] {
    check(BacklightPolicy.effectiveLevel(powered: true, brightness: brightness, idleOff: false, sleeping: false, sessionActive: true) == brightness, "exact restoration")
    check(BacklightPolicy.effectiveLevel(powered: true, brightness: brightness, idleOff: true, sleeping: false, sessionActive: true) == 0, "idle off")
    for sleeping in [false, true] {
        for active in [false, true] {
            check(BacklightPolicy.effectiveLevel(powered: false, brightness: brightness, idleOff: false, sleeping: sleeping, sessionActive: active) == 0, "manual off survives wake/session")
        }
    }
}
var events = IlluminationEvents()
check(events.accept(code: 21, timestamp: 10), "first event")
check(!events.accept(code: 21, timestamp: 10), "duplicate tap/global delivery")
check(events.accept(code: 21, timestamp: 10.01), "fast repeat must survive")
check(events.accept(code: 22, timestamp: 10), "different key")
check(!events.accept(code: 21, timestamp: 10), "delayed duplicate must be suppressed")
check(!events.accept(code: 1, timestamp: 12), "unrelated key")
check(!events.accept(code: 21, timestamp: .nan), "invalid timestamp")
var writes = BacklightWrites()
let first = writes.begin(level: 0.5)!
check(writes.begin(level: 0.8) == nil, "no concurrent helper")
check(writes.begin(level: 0) == nil, "off supersedes queued on")
check(writes.complete(level: 0.5, generation: first, succeeded: true), "pending intent must be reevaluated")
let off = writes.begin(level: 0)!
check(!writes.complete(level: 0, generation: off, succeeded: true), "queue drained")
check(writes.begin(level: 0) == nil, "identical successful target needs no write")
writes.invalidate()
let waking = writes.begin(level: 0)!
writes.invalidate()
check(!writes.complete(level: 0, generation: waking, succeeded: true), "old completion")
let retry = writes.begin(level: 0)
check(retry != nil, "old completion must not suppress post-wake write")
check(!writes.complete(level: 0, generation: retry!, succeeded: false), "failed write completion")
check(writes.begin(level: 0) != nil, "failed write may be retried")
print("\(checks) Swift runtime assertions passed; no app or HID helper launched.")
