import XCTest
import WebKit
@testable import Qiling

final class CampusGardenTests: XCTestCase {
    @MainActor
    func testBundledGardenOpensAndShowsClaimInWebKit() async throws {
        let entry = try XCTUnwrap(Bundle.main.url(forResource: "CampusGarden", withExtension: "html"))
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        let view = WKWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 844), configuration: config)
        view.loadFileURL(entry, allowingReadAccessTo: entry)
        var ready = false
        for _ in 0..<150 {
            if (try? await view.evaluateJavaScript("typeof window.showGarden === 'function' && !document.getElementById('claim').disabled")) as? Bool == true {
                ready = true
                break
            }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        XCTAssertTrue(ready)
        guard ready else { return }
        let claimed = try await view.evaluateJavaScript("document.getElementById('claim').click(); document.getElementById('claim').textContent")
        XCTAssertEqual(claimed as? String, "我的角落")
    }

    func testDailyProtectionAndNextDay() throws {
        var board = CampusGarden(day: "2026-11-24")
        func submit(_ action: String, _ site: Int, _ owner: String, _ health: Int, _ answer: Int? = nil) throws -> Bool {
            try board.apply(action: action, site: site, owner: owner, name: owner, health: health,
                            ornament: "flowers", note: " 路过看看花 ", answer: answer, tint: "violet")
        }
        XCTAssertThrowsError(try submit("claim", 0, "A", 19))
        XCTAssertTrue(try submit("claim", 0, "A", 20))
        XCTAssertFalse(try submit("claim", 0, "A", 20))
        XCTAssertThrowsError(try submit("claim", 0, "B", 60))
        XCTAssertThrowsError(try submit("claim", 1, "A", 20))
        XCTAssertTrue(try submit("claim", 1, "B", 30))
        XCTAssertThrowsError(try submit("decorate", 0, "B", 30))
        XCTAssertTrue(try submit("decorate", 0, "A", 20))
        XCTAssertTrue(try submit("quiz", 0, "A", 45, 1))
        XCTAssertFalse(try submit("quiz", 0, "A", 45, 2))
        XCTAssertEqual(board.plots[0].answer, CampusGarden.correctAnswer(day: board.day))
        XCTAssertTrue(try submit("refresh", 0, "A", 500))
        XCTAssertEqual(board.plots[0].health, 110)
        let yesterday = try JSONDecoder().decode(CampusGarden.self, from: JSONEncoder().encode(board))
        board = CampusGarden(day: "2026-11-25")
        XCTAssertTrue(try submit("claim", 0, "B", 25))
        XCTAssertNil(board.plots[0].ornament)
        XCTAssertEqual(yesterday.plots[0].note, "路过看看花")
        XCTAssertEqual(yesterday.plots[0].tint, "violet")
    }
}
