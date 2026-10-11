import Foundation

/// The prediction game and its companions (Ask Emily, circuit guide, driver
/// of the day). Shipped in 1.2.0; kept as a single switch so it can be
/// turned off again quickly if a server side breaks.
enum GameFeature {
    static let isEnabled = true
}

/// One player's picks for one grand prix. Drivers are Jolpica driver ids
/// (e.g. "norris"), so picks map straight onto results.
struct Prediction: Equatable, Codable {
    var round: String
    var pole: String?
    var p1: String?
    var p2: String?
    var p3: String?
    var fastestLap: String?
    var wildcard: String?
    /// Sprint weekends only.
    var sprintWinner: String?
    var hasSprint = false

    init(round: String, hasSprint: Bool = false) {
        self.round = round
        self.hasSprint = hasSprint
    }

    var podium: [String?] { [p1, p2, p3] }

    /// The groups this weekend has, in lock order.
    var groups: [PickGroup] { hasSprint ? [.sprint, .quali, .race] : [.quali, .race] }

    var isComplete: Bool {
        groups.allSatisfy(isComplete)
    }

    func isComplete(_ group: PickGroup) -> Bool {
        switch group {
        case .sprint: sprintWinner != nil
        case .quali: pole != nil
        case .race: [p1, p2, p3, fastestLap, wildcard].allSatisfy { $0 != nil }
        }
    }

    /// Copies one group's picks from another prediction (keeps the rest).
    mutating func take(_ group: PickGroup, from other: Prediction) {
        switch group {
        case .sprint: sprintWinner = other.sprintWinner
        case .quali: pole = other.pole
        case .race: (p1, p2, p3, fastestLap, wildcard) = (other.p1, other.p2, other.p3, other.fastestLap, other.wildcard)
        }
    }
}

/// Picks lock in groups, each at the start of its session: the sprint
/// winner (sprint weekends), pole at qualifying, the rest at the race.
enum PickGroup: String, CaseIterable {
    case sprint, quali, race

    /// "the sprint" / "qualifying" / "the race", as players read it.
    var sessionName: String {
        switch self {
        case .sprint: "the sprint"
        case .quali: "qualifying"
        case .race: "the race"
        }
    }
}

/// This weekend's extra question. Every answer can be resolved from the
/// results data alone, so scoring never needs a human.
enum Wildcard: String, CaseIterable {
    case poleSitterWins
    case retirements
    case winningMargin

    struct Answer: Identifiable, Equatable {
        let id: String
        let label: String
    }

    /// Rotates by round, so everyone gets the same question.
    static func forRound(_ round: Int) -> Wildcard {
        allCases[(max(round, 1) - 1) % allCases.count]
    }

    var question: String {
        switch self {
        case .poleSitterWins: "Will the pole-sitter win?"
        case .retirements: "How many cars fail to finish?"
        case .winningMargin: "Winning margin over 5 seconds?"
        }
    }

    var answers: [Answer] {
        switch self {
        case .poleSitterWins, .winningMargin:
            [Answer(id: "yes", label: "Yes"), Answer(id: "no", label: "No")]
        case .retirements:
            [Answer(id: "0-1", label: "0–1"), Answer(id: "2-3", label: "2–3"), Answer(id: "4+", label: "4+")]
        }
    }

    func label(for answerId: String?) -> String? {
        answers.first { $0.id == answerId }?.label
    }

    /// The correct answer id, or nil while the data isn't there yet.
    func resolve(qualifying: [QualifyingResult], race: [RaceResult]) -> String? {
        guard !race.isEmpty else { return nil }
        switch self {
        case .poleSitterWins:
            guard let pole = qualifying.first(where: { $0.position == "1" })?.driver.driverId,
                  let winner = race.first(where: { $0.position == "1" })?.driver.driverId else { return nil }
            return pole == winner ? "yes" : "no"
        case .retirements:
            let out = race.filter { !$0.finished }.count
            return out <= 1 ? "0-1" : out <= 3 ? "2-3" : "4+"
        case .winningMargin:
            guard let second = race.first(where: { $0.position == "2" }) else { return nil }
            // P2's time is the gap ("+5.123"); a lapped P2 has no time at all.
            guard let gap = second.time?.time else { return "yes" }
            let seconds = Double(gap.trimmingCharacters(in: CharacterSet(charactersIn: "+s"))) ?? 0
            return seconds > 5 ? "yes" : "no"
        }
    }
}

/// Points per pick. One place, so the values are easy to tune.
enum GameRules {
    static let pole = 5
    static let winner = 10
    static let second = 6
    static let third = 6
    static let podiumWrongSlot = 2
    static let perfectPodium = 10
    static let fastestLap = 5
    static let wildcard = 5
    /// Sprint weekends only, on top of the regular maximum.
    static let sprintWinner = 5

    static let maximum = pole + winner + second + third + perfectPodium + fastestLap + wildcard

    /// Each pick locks when the session it predicts starts: pole at
    /// qualifying, everything else at the race.
    static func lockDate(for race: Race, group: PickGroup) -> Date? {
        switch group {
        case .sprint: race.sessions.first { $0.kind == .sprint }?.date
        case .quali: race.sessions.first { $0.kind == .qualifying }?.date
        case .race: race.startDate
        }
    }

    static func score(_ prediction: Prediction, wildcard: Wildcard,
                      qualifying: [QualifyingResult], race: [RaceResult],
                      sprint: [RaceResult] = []) -> ScoreBreakdown {
        var items: [ScoreBreakdown.Item] = []
        if prediction.hasSprint || prediction.sprintWinner != nil {
            let winner = sprint.first { $0.position == "1" }?.driver.driverId
            let hit = prediction.sprintWinner != nil && prediction.sprintWinner == winner
            items.append(.init(kind: .sprint, picked: prediction.sprintWinner, actual: winner,
                               points: hit ? sprintWinner : 0, outcome: hit ? .exact : .miss))
        }
        let poleId = qualifying.first { $0.position == "1" }?.driver.driverId
        let podium = (1...3).map { p in race.first { $0.position == String(p) }?.driver.driverId }

        items.append(.init(kind: .pole, picked: prediction.pole, actual: poleId,
                           points: prediction.pole != nil && prediction.pole == poleId ? pole : 0,
                           outcome: prediction.pole != nil && prediction.pole == poleId ? .exact : .miss))

        let slotPoints = [winner, second, third]
        let slotKinds: [ScoreBreakdown.Kind] = [.p1, .p2, .p3]
        for (i, pick) in prediction.podium.enumerated() {
            let actual = podium[i]
            let outcome: ScoreBreakdown.Outcome
            let points: Int
            if let pick, pick == actual {
                (outcome, points) = (.exact, slotPoints[i])
            } else if let pick, podium.contains(pick) {
                (outcome, points) = (.partial, podiumWrongSlot)
            } else {
                (outcome, points) = (.miss, 0)
            }
            items.append(.init(kind: slotKinds[i], picked: pick, actual: actual, points: points, outcome: outcome))
        }
        if prediction.podium.allSatisfy({ $0 != nil }), prediction.podium == podium.map(Optional.some) {
            items.append(.init(kind: .perfectPodium, picked: nil, actual: nil, points: perfectPodium, outcome: .exact))
        }

        let fastest = race.first { $0.hasFastestLap }?.driver.driverId
        let fastHit = prediction.fastestLap != nil && prediction.fastestLap == fastest
        items.append(.init(kind: .fastestLap, picked: prediction.fastestLap, actual: fastest,
                           points: fastHit ? fastestLap : 0, outcome: fastHit ? .exact : .miss))

        let answer = wildcard.resolve(qualifying: qualifying, race: race)
        let wildHit = prediction.wildcard != nil && prediction.wildcard == answer
        items.append(.init(kind: .wildcard, picked: prediction.wildcard, actual: answer,
                           points: wildHit ? self.wildcard : 0, outcome: wildHit ? .exact : .miss))

        return ScoreBreakdown(items: items)
    }
}

struct ScoreBreakdown: Equatable {
    enum Kind: String {
        case sprint, pole, p1, p2, p3, perfectPodium, fastestLap, wildcard

        var label: String {
            switch self {
            case .sprint: "SPRINT WINNER"
            case .pole: "POLE"
            case .p1: "WINNER · P1"
            case .p2: "P2"
            case .p3: "P3"
            case .perfectPodium: "PERFECT PODIUM"
            case .fastestLap: "FASTEST LAP"
            case .wildcard: "WILDCARD"
            }
        }
    }

    enum Outcome { case exact, partial, miss }

    struct Item: Equatable, Identifiable {
        let kind: Kind
        let picked: String?
        let actual: String?
        let points: Int
        let outcome: Outcome
        var id: String { kind.rawValue }
    }

    let items: [Item]

    var total: Int { items.reduce(0) { $0 + $1.points } }
    var exactPicks: Int { items.filter { $0.outcome == .exact && $0.kind != .perfectPodium }.count }
}
