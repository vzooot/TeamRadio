import CloudKit
import Foundation

/// Picks live in CloudKit's public database next to the chat. One record per
/// player per round, named `pred-<round>-<userId>`, so a second entry is
/// impossible rather than merely discouraged.
///
/// Fairness is enforced by the scorer, not here: a prediction only counts if
/// CloudKit's server-set `modificationDate` is before the lock, so editing
/// after qualifying voids it.
enum PredictionService {
    private static var database: CKDatabase { ChatService.container.publicCloudDatabase }

    private static func recordID(round: String, userId: String) -> CKRecord.ID {
        CKRecord.ID(recordName: "pred-\(round)-\(userId)")
    }

    struct Saved: Equatable {
        let prediction: Prediction
        /// Server time of the last save; nil if the server didn't say.
        let savedAt: Date?
    }

    /// The player's own picks for a round, or nil if they haven't picked.
    static func mine(round: String, userId: String) async throws -> Saved? {
        do {
            let record = try await database.record(for: recordID(round: round, userId: userId))
            return Saved(prediction: prediction(from: record, round: round), savedAt: record.modificationDate)
        } catch let error as CKError where error.code == .unknownItem {
            return nil
        }
    }

    static func save(_ prediction: Prediction, userId: String, name: String) async throws -> Saved {
        let id = recordID(round: prediction.round, userId: userId)
        let record: CKRecord
        do {
            record = try await database.record(for: id)
        } catch let error as CKError where error.code == .unknownItem {
            record = CKRecord(recordType: "Prediction", recordID: id)
        }
        record["round"] = prediction.round
        record["userId"] = userId
        record["name"] = name
        record["pole"] = prediction.pole
        record["p1"] = prediction.p1
        record["p2"] = prediction.p2
        record["p3"] = prediction.p3
        record["fastestLap"] = prediction.fastestLap
        record["wildcard"] = prediction.wildcard
        let saved = try await database.save(record)
        return Saved(prediction: self.prediction(from: saved, round: prediction.round), savedAt: saved.modificationDate)
    }

    private static func prediction(from record: CKRecord, round: String) -> Prediction {
        var p = Prediction(round: round)
        p.pole = record["pole"] as? String
        p.p1 = record["p1"] as? String
        p.p2 = record["p2"] as? String
        p.p3 = record["p3"] as? String
        p.fastestLap = record["fastestLap"] as? String
        p.wildcard = record["wildcard"] as? String
        return p
    }
}
