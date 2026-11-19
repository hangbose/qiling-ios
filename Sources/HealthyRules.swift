import Foundation

struct WorkoutEntry: Codable, Identifiable, Equatable {
    var id: String
    var kind: String
    var start: Date
    var end: Date
    var minutes: Double { max(0, end.timeIntervalSince(start) / 60) }
}

enum HealthyRules {
    // Compare the longest sleep block in three noon-to-noon windows. Circular
    // clock distance handles bedtimes across midnight; naps cannot set bedtime.
    static func regularSleep(on date: Date, intervals: [HealthInterval], calendar: Calendar = .current) -> Bool {
        var bedtimes: [Int] = []
        for offset in 0..<3 {
            let day = calendar.date(byAdding: .day, value: -offset, to: date)!
            let noon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: day)!
            let previous = calendar.date(byAdding: .day, value: -1, to: noon)!
            let pieces = intervals.compactMap { item -> HealthInterval? in
                let a = max(previous, item.start), b = min(noon, item.end)
                return b > a ? HealthInterval(start: a, end: b) : nil
            }.sorted { $0.start < $1.start }
            var blocks: [HealthInterval] = []
            for item in pieces {
                if let last = blocks.last, item.start.timeIntervalSince(last.end) <= 1800 {
                    blocks[blocks.count - 1] = HealthInterval(start: last.start, end: max(last.end, item.end))
                } else { blocks.append(item) }
            }
            guard let block = blocks.max(by: { $0.end.timeIntervalSince($0.start) < $1.end.timeIntervalSince($1.start) }),
                  Growth.seconds(intervals, within: DateInterval(start: block.start, end: block.end)) >= 4 * 3600 else { return false }
            bedtimes.append(calendar.component(.hour, from: block.start) * 60 + calendar.component(.minute, from: block.start))
        }
        return bedtimes.allSatisfy { a in bedtimes.allSatisfy { b in min(abs(a-b), 1440-abs(a-b)) <= 60 } }
    }
}
