import CloudKit
import Foundation

struct GardenPlot: Codable {
    let site: Int
    let owner: String
    let name: String
    var health: Int
    var answer: Int?
    var ornament: String?
    var note: String?
    var tint: String?
}

struct CampusGarden: Codable {
    let day: String
    var plots: [GardenPlot] = []
    static let ornaments = ["flowers", "lamp", "flag"]
    // Each question has the same three choices in the native and browser versions.
    static func correctAnswer(day: String) -> Int {
        let n = Int(day.suffix(2)) ?? 1
        return [1, 2, 0][n % 3]
    }

    mutating func apply(action: String, site: Int, owner: String, name: String, health: Int,
                        ornament: String?, note: String?, answer: Int?, tint: String? = nil) throws -> Bool {
        let score = min(110, max(0, health))
        if action == "claim" {
            guard (0..<3).contains(site), score >= 20 else { throw CampusError.rule("今日健康贡献满 20 分，就能认领一处角落。") }
            if let previous = plots.first(where: { $0.owner == owner }) {
                guard previous.site == site else { throw CampusError.rule("今天已经选过活动点了。明天可以换个地方。") }
                return false
            }
            guard !plots.contains(where: { $0.site == site }) else { throw CampusError.rule("这里今天已有主人，换个角落看看。") }
            plots.append(GardenPlot(site: site, owner: owner, name: String(name.prefix(20)), health: score))
            return true
        }
        guard let i = plots.firstIndex(where: { $0.owner == owner }) else {
            if action == "refresh" { return false }
            throw CampusError.rule("先认领今天的角落。")
        }
        let oldScore = plots[i].health
        plots[i].health = max(oldScore, score)
        if action == "refresh" { return plots[i].health != oldScore }
        guard plots[i].site == site else { throw CampusError.rule("只有今天的主人可以布置这里。") }
        switch action {
        case "decorate":
            guard let ornament, Self.ornaments.contains(ornament) else { throw CampusError.rule("请选择一件摆设。") }
            let words = String((note ?? "").trimmingCharacters(in: .whitespacesAndNewlines).prefix(40))
            let color = ["jade","apricot","violet"].contains(tint ?? "") ? tint : plots[i].tint
            let changed = plots[i].ornament != ornament || plots[i].note != words || plots[i].tint != color
            plots[i].ornament = ornament
            plots[i].note = words
            plots[i].tint = color
            return changed || plots[i].health != oldScore
        case "quiz":
            guard let answer, (0..<3).contains(answer) else { throw CampusError.rule("请选一个答案。") }
            guard plots[i].answer == nil else { return plots[i].health != oldScore }
            plots[i].answer = answer
            return true
        default: throw CampusError.rule("请重新打开校园地图。")
        }
    }
}

extension CampusService {
    func gardenSnapshot(action: String, expectedDay: String, site: Int, name: String, health: Int,
                        ornament: String?, note: String?, answer: Int?, tint: String?) async throws -> (CampusGarden, CampusGarden, String) {
        let cloud = CKContainer.default()
        guard try await cloud.accountStatus() == .available else { throw SquadFailure.account }
        let user = try await cloud.userRecordID().recordName
        let db = cloud.publicCloudDatabase
        func load(_ day: String) async throws -> (CKRecord, CampusGarden) {
            let id = CKRecord.ID(recordName: "campus-zhili-garden-v1-" + day)
            let record: CKRecord
            do { record = try await db.record(for: id) }
            catch let error as CKError where error.code == .unknownItem {
                return (CKRecord(recordType: "CampusDay", recordID: id), CampusGarden(day: day))
            }
            guard let data = record["payload"] as? Data else { throw CampusError.rule("这处庭院暂时读不到，请刷新。") }
            let garden = try JSONDecoder().decode(CampusGarden.self, from: data)
            guard garden.day == day else { throw CampusError.rule("日期已变化，请刷新地图。") }
            return (record, garden)
        }
        for attempt in 0..<4 {
            let now = Date(), day = CampusBoard.dayID(now)
            if action != "refresh" && expectedDay != day { throw CampusError.rule("已经换日，刷新后再选今天的活动点。") }
            let yesterday = CampusBoard.calendar.date(byAdding: .day, value: -1, to: now)!
            let (_, past) = try await load(CampusBoard.dayID(yesterday))
            var (record, garden) = try await load(day)
            guard CampusBoard.dayID(Date()) == day else { continue }
            let changed = try garden.apply(action: action, site: site, owner: user, name: name, health: health,
                                           ornament: ornament, note: note, answer: answer, tint: tint)
            if changed {
                record["payload"] = try JSONEncoder().encode(garden) as CKRecordValue
                do { _ = try await db.save(record) }
                catch let conflict as CKError where conflict.code == .serverRecordChanged && attempt < 3 { continue }
            }
            return (garden, past, user)
        }
        throw CampusError.rule("有人刚更新了这块地，刷新就能看到。")
    }
}
