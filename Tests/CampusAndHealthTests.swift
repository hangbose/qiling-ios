import XCTest
@testable import Qiling

final class CampusAndHealthTests: XCTestCase {
    private let now = ISO8601DateFormatter().date(from: "2026-11-19T10:00:00+08:00")!
    func testActivityDoesNotStackStepsAndTraining() {
        var day = DailyProgress(id: "x", date: now, sleepHours: 0, workoutMinutes: 30, sleepGoal: 8, workoutGoal: 30, steps: 6000)
        day.ruleVersion = 2
        XCTAssertEqual(day.points, 70)
        day.steps = 100000
        day.workoutMinutes = 600
        day.sleepHours = 20
        day.regularSleep = true
        XCTAssertEqual(day.contribution, 110)
        day.earnedFloor = 300
        XCTAssertEqual(day.points, 300)
        XCTAssertEqual(day.contribution, 110)
    }
    func testOldLedgerRetainsEarnedExperience() throws {
        let day = DailyProgress(id: "x", date: now, sleepHours: 8, workoutMinutes: 30, sleepGoal: 8, workoutGoal: 30, steps: 2000)
        let decoded = try JSONDecoder().decode(DailyProgress.self, from: JSONEncoder().encode(day))
        XCTAssertEqual(decoded.points, 120)
    }
    func testShieldAndDailyQuota() throws {
        var board = CampusBoard(day: CampusBoard.dayID(now))
        _ = try board.claim(plot: 0, user: "a", name: "A", companion: "yaya", score: 30, now: now)
        XCTAssertThrowsError(try board.claim(plot: 0, user: "b", name: "B", companion: "yaya", score: 100, now: now))
        XCTAssertNil(board.challenges["b"])
        let later = now.addingTimeInterval(7201)
        for _ in 0..<3 {
            _ = try board.claim(plot: 0, user: "b", name: "B", companion: "yaya", score: 30, now: later)
        }
        XCTAssertEqual(board.plots.first?.owner, "a")
        XCTAssertEqual(board.challenges["b"], 3)
        XCTAssertThrowsError(try board.claim(plot: 0, user: "b", name: "B", companion: "yaya", score: 100, now: later))
    }
    func testCaptureAtomicallyReleasesOldLandAndKeepsShield() throws {
        var board = CampusBoard(day: CampusBoard.dayID(now))
        _ = try board.claim(plot: 0, user: "a", name: "A", companion: "yaya", score: 20, now: now)
        _ = try board.claim(plot: 1, user: "b", name: "B", companion: "yaya", score: 50, now: now)
        _ = try board.claim(plot: 0, user: "b", name: "B", companion: "yaya", score: 50, now: now.addingTimeInterval(7201))
        XCTAssertEqual(board.plots.count, 1)
        XCTAssertEqual(board.plots[0].owner, "b")
        XCTAssertEqual(board.plots[0].protectedUntil, now.addingTimeInterval(7200))
    }
    func testNightAndRollover() throws {
        var board = CampusBoard(day: CampusBoard.dayID(now))
        XCTAssertThrowsError(try board.claim(plot: 0, user: "a", name: "A", companion: "yaya", score: 100, now: now.addingTimeInterval(12 * 3600)))
        XCTAssertThrowsError(try board.claim(plot: 0, user: "a", name: "A", companion: "yaya", score: 100, now: now.addingTimeInterval(24 * 3600)))
        XCTAssertEqual(CampusBoard(day: CampusBoard.dayID(now.addingTimeInterval(86400))).plots.count, 0)
    }
    func testEmptyMovesCannotFarmAllFootprints() throws {
        var board = CampusBoard(day: CampusBoard.dayID(now))
        for id in 0..<4 {
            _ = try board.claim(plot: id, user: "a", name: "A", companion: "yaya", score: 50, now: now)
        }
        XCTAssertThrowsError(try board.claim(plot: 4, user: "a", name: "A", companion: "yaya", score: 50, now: now))
        XCTAssertEqual(board.visits["a"]?.count, 4)
        XCTAssertEqual(board.plots.count, 1)
    }
    func testRegularSleepAcrossMidnightAndMissingNight() {
        let formatter = ISO8601DateFormatter()
        let intervals = [("2026-11-16T23:40:00+08:00", "2026-11-17T07:40:00+08:00"),
                         ("2026-11-18T00:10:00+08:00", "2026-11-18T08:10:00+08:00"),
                         ("2026-11-18T23:55:00+08:00", "2026-11-19T07:55:00+08:00")].map {
            HealthInterval(start: formatter.date(from: $0.0)!, end: formatter.date(from: $0.1)!)
        }
        XCTAssertTrue(HealthyRules.regularSleep(on: now, intervals: intervals, calendar: CampusBoard.calendar))
        XCTAssertFalse(HealthyRules.regularSleep(on: now, intervals: Array(intervals.dropLast()), calendar: CampusBoard.calendar))
    }
}
