import Foundation

// MARK: - Ergast/Jolpica response envelope

struct ErgastResponse: Decodable {
    let mrData: MRData

    enum CodingKeys: String, CodingKey {
        case mrData = "MRData"
    }
}

struct MRData: Decodable {
    let raceTable: RaceTable?
    let standingsTable: StandingsTable?

    enum CodingKeys: String, CodingKey {
        case raceTable = "RaceTable"
        case standingsTable = "StandingsTable"
    }
}

struct RaceTable: Decodable {
    let season: String?
    let races: [Race]

    enum CodingKeys: String, CodingKey {
        case season
        case races = "Races"
    }
}

struct StandingsTable: Decodable {
    let standingsLists: [StandingsList]

    enum CodingKeys: String, CodingKey {
        case standingsLists = "StandingsLists"
    }
}

struct StandingsList: Decodable {
    let round: String?
    let driverStandings: [DriverStanding]?
    let constructorStandings: [ConstructorStanding]?

    enum CodingKeys: String, CodingKey {
        case round
        case driverStandings = "DriverStandings"
        case constructorStandings = "ConstructorStandings"
    }
}

// MARK: - Race & sessions

struct Race: Decodable, Identifiable, Equatable {
    let season: String
    let round: String
    let raceName: String
    let circuit: Circuit
    let date: String
    let time: String?
    let firstPractice: SessionTime?
    let secondPractice: SessionTime?
    let thirdPractice: SessionTime?
    let qualifying: SessionTime?
    let sprint: SessionTime?
    let sprintQualifying: SessionTime?
    /// Present only on the results/qualifying/sprint endpoints.
    let results: [RaceResult]?
    let qualifyingResults: [QualifyingResult]?
    let sprintResults: [RaceResult]?

    enum CodingKeys: String, CodingKey {
        case season, round, raceName, date, time
        case circuit = "Circuit"
        case firstPractice = "FirstPractice"
        case secondPractice = "SecondPractice"
        case thirdPractice = "ThirdPractice"
        case qualifying = "Qualifying"
        case sprint = "Sprint"
        case sprintQualifying = "SprintQualifying"
        case results = "Results"
        case qualifyingResults = "QualifyingResults"
        case sprintResults = "SprintResults"
    }

    var id: String { "\(season)-\(round)" }

    var roundNumber: Int { Int(round) ?? 0 }

    /// The weekend is over (its last session has started).
    var isPast: Bool {
        guard let last = sessions.last else { return false }
        return last.date <= .now
    }

    /// UTC start of the grand prix itself.
    var startDate: Date? { ErgastDate.parse(date: date, time: time) }

    var isSprintWeekend: Bool { sprint != nil || sprintQualifying != nil }

    /// All weekend sessions in chronological order, race included.
    var sessions: [WeekendSession] {
        var items: [WeekendSession] = []
        func add(_ kind: WeekendSession.Kind, _ st: SessionTime?) {
            guard let st, let d = ErgastDate.parse(date: st.date, time: st.time) else { return }
            items.append(WeekendSession(kind: kind, date: d))
        }
        add(.practice1, firstPractice)
        add(.practice2, secondPractice)
        add(.practice3, thirdPractice)
        add(.sprintQualifying, sprintQualifying)
        add(.sprint, sprint)
        add(.qualifying, qualifying)
        if let d = startDate {
            items.append(WeekendSession(kind: .race, date: d))
        }
        return items.sorted { $0.date < $1.date }
    }

    static func == (lhs: Race, rhs: Race) -> Bool { lhs.id == rhs.id }
}

struct SessionTime: Decodable {
    let date: String
    let time: String?
}

struct WeekendSession: Identifiable {
    enum Kind: String {
        case practice1 = "Practice 1"
        case practice2 = "Practice 2"
        case practice3 = "Practice 3"
        case sprintQualifying = "Sprint Quali"
        case sprint = "Sprint"
        case qualifying = "Qualifying"
        case race = "Race"

        var short: String {
            switch self {
            case .practice1: "FP1"
            case .practice2: "FP2"
            case .practice3: "FP3"
            case .sprintQualifying: "SQ"
            case .sprint: "SPR"
            case .qualifying: "Q"
            case .race: "RACE"
            }
        }

        /// Rough session length, used to decide when a session counts as live.
        var expectedDuration: TimeInterval {
            switch self {
            case .race: 2 * 3600
            default: 3600
            }
        }
    }

    let kind: Kind
    let date: Date
    var id: String { kind.rawValue }
}

struct Circuit: Decodable {
    let circuitId: String
    let circuitName: String
    let url: String?
    let location: CircuitLocation

    enum CodingKeys: String, CodingKey {
        case circuitId, circuitName, url
        case location = "Location"
    }
}

struct CircuitLocation: Decodable {
    let lat: String?
    let long: String?
    let locality: String
    let country: String
}

// MARK: - Standings

struct DriverStanding: Decodable, Identifiable {
    let position: String
    let points: String
    let wins: String
    let driver: Driver
    let constructors: [Constructor]

    enum CodingKeys: String, CodingKey {
        case position, points, wins
        case driver = "Driver"
        case constructors = "Constructors"
    }

    var id: String { driver.driverId }
    var teamId: String? { constructors.first?.constructorId }
    var teamName: String { constructors.first?.name ?? "—" }
}

struct Driver: Decodable {
    let driverId: String
    let permanentNumber: String?
    let code: String?
    let givenName: String
    let familyName: String

    var shortCode: String { code ?? String(familyName.prefix(3)).uppercased() }
}

struct Constructor: Decodable {
    let constructorId: String
    let name: String
}

struct ConstructorStanding: Decodable, Identifiable {
    let position: String
    let points: String
    let wins: String
    let constructor: Constructor

    enum CodingKeys: String, CodingKey {
        case position, points, wins
        case constructor = "Constructor"
    }

    var id: String { constructor.constructorId }
}

// MARK: - Race & qualifying results

struct RaceResult: Decodable, Identifiable {
    let position: String
    let positionText: String
    let points: String
    let driver: Driver
    let constructor: Constructor
    let grid: String
    let laps: String?
    let status: String
    let time: ResultTime?
    let fastestLap: FastestLap?

    enum CodingKeys: String, CodingKey {
        case position, positionText, points, grid, laps, status
        case driver = "Driver"
        case constructor = "Constructor"
        case time = "Time"
        case fastestLap = "FastestLap"
    }

    var id: String { driver.driverId }

    /// Positions gained (+) or lost (−) versus the starting grid.
    /// Nil for pit-lane starts (grid "0").
    var gridDelta: Int? {
        guard let start = Int(grid), start > 0, let finish = Int(position) else { return nil }
        return start - finish
    }

    /// Set the fastest lap of the race.
    var hasFastestLap: Bool { fastestLap?.rank == "1" }

    /// What to show in the gap column: winner's total, gap, or status (DNF etc).
    var gapText: String {
        if let t = time?.time { return t }
        return status.uppercased()
    }

    /// Classified as a finisher — includes cars a lap (or more) down.
    var finished: Bool {
        status == "Finished" || status.hasPrefix("+") || status == "Lapped"
    }
}

struct ResultTime: Decodable {
    let time: String
}

struct FastestLap: Decodable {
    let rank: String?
    let lap: String?
    let time: ResultTime?

    enum CodingKeys: String, CodingKey {
        case rank, lap
        case time = "Time"
    }
}

struct QualifyingResult: Decodable, Identifiable {
    let position: String
    let driver: Driver
    let constructor: Constructor
    let q1: String?
    let q2: String?
    let q3: String?

    enum CodingKeys: String, CodingKey {
        case position
        case driver = "Driver"
        case constructor = "Constructor"
        case q1 = "Q1"
        case q2 = "Q2"
        case q3 = "Q3"
    }

    var id: String { driver.driverId }

    /// Best time set, with the segment it came from.
    var bestTime: (time: String, segment: String)? {
        if let q3 { return (q3, "Q3") }
        if let q2 { return (q2, "Q2") }
        if let q1 { return (q1, "Q1") }
        return nil
    }
}

// MARK: - Date parsing

enum ErgastDate {
    private static let formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    /// Combines Ergast "YYYY-MM-DD" + "HH:mm:ssZ" into a Date. Time defaults to midnight UTC.
    static func parse(date: String, time: String?) -> Date? {
        let t = time ?? "00:00:00Z"
        return formatter.date(from: "\(date)T\(t)")
    }
}
