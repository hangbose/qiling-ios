import XCTest
@testable import Qiling

final class GrowthSummaryTests: XCTestCase {
    private var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 8 * 3600)!
        return c
    }
    private func date(_ text: String) -> Date { ISO8601DateFormatter().date(from: text)! }
    private func progress(_ date: Date, sleep: Double = 8, workout: Double = 30) -> DailyProgress {
        DailyProgress(id: Growth.dayID(date, calendar: cal), date: date,
                      sleepHours: sleep, workoutMinutes: workout, sleepGoal: 8, workoutGoal: 30)
    }
    func testEmptySummaryDoesNotInventCompanionDaysOrAchievements() {
        let summary = GrowthSummary(days: [], now: date("2026-10-20T12:00:00+08:00"), started: nil, calendar: cal)
        XCTAssertEqual(summary.companionDays, 0)
        XCTAssertEqual(summary.sleepDays, 0)
        XCTAssertEqual(summary.workoutDays, 0)
        XCTAssertEqual(summary.week.count, 7)
        XCTAssertEqual(summary.week.reduce(0) { $0 + $1.points }, 0)
    }
    func testCompanionDaysIncludesAdoptionDay() {
        let start = date("2026-10-01T23:00:00+08:00")
        let summary = GrowthSummary(days: [], now: date("2026-10-21T08:00:00+08:00"), started: start, calendar: cal)
        XCTAssertEqual(summary.companionDays, 21)
    }
    func testCurrentWeekExcludesPreviousSundayAndCountsRealGoals() {
        let sunday = date("2026-10-18T08:00:00+08:00")
        let monday = date("2026-10-19T08:00:00+08:00")
        let tuesday = date("2026-10-20T08:00:00+08:00")
        let summary = GrowthSummary(days: [progress(sunday), progress(monday, workout: 10), progress(tuesday, sleep: 6)],
                                    now: tuesday, started: nil, calendar: cal)
        XCTAssertEqual(summary.week.map(\.points), [50, 50, 0, 0, 0, 0, 0])
        XCTAssertEqual(summary.sleepDays, 2)
        XCTAssertEqual(summary.workoutDays, 2)
        XCTAssertEqual(Growth.dayID(summary.week[0].date, calendar: cal), "2026-10-19")
    }
}
