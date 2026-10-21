import CloudKit
import Foundation

struct SquadMember: Identifiable {
    let id: String
    let name: String
    let points: Int
    let xp: Int
    let cheers: Int
    let updated: Date
}

// Public database contains opt-in summaries only. Never send raw HealthKit samples.
// A code is an invitation convenience, not a security boundary. See README.
actor SquadService {
    // Resolve only when a user connects a squad. Local growth and simulator tests
    // must work before a CloudKit container has been provisioned.
    private var container: CKContainer { CKContainer.default() }
    private var database: CKDatabase { container.publicCloudDatabase }

    private func userID() async throws -> CKRecord.ID {
        guard try await container.accountStatus() == .available else { throw SquadFailure.account }
        return try await container.userRecordID()
    }

    func create() async throws -> String {
        _ = try await userID()
        let code = UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(10).uppercased()
        let record = CKRecord(recordType: "Squad", recordID: CKRecord.ID(recordName: "squad-\(code)"))
        record["code"] = code as CKRecordValue
        _ = try await database.save(record)
        return code
    }

    func validate(code: String) async throws {
        _ = try await userID()
        _ = try await database.record(for: CKRecord.ID(recordName: "squad-\(code)"))
    }

    func publish(code: String, week: String, name: String, points: Int, xp: Int) async throws {
        let user = try await userID()
        let id = CKRecord.ID(recordName: "member-\(code)-\(week)-\(user.recordName)")
        let record: CKRecord
        do { record = try await database.record(for: id) }
        catch let error as CKError where error.code == .unknownItem {
            record = CKRecord(recordType: "MemberWeek", recordID: id)
        }
        record["squad"] = code as CKRecordValue
        record["week"] = week as CKRecordValue
        record["nickname"] = name as CKRecordValue
        record["points"] = points as CKRecordValue
        record["xp"] = xp as CKRecordValue
        record["updated"] = Date() as CKRecordValue
        _ = try await database.save(record)
    }

    private func records(type: String, predicate: NSPredicate) async throws -> [CKRecord] {
        let query = CKQuery(recordType: type, predicate: predicate)
        var page = try await database.records(matching: query)
        var result = try page.matchResults.map { try $0.1.get() }
        while let cursor = page.queryCursor {
            page = try await database.records(continuingMatchFrom: cursor)
            result.append(contentsOf: try page.matchResults.map { try $0.1.get() })
        }
        return result
    }

    func members(code: String, week: String) async throws -> [SquadMember] {
        let predicate = NSPredicate(format: "squad == %@ AND week == %@", code, week)
        async let memberRecords = records(type: "MemberWeek", predicate: predicate)
        async let cheerRecords = records(type: "Cheer", predicate: predicate)
        let (members, cheers) = try await (memberRecords, cheerRecords)
        return members.map { record in
            SquadMember(id: record.recordID.recordName, name: record["nickname"] as? String ?? "同行者",
                        points: record["points"] as? Int ?? 0, xp: record["xp"] as? Int ?? 0,
                        cheers: cheers.filter { ($0["target"] as? String) == record.recordID.recordName }.count,
                        updated: record["updated"] as? Date ?? .distantPast)
        }.sorted { $0.points == $1.points ? $0.id < $1.id : $0.points > $1.points }
    }

    func cheer(member: SquadMember, code: String, week: String) async throws {
        let user = try await userID()
        let id = CKRecord.ID(recordName: "cheer-\(member.id)-\(user.recordName)")
        do {
            _ = try await database.record(for: id)
            return
        } catch let error as CKError where error.code == .unknownItem { }
        let record = CKRecord(recordType: "Cheer", recordID: id)
        record["squad"] = code as CKRecordValue
        record["week"] = week as CKRecordValue
        record["target"] = member.id as CKRecordValue
        _ = try await database.save(record)
    }
}

enum SquadFailure: LocalizedError {
    case account
    var errorDescription: String? { "请先在 iPhone 设置中登录 iCloud，再连接好友小队。" }
}
