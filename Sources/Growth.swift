import Foundation

struct HealthInterval: Codable, Equatable {
    let start: Date
    let end: Date
}

struct DailyProgress: Codable, Identifiable, Equatable {
    var id: String
    var date: Date
    var sleepHours: Double
    var workoutMinutes: Double
    var sleepGoal: Double
    var workoutGoal: Double
    var sleepComplete: Bool { sleepHours >= sleepGoal }
    var workoutComplete: Bool { workoutMinutes >= workoutGoal }
    var points: Int { (sleepComplete ? 50 : 0) + (workoutComplete ? 50 : 0) }
}

enum Growth {
    static func dayID(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }

    static func weekID(_ date: Date, calendar: Calendar = .current) -> String {
        var cal = calendar
        cal.firstWeekday = 2
        cal.minimumDaysInFirstWeek = 4
        let c = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return "\(c.yearForWeekOfYear!)-W\(c.weekOfYear!)"
    }

    // Union overlaps: watch stages and other sources must not double-count time.
    static func seconds(_ intervals: [HealthInterval], within window: DateInterval) -> Double {
        let sorted = intervals.compactMap { item -> HealthInterval? in
            let start = max(item.start, window.start)
            let end = min(item.end, window.end)
            return end > start ? HealthInterval(start: start, end: end) : nil
        }.sorted { $0.start < $1.start }
        guard var current = sorted.first else { return 0 }
        var total: Double = 0
        for item in sorted.dropFirst() {
            if item.start <= current.end {
                current = HealthInterval(start: current.start, end: max(current.end, item.end))
            } else {
                total += current.end.timeIntervalSince(current.start)
                current = item
            }
        }
        return total + current.end.timeIntervalSince(current.start)
    }

    // Sleep belongs to a noon-to-noon window ending on the displayed date.
    // Calendar arithmetic keeps DST days correct.
    static func progress(on date: Date, sleep: [HealthInterval], workouts: [HealthInterval],
                         sleepGoal: Double, workoutGoal: Double,
                         calendar: Calendar = .current) -> DailyProgress {
        let day = calendar.startOfDay(for: date)
        let nextDay = calendar.date(byAdding: .day, value: 1, to: day)!
        let noon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: day)!
        let previousNoon = calendar.date(byAdding: .day, value: -1, to: noon)!
        return DailyProgress(
            id: dayID(day, calendar: calendar), date: day,
            sleepHours: seconds(sleep, within: DateInterval(start: previousNoon, end: noon)) / 3600,
            workoutMinutes: seconds(workouts, within: DateInterval(start: day, end: nextDay)) / 60,
            sleepGoal: sleepGoal, workoutGoal: workoutGoal)
    }

    static func stage(_ xp: Int) -> Int { xp >= 3000 ? 2 : (xp >= 1000 ? 1 : 0) }
    static func stageName(_ xp: Int) -> String { ["星芽幼体", "逐光成长体", "月辉守护体"][stage(xp)] }
    static func nextMilestone(_ xp: Int) -> Int { xp < 1000 ? 1000 : (xp < 3000 ? 3000 : ((xp / 1000) + 1) * 1000) }
}
