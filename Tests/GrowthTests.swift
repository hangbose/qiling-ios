import XCTest
@testable import Qiling

final class GrowthTests: XCTestCase {
    private var cal: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 3600)!
        return calendar
    }
    private func date(_ string: String) -> Date {
        ISO8601DateFormatter().date(from: string)!
    }
    func testOverlappingSourcesDoNotDuplicateSleep() {
        let a = date("2026-10-19T23:00:00+08:00")
        let b = date("2026-10-20T07:00:00+08:00")
        let intervals = [HealthInterval(start: a, end: b),
                         HealthInterval(start: a.addingTimeInterval(3600), end: b)]
        let day = Growth.progress(on: b, sleep: intervals, workouts: [], sleepGoal: 8, workoutGoal: 30, calendar: cal)
        XCTAssertEqual(day.sleepHours, 8)
        XCTAssertEqual(day.points, 50)
    }
    func testSleepIsAssignedToWakeDay() {
        let a = date("2026-10-19T23:00:00+08:00")
        let b = date("2026-10-20T07:00:00+08:00")
        let sleep = [HealthInterval(start: a, end: b)]
        XCTAssertEqual(Growth.progress(on: a, sleep: sleep, workouts: [], sleepGoal: 8, workoutGoal: 30, calendar: cal).sleepHours, 0)
        XCTAssertEqual(Growth.progress(on: b, sleep: sleep, workouts: [], sleepGoal: 8, workoutGoal: 30, calendar: cal).sleepHours, 8)
    }
    func testDailyCapAndDeterministicReplay() {
        let start = date("2026-10-20T00:00:00+08:00")
        let intervals = [HealthInterval(start: start, end: start.addingTimeInterval(10 * 3600))]
        let result = Growth.progress(on: start, sleep: intervals, workouts: intervals, sleepGoal: 8, workoutGoal: 30, calendar: cal)
        var ledger: [String: DailyProgress] = [:]
        ledger[result.id] = result
        ledger[result.id] = result
        XCTAssertEqual(ledger.values.reduce(0) { $0 + $1.points }, 100)
    }
    func testMissingDataEarnsNothing() {
        let result = Growth.progress(on: Date(), sleep: [], workouts: [], sleepGoal: 8, workoutGoal: 30)
        XCTAssertEqual(result.points, 0)
    }
    func testMidnightWorkoutSplit() {
        let a = date("2026-10-19T23:45:00+08:00")
        let b = date("2026-10-20T00:15:00+08:00")
        let intervals = [HealthInterval(start: a, end: b)]
        for day in [a, b] {
            XCTAssertEqual(Growth.progress(on: day, sleep: [], workouts: intervals,
                                           sleepGoal: 8, workoutGoal: 30, calendar: cal).workoutMinutes, 15)
        }
    }
    func testMondayStartsNewCompetition() {
        XCTAssertNotEqual(Growth.weekID(date("2026-10-18T23:00:00+08:00"), calendar: cal),
                          Growth.weekID(date("2026-10-19T00:00:00+08:00"), calendar: cal))
    }
    func testEvolutionBoundaries() {
        XCTAssertEqual(Growth.stage(999), 0)
        XCTAssertEqual(Growth.stage(1000), 1)
        XCTAssertEqual(Growth.stage(2999), 1)
        XCTAssertEqual(Growth.stage(3000), 2)
    }
}
