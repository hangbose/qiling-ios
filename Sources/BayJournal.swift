import Foundation

struct BayRelayStep: Codable, Hashable {
    let key: String
    let name: String
    let companion: String
}

enum BaySouvenir: String, CaseIterable {
    case planter, pennant
    var title: String { self == .planter ? "簕杜鹃花盆" : "海风信号旗" }
    var price: Int { self == .planter ? 35 : 75 }
    var asset: String { self == .planter ? "BayPlanter" : "BayPennant" }
    var place: String { self == .planter ? "海边长椅" : "观景平台" }
    var detail: String { self == .planter ? "给长椅添一丛深圳的市花。" : "在观景平台升起一面海湾的小旗。" }
}

struct BayJournal: Codable {
    var start = Growth.dayID(Date())
    var bedtime = 23 * 60
    var goals: [String: Int] = [:]
    var days: [String: String] = [:]
    var relayCode: String?
    var relayFrom: String?
    var relaySteps: [BayRelayStep] = []
    var seen: [String: Int] = [:]

    // Older journals have no purchases. Store the paid price with each souvenir.
    private(set) var purchases: [String: Int]?

    var balance: Int {
        let earned = payments.reduce(0) { $0 + $1.amount }
        return earned - (purchases ?? [:]).values.reduce(0, +)
    }

    func owns(_ item: BaySouvenir) -> Bool { purchases?[item.rawValue] != nil }

    mutating func buy(_ item: BaySouvenir) -> Bool {
        guard !owns(item), balance >= item.price else { return false }
        var updated = purchases ?? [:]
        updated[item.rawValue] = item.price
        purchases = updated
        return true
    }

    mutating func record(day: String, reason: String) {
        guard day >= start, days[day] == nil else { return }
        days[day] = reason
    }

    func goal(on day: String) -> Int {
        goals.keys.filter { $0 <= day }.max().flatMap { goals[$0] } ?? 23 * 60
    }

    var payments: [(day: String, amount: Int)] {
        let cal = Calendar(identifier: .gregorian)
        var previous: Date?
        var amount = 50
        return days.keys.sorted().compactMap { key in
            let parts = key.split(separator: "-").compactMap { Int($0) }
            guard parts.count == 3, let date = cal.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])) else { return nil }
            if let previous {
                let gap = cal.dateComponents([.day], from: previous, to: date).day ?? 1
                amount = gap == 1 ? min(80, amount + 10) : max(50, amount - 10 * max(1, gap - 1))
            }
            previous = date
            return (key, amount)
        }
    }
    static func bedtimeMet(on day: Date, goal: Int, samples: [HealthInterval], calendar: Calendar = .current) -> Bool {
        // Choose the principal overnight sleep, ignoring isolated naps and daytime sleep.
        let midnight = calendar.startOfDay(for: day)
        guard let prior = calendar.date(byAdding: .day, value: -1, to: midnight),
              let evening = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: prior),
              let noon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: midnight) else { return false }
        let sorted = samples.filter { $0.start >= evening && $0.start < noon }.sorted { $0.start < $1.start }
        var blocks: [HealthInterval] = []
        for sample in sorted {
            let end = min(noon, sample.end)
            if let last = blocks.last, sample.start.timeIntervalSince(last.end) <= 1800 {
                blocks[blocks.count - 1] = HealthInterval(start: last.start, end: max(last.end, end))
            } else if end > sample.start { blocks.append(HealthInterval(start: sample.start, end: end)) }
        }
        let candidates = blocks.filter { $0.end > midnight }.map {
            ($0, Growth.seconds(sorted, within: DateInterval(start: $0.start, end: $0.end)))
        }
        guard let (night, duration) = candidates.max(by: { $0.1 < $1.1 }), duration >= 3 * 3600 else { return false }
        let targetDay = goal < 12 * 60 ? midnight : prior
        guard let deadline = calendar.date(bySettingHour: goal / 60, minute: goal % 60, second: 0, of: targetDay) else { return false }
        return night.start <= deadline
    }
}
