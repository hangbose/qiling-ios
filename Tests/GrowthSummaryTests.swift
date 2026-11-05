import XCTest
@testable import Qiling

final class GrowthSummaryTests: XCTestCase {
    func testCelebrationDistinguishesRewardsLevelsAndEvolution() {
        XCTAssertFalse(GrowthCelebration(previous: 100, current: 150).leveledUp)
        XCTAssertTrue(GrowthCelebration(previous: 150, current: 200).leveledUp)
        XCTAssertFalse(GrowthCelebration(previous: 150, current: 200).evolved)
        XCTAssertTrue(GrowthCelebration(previous: 950, current: 1000).evolved)
        XCTAssertTrue(GrowthCelebration(previous: 2950, current: 3000).evolved)
    }

    func testExistingSaveLoadsWithoutCelebrationField() throws {
        let data = try JSONEncoder().encode(SavedState())
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object.removeValue(forKey: "celebratedXP")
        let oldData = try JSONSerialization.data(withJSONObject: object)
        XCTAssertNil(try JSONDecoder().decode(SavedState.self, from: oldData).celebratedXP)
    }
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
    func testStreakAllowsUnfinishedTodayAndStopsAtMissingDay() {
        let now = date("2026-10-20T12:00:00+08:00")
        let yesterday = date("2026-10-19T08:00:00+08:00")
        let before = date("2026-10-18T08:00:00+08:00")
        let old = date("2026-10-16T08:00:00+08:00")
        let days = [progress(now, sleep: 0, workout: 0), progress(yesterday, workout: 0), progress(before), progress(old)]
        XCTAssertEqual(GrowthSummary(days: days, now: now, started: nil, calendar: cal).currentStreak, 2)
        XCTAssertEqual(GrowthSummary(days: days + [progress(now)], now: now, started: nil, calendar: cal).currentStreak, 3)
        XCTAssertEqual(GrowthSummary(days: [progress(before)], now: now, started: nil, calendar: cal).currentStreak, 0)
    }
}
