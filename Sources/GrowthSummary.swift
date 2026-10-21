import Foundation

struct GrowthSummary {
    let days: [DailyProgress]
    let now: Date
    let started: Date?
    var calendar = Calendar.current

    var companionDays: Int {
        guard let start = started ?? days.map(\.date).min() else { return 0 }
        return max(1, (calendar.dateComponents([.day], from: calendar.startOfDay(for: start),
                                              to: calendar.startOfDay(for: now)).day ?? 0) + 1)
    }
    var sleepDays: Int { days.filter(\.sleepComplete).count }
    var workoutDays: Int { days.filter(\.workoutComplete).count }
    var week: [(date: Date, points: Int)] {
        var cal = calendar
        cal.firstWeekday = 2
        cal.minimumDaysInFirstWeek = 4
        guard let start = cal.dateInterval(of: .weekOfYear, for: now)?.start else { return [] }
        return (0..<7).compactMap { offset in
            guard let date = cal.date(byAdding: .day, value: offset, to: start) else { return nil }
            let key = Growth.dayID(date, calendar: cal)
            return (date, days.first { $0.id == key }?.points ?? 0)
        }
    }
}
