import CloudKit
import Foundation

actor CampusService {
    private var container: CKContainer { CKContainer.default() }
    private var database: CKDatabase { container.publicCloudDatabase }
    private func identity() async throws -> String {
        guard try await container.accountStatus() == .available else { throw SquadFailure.account }
        return try await container.userRecordID().recordName
    }
    private func record(day: String) async throws -> CKRecord {
        do { return try await database.record(for: CKRecord.ID(recordName: "campus-yuehai-\(day)")) }
        catch let error as CKError where error.code == .unknownItem {
            return CKRecord(recordType: "CampusDay", recordID: CKRecord.ID(recordName: "campus-yuehai-\(day)"))
        }
    }
    private func decode(_ record: CKRecord, day: String) throws -> CampusBoard {
        guard let payload = record["payload"] as? Data else { return CampusBoard(day: day) }
        return try JSONDecoder().decode(CampusBoard.self, from: payload)
    }
    func load() async throws -> (CampusBoard, String) {
        let user = try await identity(), day = CampusBoard.dayID(Date())
        let record = try await record(day: day)
        return (try decode(record, day: day), user)
    }
    func update(plot: Int?, name: String, companion: String, score: Int, expectedDay: String) async throws -> (CampusBoard, String, String) {
        let user = try await identity()
        for attempt in 0..<3 {
            let now = Date(), day = CampusBoard.dayID(now)
            guard day == expectedDay else { throw CampusError.rule("已进入新的一天，请刷新地图。") }
            let record = try await record(day: day)
            var board = try decode(record, day: day)
            var message = "守护值已同步"
            if let plot {
                message = try board.claim(plot: plot, user: user, name: name, companion: companion, score: score, now: now)
            } else {
                guard board.plots.contains(where: { $0.owner == user }) else { return (board, user, message) }
                board.contribute(user: user, score: score)
            }
            record["payload"] = try JSONEncoder().encode(board) as CKRecordValue
            do { _ = try await database.save(record); return (board, user, message) }
            catch let error as CKError where error.code == .serverRecordChanged && attempt < 2 { continue }
        }
        throw CampusError.rule("这块地正在变化，请刷新后重试。")
    }
}
