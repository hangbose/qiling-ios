import XCTest
@testable import Qiling

final class BayJournalTests: XCTestCase {
    func testSoloDaysStayPersonalAfterResumingOrChangingTeam() {
        var book = BayJournal()
        book.start = "2026-11-01"
        book.setRelay(true, code: "A", today: "2026-11-01")
        book.record(day: "2026-11-01", reason: "阅读")
        book.setRelay(false, code: "A", today: "2026-11-02")
        book.record(day: "2026-11-02", reason: "喝水")
        XCTAssertTrue(book.eligibleRelayDays.isEmpty)
        book.setRelay(true, code: "A", today: "2026-11-03")
        book.record(day: "2026-11-03", reason: "阅读")
        XCTAssertEqual(book.eligibleRelayDays, ["2026-11-01", "2026-11-03"])
        book.setRelay(true, code: "B", today: "2026-11-03")
        XCTAssertEqual(book.eligibleRelayDays, ["2026-11-03"])
    }

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

    func testCanSaveForCottageAfterLightingAllStops() {
        var book = BayJournal()
        book.start = "2026-11-10"
        for day in 10...14 { book.record(day: "2026-11-\(day)", reason: "步行千步") }
        XCTAssertEqual(book.balance, 340)
        XCTAssertFalse(book.buy(.cottage))
        book.record(day: "2026-11-15", reason: "阅读")
        XCTAssertEqual(book.balance, 420)
        XCTAssertTrue(book.buy(.cottage))
        XCTAssertFalse(book.buy(.cottage))
        XCTAssertEqual(book.balance, 0)
    }

    func testRouteBoundariesAndRevisits() {
        XCTAssertEqual(BayDistrict.lapLength, 78)
        XCTAssertEqual(BayTrail(12).district, 0)
        XCTAssertEqual(BayTrail(13).ticks(in: 1), 1)
        XCTAssertEqual(BayTrail(27).ticks(in: 1), 15)
        XCTAssertFalse(BayTrail(27).canVisit(2))
        XCTAssertEqual(BayTrail(78).district, 4)
        XCTAssertEqual(BayTrail(79).lap, 2)
        XCTAssertEqual(BayTrail(79).visitTicks(4), 18)
    }

    func testMissingSoloPaceIsDistinguishableFromANewJournal() throws {
        var old = BayJournal()
        old.shortRouteDays = nil
        let data = try JSONEncoder().encode(old)
        XCTAssertNil(try JSONDecoder().decode(BayJournal.self, from: data).shortRouteDays)
        XCTAssertEqual(BayJournal().shortRouteDays, 0)
    }

    func testPanoramaDayDistanceAndCameraStayInsideEveryDistrict() {
        let phone = CGSize(width: 390, height: 645)
        for (index, district) in BayDistrict.all.enumerated() {
            let start = BayPromenadeLayout(district: index, viewport: phone, ticks: 0, focus: nil)
            let next = BayPromenadeLayout(district: index, viewport: phone, ticks: 1, focus: nil)
            XCTAssertGreaterThanOrEqual((next.x - start.x) * start.width, phone.width * 0.82 - 0.001)
            for tick in 0...district.length {
                let view = BayPromenadeLayout(district: index, viewport: phone, ticks: Double(tick), focus: nil)
                XCTAssertGreaterThanOrEqual(view.cameraLeft, 0)
                XCTAssertLessThanOrEqual(view.cameraLeft + phone.width, view.width + 0.001)
                XCTAssertTrue((0...phone.height).contains(view.screenPoint(view.x).y))
            }
        }
    }

    func testOldPlayersKeepTheirLandmarksAndFutureStepsCostOne() {
        XCTAssertEqual(BayTrail(3, legacyCount: 3).total, 12)
        XCTAssertEqual(BayTrail(4, legacyCount: 3).total, 13)
        XCTAssertEqual(BayTrail(9, legacyCount: 9).ticks(in: 1), 15)
        XCTAssertEqual(BayTrail(27, legacyCount: 28).total, 78)
        XCTAssertEqual(BayTrail(28, legacyCount: 28).lap, 2)
        XCTAssertEqual(BayTrail(29, legacyCount: 28).total, 83)
    }

    func testPlacementSurvivesReloadAndDoesNotChargeAgain() throws {
        var book = BayJournal()
        book.start = "2026-11-01"
        book.record(day: book.start, reason: "阅读")
        XCTAssertTrue(book.buy(.planter))
        book.place(.planter, in: 1, at: 0.8, progress: BayTrail(1))
        XCTAssertEqual(book.position(of: .planter).district, 0)
        book.place(.planter, in: 1, at: 1.5, progress: BayTrail(13))
        let copy = try JSONDecoder().decode(BayJournal.self, from: JSONEncoder().encode(book))
        XCTAssertEqual(copy.position(of: .planter).district, 1)
        XCTAssertEqual(copy.position(of: .planter).x, 0.94)
        XCTAssertEqual(copy.balance, 15)
    }

    func testWatchAndManualRecordSettleSameDayOnce() {
        var day = DailyProgress(id: "2026-11-20", date: Date(), sleepHours: 0, workoutMinutes: 9.5, sleepGoal: 8, workoutGoal: 30, steps: 999)
        XCTAssertNil(BayJournal.automaticReason(day))
        day.workoutMinutes = 10
        XCTAssertEqual(BayJournal.automaticReason(day), "运动达标")
        var book = BayJournal()
        book.start = day.id
        book.record(day: day.id, reason: "阅读")
        book.record(day: day.id, reason: BayJournal.automaticReason(day)!)
        XCTAssertEqual(book.days[day.id], "阅读")
        XCTAssertEqual(book.balance, 50)
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
