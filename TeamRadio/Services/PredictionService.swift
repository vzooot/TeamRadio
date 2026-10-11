import CloudKit
import Foundation

/// Picks live in CloudKit's public database next to the chat. Each player
/// has one record per round and lock group: `pred-<round>-<userId>-quali`
/// (pole) and `pred-<round>-<userId>-race` (podium, fastest lap, wildcard).
/// Deterministic names make a second entry impossible rather than merely
/// discouraged.
///
/// Fairness is enforced by the scorer, not here: a group only counts if
/// CloudKit's server-set `modificationDate` is before its session starts.
/// Two records per round mean editing the podium on Saturday night can't
/// void a pole pick locked in before qualifying.
enum PredictionService {
    private static var database: CKDatabase { ChatService.container.publicCloudDatabase }

    private static func recordID(round: String, userId: String, group: PickGroup) -> CKRecord.ID {
        CKRecord.ID(recordName: "pred-\(round)-\(userId)-\(group.rawValue)")
    }

    /// One record for every pick, written by the first test builds.
    private static func legacyID(round: String, userId: String) -> CKRecord.ID {
        CKRecord.ID(recordName: "pred-\(round)-\(userId)")
    }

    struct Saved: Equatable {
        let prediction: Prediction
        /// Groups that have been saved at least once.
        let groups: Set<PickGroup>
    }

    /// The player's own picks for a round, or nil if they haven't picked.
    static func mine(round: String, userId: String) async throws -> Saved? {
        let ids = PickGroup.allCases.map { recordID(round: round, userId: userId, group: $0) }
            + [legacyID(round: round, userId: userId)]
        let results = try await database.records(for: ids, desiredKeys: nil)
        var prediction = Prediction(round: round)
        var groups = Set<PickGroup>()
        if case .success(let record)? = results[legacyID(round: round, userId: userId)] {
            prediction = self.prediction(from: record, round: round)
            groups = [.quali, .race]
        }
        for group in PickGroup.allCases {
            switch results[recordID(round: round, userId: userId, group: group)] {
            case .success(let record)?:
                prediction.take(group, from: self.prediction(from: record, round: round))
                groups.insert(group)
            case .failure(let error as CKError)? where error.code == .unknownItem:
                break
            case .failure(let error)?:
                throw error
            case nil:
                break
            }
        }
        return groups.isEmpty ? nil : Saved(prediction: prediction, groups: groups)
    }

    /// Saves the given groups of `prediction`; other groups are untouched.
    static func save(_ prediction: Prediction, groups: [PickGroup], userId: String, name: String) async throws {
        for group in groups {
            let id = recordID(round: prediction.round, userId: userId, group: group)
            let record: CKRecord
            do {
                record = try await database.record(for: id)
            } catch let error as CKError where error.code == .unknownItem {
                record = CKRecord(recordType: "Prediction", recordID: id)
            }
            record["round"] = prediction.round
            record["userId"] = userId
            record["name"] = name
            record["group"] = group.rawValue
            switch group {
            case .sprint:
                record["sprintWinner"] = prediction.sprintWinner
            case .quali:
                record["pole"] = prediction.pole
            case .race:
                record["p1"] = prediction.p1
                record["p2"] = prediction.p2
                record["p3"] = prediction.p3
                record["fastestLap"] = prediction.fastestLap
                record["wildcard"] = prediction.wildcard
            }
            _ = try await database.save(record)
        }
    }

    private static func prediction(from record: CKRecord, round: String) -> Prediction {
        var p = Prediction(round: round)
        p.pole = record["pole"] as? String
        p.p1 = record["p1"] as? String
        p.p2 = record["p2"] as? String
        p.p3 = record["p3"] as? String
        p.fastestLap = record["fastestLap"] as? String
        p.wildcard = record["wildcard"] as? String
        p.sprintWinner = record["sprintWinner"] as? String
        return p
    }
}
