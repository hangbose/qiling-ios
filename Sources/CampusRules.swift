import Foundation

struct CampusPlot: Codable, Identifiable, Equatable {
    var id: Int
    var owner: String
    var name: String
    var companion: String
    var score: Int
    var protectedUntil: Date
}

struct CampusBoard: Codable {
    var day: String
    var plots: [CampusPlot] = []
    var challenges: [String: Int] = [:]
    var visits: [String: [Int]] = [:]
    static var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return cal
    }
    static func dayID(_ now: Date) -> String { Growth.dayID(now, calendar: calendar) }
    static func open(_ now: Date) -> Bool { calendar.component(.hour, from: now) < 22 }
    mutating func contribute(user: String, score: Int) {
        if let index = plots.firstIndex(where: { $0.owner == user }) {
            plots[index].score = max(plots[index].score, min(110, max(0, score)))
        }
    }
    // All changes (including relinquishing the old plot and challenge quota)
    // are saved in one optimistic-concurrency-controlled CloudKit record.
    mutating func claim(plot: Int, user: String, name: String, companion: String, score: Int, now: Date) throws -> String {
        guard day == Self.dayID(now), (0..<24).contains(plot) else { throw CampusError.rule("地图已换日，请刷新后重试。") }
        guard Self.open(now) else { throw CampusError.rule("22:00 后停止抢夺，今晚安心休息。") }
        let value = min(110, max(0, score))
        guard value >= 20 else { throw CampusError.rule("今日健康贡献达到 20 分后可以占地。") }
        if let target = plots.first(where: { $0.id == plot }) {
            if target.owner == user { contribute(user: user, score: value); return "守护值已同步" }
            guard now >= target.protectedUntil else { throw CampusError.rule("这块地还在保护期，先选其他地方吧。") }
            let used = challenges[user, default: 0]
            guard used < 3 else { throw CampusError.rule("今天已挑战 3 次，明天再来。") }
            challenges[user] = used + 1
            guard value >= target.score + 10 else { return "挑战未成功：需要比守护值至少高 10 分。本次已计入挑战次数，不扣经验。" }
        }
        // Switching cannot be used to renew shields indefinitely.
        let protection = plots.first(where: { $0.owner == user })?.protectedUntil ?? now.addingTimeInterval(7200)
        plots.removeAll { $0.owner == user || $0.id == plot }
        plots.append(CampusPlot(id: plot, owner: user, name: String(name.prefix(20)), companion: companion,
                                score: value, protectedUntil: protection))
        var footprint = visits[user, default: []]
        if !footprint.contains(plot) { footprint.append(plot) }
        visits[user] = footprint
        return "占领成功！健康同步会更新守护值，丢地也不会扣除精灵经验。"
    }
}

enum CampusError: LocalizedError {
    case rule(String)
    var errorDescription: String? { if case .rule(let text) = self { return text }; return nil }
}
