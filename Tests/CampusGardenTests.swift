import XCTest
import WebKit
@testable import Qiling

@MainActor
private final class GardenBridgeSpy: NSObject, WKScriptMessageHandler {
    var onMessage: (([String: Any]) -> Void)?

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if let body = message.body as? [String: Any] { onMessage?(body) }
    }
}

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
            if (try? await view.evaluateJavaScript("typeof window.showGarden === 'function' && !document.getElementById('claim').disabled && !document.querySelector('.night-next').disabled && document.querySelector('.night-cube').style.visibility === 'visible'")) as? Bool == true {
                ready = true
                break
            }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        XCTAssertTrue(ready)
        guard ready else { return }
        let stop = try await view.callAsyncJavaScript("""
            const label = document.querySelector('.night-stop');
            const result = new Promise(resolve => {
              const observer = new MutationObserver(() => { observer.disconnect(); resolve(label.textContent); });
              observer.observe(label, { childList: true });
              setTimeout(() => { observer.disconnect(); resolve(label.textContent); }, 8000);
            });
            document.querySelector('.night-next').click();
            return await result;
            """, arguments: [:], in: nil, contentWorld: .page)
        XCTAssertEqual(stop as? String, "窗边长椅 · 2/3")
        let claimed = try await view.evaluateJavaScript("document.getElementById('claim').click(); document.getElementById('claim').textContent")
        XCTAssertEqual(claimed as? String, "我的角落")
        let showingMap = try await view.evaluateJavaScript("document.getElementById('rain').hidden && !document.getElementById('stage').hidden")
        XCTAssertEqual(showingMap as? Bool, true)
    }

    @MainActor
    func testLateReplyCannotConfirmOrUndoANewerDecoration() async throws {
        let entry = try XCTUnwrap(Bundle.main.url(forResource: "CampusGarden", withExtension: "html"))
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        let bridge = GardenBridgeSpy()
        config.userContentController.add(bridge, name: "garden")
        config.userContentController.addUserScript(WKUserScript(source: """
            window.gardenLive = true;
            const schedule = window.setTimeout.bind(window);
            window.setTimeout = (fn, delay, ...args) => {
                if (delay === 40000) window.expireGardenRequest = fn;
                return schedule(fn, delay, ...args);
            };
            """, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        let view = WKWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 844), configuration: config)
        defer { config.userContentController.removeScriptMessageHandler(forName: "garden") }

        func request(_ action: String, trigger: () async throws -> Void) async throws -> Int {
            let sent = expectation(description: "Garden sent \(action)")
            var body: [String: Any]?
            bridge.onMessage = { body = $0; sent.fulfill() }
            defer { bridge.onMessage = nil }
            try await trigger()
            await fulfillment(of: [sent], timeout: 15)
            XCTAssertEqual(body?["action"] as? String, action)
            let id = try XCTUnwrap(body?["requestId"] as? Int)
            XCTAssertGreaterThan(id, 0)
            return id
        }
        let original: [String: Any] = ["site": 0, "health": 50, "mine": true, "name": "队友"]
        func reply(to id: Int, saved: Bool) async throws {
            var plot = original
            if saved { plot["ornament"] = "flowers"; plot["note"] = "明天见" }
            let data: [String: Any] = ["day": "2026-11-25", "health": 50, "plots": [plot], "previous": []]
            _ = try await view.callAsyncJavaScript("window.showGarden(data, id)", arguments: ["data": data, "id": id], in: nil, contentWorld: .page)
        }
        func displayedState() async throws -> [String] {
            let state = try await view.evaluateJavaScript("""
                ['status', 'current', 'note'].map(id => {
                    const el = document.getElementById(id); return id === 'note' ? el.value : el.textContent;
                }).concat(String(document.getElementById('editor').disabled))
                """)
            return try XCTUnwrap(state as? [String])
        }

        let initial = try await request("refresh") { _ = view.loadFileURL(entry, allowingReadAccessTo: entry) }
        try await reply(to: initial, saved: false)
        let expired = try await request("refresh") { _ = try await view.evaluateJavaScript("document.getElementById('refresh').click()") }
        _ = try await view.evaluateJavaScript("window.expireGardenRequest()")
        let timeoutState = try await displayedState()
        XCTAssertTrue(timeoutState[0].contains("暂时没有收到校园回信"))
        let save = try await request("decorate") {
            _ = try await view.evaluateJavaScript("document.getElementById('note').value='明天见'; document.getElementById('save').click()")
        }
        XCTAssertGreaterThan(expired, initial)
        XCTAssertGreaterThan(save, expired)
        let pending = ["正在同步…", "", "明天见", "true"]
        try await reply(to: expired, saved: false)
        let afterLateSuccess = try await displayedState()
        XCTAssertEqual(afterLateSuccess, pending)
        _ = try await view.evaluateJavaScript("window.gardenError('旧请求失败', \(expired))")
        let afterLateFailure = try await displayedState()
        XCTAssertEqual(afterLateFailure, pending)

        try await reply(to: save, saved: true)
        let confirmed = try await displayedState()
        XCTAssertTrue(confirmed[0].contains("摆好了"))
        XCTAssertTrue(confirmed[1].contains("明天见"))
        XCTAssertEqual(confirmed[3], "false")
        try await reply(to: save, saved: false)
        _ = try await view.evaluateJavaScript("window.gardenError('重复回包', \(save))")
        let afterDuplicate = try await displayedState()
        XCTAssertEqual(afterDuplicate, confirmed)
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
