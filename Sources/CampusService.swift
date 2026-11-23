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
                guard let current = board.plots.first(where: { $0.owner == user }),
                      current.score < min(110, max(0, score)) else { return (board, user, message) }
                board.contribute(user: user, score: score)
            }
            record["payload"] = try JSONEncoder().encode(board) as CKRecordValue
            do { _ = try await database.save(record); return (board, user, message) }
            catch let error as CKError where error.code == .serverRecordChanged && attempt < 2 { continue }
        }
        throw CampusError.rule("这块地正在变化，请刷新后重试。")
    }
}


extension CampusService {
    func advanceBay(code: String, days: [String], name: String, companion: String) async throws -> (steps: [BayRelayStep], user: String) {
        let user = try await identity()
        var result: [BayRelayStep] = []
        var contributed = Set<String>()
        let candidates = Set(days).sorted().map { BayRelayStep(key: user + "|" + $0, name: name, companion: companion) }
        var page = 0
        while true {
            // Keep the original three-entry record readable by older clients.
            let suffix = page == 0 ? "" : "-page-\(page)"
            let id = CKRecord.ID(recordName: "journey-bay-v1-\(code)" + suffix)
            let capacity = page == 0 ? 3 : 96
            let steps = try await appendBayPage(id, capacity: capacity,
                candidates: candidates.filter { !contributed.contains($0.key) })
            result.append(contentsOf: steps)
            contributed.formUnion(steps.map(\.key))
            if steps.count < capacity { return (result, user) }
            page += 1
        }
    }

    private func appendBayPage(_ id: CKRecord.ID, capacity: Int,
                               candidates: [BayRelayStep]) async throws -> [BayRelayStep] {
        for attempt in 0..<3 {
            let record: CKRecord
            do { record = try await database.record(for: id) }
            catch let error as CKError where error.code == .unknownItem {
                record = CKRecord(recordType: "CampusDay", recordID: id)
            }
            let data = record["payload"] as? Data
            var steps = try data.map { try JSONDecoder().decode([BayRelayStep].self, from: $0) } ?? []
            guard steps.count <= capacity, Set(steps.map(\.key)).count == steps.count else {
                throw CampusError.rule("这段接力记录暂时无法读取。")
            }
            let before = steps.count
            var keys = Set(steps.map(\.key))
            for step in candidates where steps.count < capacity {
                if keys.insert(step.key).inserted { steps.append(step) }
            }
            if before == steps.count { return steps }
            record["payload"] = try JSONEncoder().encode(steps) as CKRecordValue
            do { _ = try await database.save(record); return steps }
            catch let error as CKError where error.code == .serverRecordChanged && attempt < 2 { continue }
        }
        throw CampusError.rule("接力正在更新，稍后会重试。")
    }
}

