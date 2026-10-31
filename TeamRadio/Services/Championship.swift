import SwiftUI

/// The season's world champion, once the drivers' title is settled.
struct Champion {
    let season: String
    let standing: DriverStanding
    /// Points ahead of the runner-up.
    let ahead: Int
}

/// Works out the drivers' title the way the server does for its "World
/// Champion" push, so the app and the push agree: settled once no rival can
/// catch the leader in the races left (25 points a race, 8 more on a sprint
/// weekend); level on points, the driver with more wins takes it.
enum Championship {
    /// The champion, or nil while the title is open (or the data isn't there).
    static func load() async -> Champion? {
        async let table = try? F1API.driversTable()
        async let calendar = try? F1API.season()
        guard let table = await table, let calendar = await calendar,
              let season = table.season, let round = table.round.flatMap(Int.init),
              let drivers = table.driverStandings, let leader = drivers.first, drivers.count > 1 else { return nil }
        let left = calendar.filter { (Int($0.round) ?? 0) > round }
        let points = { (d: DriverStanding) in Double(d.points) ?? 0 }
        let wins = { (d: DriverStanding) in Int(d.wins) ?? 0 }
        #if DEBUG
        // -ChampionDemo YES: today's leader as champion, for screenshots
        let demo = UserDefaults.standard.bool(forKey: "ChampionDemo")
        #else
        let demo = false
        #endif
        guard demo || decided(drivers.map { (points($0), wins($0)) },
                              left: left.reduce(0) { $0 + ($1.sprint == nil ? 25 : 33) }, racesLeft: left.count)
        else { return nil }
        return Champion(season: season, standing: leader, ahead: Int(points(leader) - points(drivers[1])))
    }

    /// Nobody can catch the leader (first) with `left` points and `racesLeft` races to go.
    static func decided(_ drivers: [(points: Double, wins: Int)], left: Double, racesLeft: Int) -> Bool {
        guard let leader = drivers.first, drivers.count > 1 else { return false }
        return drivers.dropFirst().allSatisfy { rival in
            let gap = leader.points - rival.points
            return gap > left || (gap == left && leader.wins > rival.wins + racesLeft)
        }
    }

    /// The title moment shows once per season (and not in spoiler mode).
    private static let seenKey = "championMomentSeen"

    static func shouldCelebrate(_ champion: Champion) -> Bool {
        UserDefaults.standard.string(forKey: seenKey) != champion.season
            && !UserDefaults.standard.bool(forKey: "spoilerMode")
    }

    static func celebrated(_ champion: Champion) {
        UserDefaults.standard.set(champion.season, forKey: seenKey)
    }
}

extension EnvironmentValues {
    /// Set by the root view once the title is settled.
    @Entry var champion: Champion? = nil
}
