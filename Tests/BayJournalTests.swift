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
