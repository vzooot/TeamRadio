import Foundation
import Observation

/// Who a profile sheet is about.
enum ProfileTarget: Identifiable, Hashable {
    case driver(String)
    case team(String)

    var id: String {
        switch self {
        case .driver(let id): "driver-\(id)"
        case .team(let id): "team-\(id)"
        }
    }
}

/// One cell of the per-round results strip.
struct RoundResult: Identifiable {
    let round: Int
    let label: String        // "P1", "P12", "DNF", "DSQ"
    let isWin: Bool
    let isPodium: Bool
    let isRetirement: Bool
    var id: Int { round }
}

@Observable
@MainActor
final class DriverProfileModel {
    let driverId: String
    var standing: DriverStanding?
    var driver: Driver?
    var leaderGap: Double?
    var rounds: [RoundResult] = []
    var podiums = 0
    var poles = 0
    var dnfs = 0
    var firstEntry: Race?
    var firstWin: Race?
    var careerStarts = 0
    var careerWins = 0
    var isLoading = true
    var failed = false

    init(driverId: String) { self.driverId = driverId }

    func load() async {
        defer { isLoading = false }
        do {
            async let standings = F1API.driverStandings(limit: 40)
            async let results = F1API.driverSeasonResults(driverId)
            async let qualifying = F1API.driverSeasonQualifying(driverId)
            let (table, races, quali) = try await (standings, results, qualifying)
            standing = table.first { $0.id == driverId }
            if let leader = Double(table.first?.points ?? ""), let mine = Double(standing?.points ?? "") {
                leaderGap = leader - mine
            }
            let myResults = races.compactMap { race in race.results?.first.map { (race, $0) } }
            driver = myResults.first?.1.driver ?? standing?.driver
            rounds = myResults.map { race, r in
                RoundResult(round: race.roundNumber,
                            label: r.finished ? "P\(r.position)" : (r.positionText == "D" ? "DSQ" : "DNF"),
                            isWin: r.position == "1" && r.finished,
                            isPodium: (Int(r.position) ?? 99) <= 3 && r.finished,
                            isRetirement: !r.finished)
            }
            podiums = rounds.filter(\.isPodium).count
            dnfs = rounds.filter(\.isRetirement).count
            poles = quali.filter { $0.qualifyingResults?.first?.position == "1" }.count
        } catch {
            failed = standing == nil
        }
        // Career facts are a bonus; the sheet stands without them.
        if let start = try? await F1API.driverCareerStart(driverId) {
            firstEntry = start.first
            careerStarts = start.starts
        }
        if let wins = try? await F1API.driverWins(driverId) {
            firstWin = wins.first
            careerWins = wins.wins
        }
    }
}

@Observable
@MainActor
final class TeamProfileModel {
    let teamId: String
    var standing: ConstructorStanding?
    var constructor: Constructor?
    var leaderGap: Double?
    var drivers: [DriverStanding] = []
    var podiums = 0
    var poles = 0
    var isLoading = true
    var failed = false

    init(teamId: String) { self.teamId = teamId }

    func load() async {
        defer { isLoading = false }
        do {
            async let teams = F1API.constructorStandings(limit: 20)
            async let driverTable = F1API.driverStandings(limit: 40)
            async let results = F1API.constructorSeasonResults(teamId)
            async let qualifying = F1API.constructorSeasonQualifying(teamId)
            let (table, driverRows, races, quali) = try await (teams, driverTable, results, qualifying)
            standing = table.first { $0.id == teamId }
            constructor = races.first?.results?.first?.constructor ?? standing?.constructor
            if let leader = Double(table.first?.points ?? ""), let mine = Double(standing?.points ?? "") {
                leaderGap = leader - mine
            }
            drivers = driverRows.filter { $0.teamId == teamId }
            podiums = races.reduce(0) { total, race in
                total + (race.results ?? []).filter { (Int($0.position) ?? 99) <= 3 && $0.finished }.count
            }
            poles = quali.filter { race in race.qualifyingResults?.contains { $0.position == "1" } ?? false }.count
        } catch {
            failed = standing == nil
        }
    }
}

/// Facts the API doesn't carry: where each team is based.
enum TeamFacts {
    static let base: [String: String] = [
        "mercedes": "Brackley, United Kingdom",
        "ferrari": "Maranello, Italy",
        "mclaren": "Woking, United Kingdom",
        "red_bull": "Milton Keynes, United Kingdom",
        "aston_martin": "Silverstone, United Kingdom",
        "alpine": "Enstone, United Kingdom",
        "williams": "Grove, United Kingdom",
        "rb": "Faenza, Italy",
        "haas": "Kannapolis, United States",
        "audi": "Hinwil, Switzerland",
        "cadillac": "Fishers, United States",
    ]
}
