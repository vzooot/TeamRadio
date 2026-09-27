#if DEBUG
import SwiftUI
import Observation

/// Debug builds only — never compiled into the App Store app.
///
/// Drives the app on a fixed timeline so the marketing video recorder
/// (scripts/video) gets clean, repeatable footage: launch with
/// `-Demo countdown`. Every step is logged with its time to
/// Documents/demo-log.json so the renderer can cut on exact moments.
/// Demo mode never touches real notifications or Live Activities — the
/// pin and alert controls only change what's on screen.
@Observable @MainActor
final class DemoDirector {
    static let shared = DemoDirector()

    struct Scroll: Equatable {
        let target: String
        let anchor: UnitPoint
        let duration: Double
        let seq: Int
    }

    let pass: String? = UserDefaults.standard.string(forKey: "Demo")
    var isActive: Bool { pass != nil }

    var scroll: Scroll?
    var sessionIndex: Int?
    var boardPageSeq = 0
    var boardPageValue = 0
    var pinned: Bool?
    var alertsOn: Bool?

    private var started = false
    private var seq = 0
    private var log: [[String: Any]] = []
    private var t0 = Date()

    private init() {}

    /// Called once the race data has loaded.
    func runIfNeeded() async {
        guard let pass, !started else { return }
        started = true
        try? await Task.sleep(for: .seconds(2.5))      // let weather and the board settle
        t0 = Date()
        mark("start", ["epoch": t0.timeIntervalSince1970])
        switch pass {
        case "countdown": await countdownPass()
        default: break
        }
        mark("end")
    }

    // MARK: - Passes

    /// Countdown tab, top to bottom: hero, start-light board, session chips,
    /// pin, weekend timetable, session alerts, back to the helmet.
    private func countdownPass() async {
        pinned = false
        alertsOn = false
        go("top", .top, 0)
        await at(5);    go("countdown", .center, 1.2)
        await at(6.5);  page(0)
        await at(13);   page(1)                           // the board cycles on by itself from here
        for (i, t) in [21.0, 22.2, 23.4, 24.6, 25.8].enumerated() {
            await at(t); sessionIndex = [1, 2, 3, 4, 0][i]; mark("session", ["index": sessionIndex ?? 0])
        }
        await at(28);   pinned = true; mark("pin")
        await at(31);   go("schedule", .top, 1.5)
        await at(35);   go("alerts", .center, 3)
        await at(39.5); alertsOn = true; mark("alerts")
        await at(43);   go("top", .top, 1.5)
        await at(50)
    }

    // MARK: - Steps

    private func go(_ target: String, _ anchor: UnitPoint, _ duration: Double) {
        seq += 1
        scroll = Scroll(target: target, anchor: anchor, duration: duration, seq: seq)
        mark("scroll", ["target": target, "duration": duration])
    }

    private func page(_ n: Int) {
        boardPageValue = n
        boardPageSeq += 1
        mark("board", ["page": n])
    }

    private func at(_ t: Double) async {
        let wait = t - Date().timeIntervalSince(t0)
        if wait > 0 { try? await Task.sleep(for: .seconds(wait)) }
    }

    private func mark(_ event: String, _ extra: [String: Any] = [:]) {
        var entry = extra
        entry["event"] = event
        entry["t"] = (Date().timeIntervalSince(t0) * 1000).rounded() / 1000
        log.append(entry)
        guard let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
              let data = try? JSONSerialization.data(withJSONObject: log, options: [.prettyPrinted]) else { return }
        try? data.write(to: dir.appendingPathComponent("demo-log.json"))
    }
}
#endif
