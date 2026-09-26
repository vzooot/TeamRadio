import Foundation

/// Thin async client for the Jolpica F1 API (the community successor to Ergast).
/// Docs: https://github.com/jolpica/jolpica-f1
enum F1API {
    static let base = URL(string: "https://api.jolpi.ca/ergast/f1")!

    enum APIError: LocalizedError {
        case badResponse(Int)

        var errorDescription: String? {
            switch self {
            case .badResponse(let code): "The F1 API answered with status \(code)."
            }
        }
    }

    private static func fetch(_ path: String, query: [URLQueryItem] = []) async throws -> MRData {
        var components = URLComponents(url: base.appending(path: path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty { components.queryItems = query }
        var request = URLRequest(url: components.url!)
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw APIError.badResponse(http.statusCode)
        }
        return try JSONDecoder().decode(ErgastResponse.self, from: data).mrData
    }

    /// The next grand prix on the calendar, with full weekend session times.
    static func nextRace() async throws -> Race? {
        try await fetch("current/next.json").raceTable?.races.first
    }

    /// The full current-season calendar.
    static func season() async throws -> [Race] {
        try await fetch("current.json", query: [URLQueryItem(name: "limit", value: "30")])
            .raceTable?.races ?? []
    }

    /// Current championship top order.
    static func driverStandings(limit: Int = 5) async throws -> [DriverStanding] {
        try await fetch("current/driverstandings.json", query: [URLQueryItem(name: "limit", value: "\(limit)")])
            .standingsTable?.standingsLists.first?.driverStandings ?? []
    }

    /// Constructors' championship top order.
    static func constructorStandings(limit: Int = 5) async throws -> [ConstructorStanding] {
        try await fetch("current/constructorstandings.json", query: [URLQueryItem(name: "limit", value: "\(limit)")])
            .standingsTable?.standingsLists.first?.constructorStandings ?? []
    }

    /// The most recent completed grand prix, with full classification.
    static func lastRaceResults() async throws -> Race? {
        try await fetch("current/last/results.json").raceTable?.races.first
    }

    /// Full classification for any completed round of the current season.
    static func raceResults(round: String) async throws -> Race? {
        try await fetch("current/\(round)/results.json").raceTable?.races.first
    }

    /// Qualifying classification for any round of the current season.
    static func qualifying(round: String) async throws -> Race? {
        try await fetch("current/\(round)/qualifying.json").raceTable?.races.first
    }

    /// Sprint race classification for a sprint-weekend round.
    static func sprintResults(round: String) async throws -> Race? {
        try await fetch("current/\(round)/sprint.json").raceTable?.races.first
    }

    // MARK: - Profiles

    /// Every race this season with this driver's result (one Results entry per race).
    static func driverSeasonResults(_ driverId: String) async throws -> [Race] {
        try await fetch("current/drivers/\(driverId)/results.json", query: [URLQueryItem(name: "limit", value: "40")])
            .raceTable?.races ?? []
    }

    static func driverSeasonQualifying(_ driverId: String) async throws -> [Race] {
        try await fetch("current/drivers/\(driverId)/qualifying.json", query: [URLQueryItem(name: "limit", value: "40")])
            .raceTable?.races ?? []
    }

    /// The driver's first-ever race, and how many they have entered.
    static func driverCareerStart(_ driverId: String) async throws -> (first: Race?, starts: Int) {
        let data = try await fetch("drivers/\(driverId)/results.json", query: [URLQueryItem(name: "limit", value: "1")])
        return (data.raceTable?.races.first, Int(data.total ?? "") ?? 0)
    }

    /// The driver's first win, and their career win count.
    static func driverWins(_ driverId: String) async throws -> (first: Race?, wins: Int) {
        let data = try await fetch("drivers/\(driverId)/results/1.json", query: [URLQueryItem(name: "limit", value: "1")])
        return (data.raceTable?.races.first, Int(data.total ?? "") ?? 0)
    }

    /// Every race this season with both of this team's results.
    static func constructorSeasonResults(_ constructorId: String) async throws -> [Race] {
        try await fetch("current/constructors/\(constructorId)/results.json", query: [URLQueryItem(name: "limit", value: "100")])
            .raceTable?.races ?? []
    }

    static func constructorSeasonQualifying(_ constructorId: String) async throws -> [Race] {
        try await fetch("current/constructors/\(constructorId)/qualifying.json", query: [URLQueryItem(name: "limit", value: "100")])
            .raceTable?.races ?? []
    }
}

