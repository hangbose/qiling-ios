import XCTest
@testable import Qiling

final class BayJournalTests: XCTestCase {
    func testDelayedSyncDoesNotDuplicateRewardsOrReplayBeforeArrival() {
        var book = BayJournal()
        book.start = "2026-11-19"
        for day in [18, 19, 21, 21, 20, 22, 24] {
            book.record(day: "2026-11-\(day)", reason: "阅读")
        }
        XCTAssertEqual(book.payments.map(\.amount), [50, 60, 70, 80, 70])
        XCTAssertEqual(book.days.count, 5)
    }

    func testShopUsesEarnedBalanceOnceAndSurvivesReload() throws {
        var archived = BayJournal()
        archived.start = "2026-11-19"
        let data = try JSONEncoder().encode(archived)
        XCTAssertFalse(String(decoding: data, as: UTF8.self).contains("purchases"))
        var book = try JSONDecoder().decode(BayJournal.self, from: data)
        XCTAssertFalse(book.buy(.planter))
        book.record(day: "2026-11-19", reason: "按时入睡")
        XCTAssertTrue(book.buy(.planter))
        XCTAssertFalse(book.buy(.planter))
        XCTAssertFalse(book.buy(.pennant))
        XCTAssertEqual(book.balance, 15)
        book.record(day: "2026-11-20", reason: "阅读")
        XCTAssertEqual(book.balance, 75)
        XCTAssertTrue(book.buy(.pennant))
        let restored = try JSONDecoder().decode(BayJournal.self, from: JSONEncoder().encode(book))
        XCTAssertTrue(restored.owns(.planter))
        XCTAssertTrue(restored.owns(.pennant))
        XCTAssertEqual(restored.balance, 0)
    }

    func testBedtimeUsesMainSleepAndNextMorningForAfterMidnightTargets() {
        let cal = Calendar(identifier: .gregorian)
        let day = cal.date(from: DateComponents(year: 2026, month: 11, day: 21))!
        let nap = HealthInterval(start: day.addingTimeInterval(-5*3600), end: day.addingTimeInterval(-4*3600))
        let sleep = HealthInterval(start: day.addingTimeInterval(15*60), end: day.addingTimeInterval(8*3600))
        XCTAssertFalse(BayJournal.bedtimeMet(on: day, goal: 23*60, samples: [nap, sleep], calendar: cal))
        XCTAssertTrue(BayJournal.bedtimeMet(on: day, goal: 30, samples: [nap, sleep, sleep], calendar: cal))
        XCTAssertFalse(BayJournal.bedtimeMet(on: day, goal: 30, samples: [nap], calendar: cal))
    }
}
