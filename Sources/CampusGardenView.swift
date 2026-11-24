import SwiftUI
import WebKit

struct CampusGardenView: UIViewRepresentable {
    @EnvironmentObject private var model: AppModel
    func makeCoordinator() -> Coordinator { Coordinator(model: model) }
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let live = !model.demo && model.state.campusSharing == true
        config.userContentController.addUserScript(WKUserScript(source: "window.gardenLive = " + (live ? "true;" : "false;"),
                                                                injectionTime: .atDocumentStart, forMainFrameOnly: true))
        config.userContentController.add(context.coordinator, name: "garden")
        let view = WKWebView(frame: .zero, configuration: config)
        view.scrollView.contentInsetAdjustmentBehavior = .never
        if let file = Bundle.main.url(forResource: "CampusGarden", withExtension: "html") {
            view.loadFileURL(file, allowingReadAccessTo: file)
        }
        return view
    }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        uiView.configuration.userContentController.removeScriptMessageHandler(forName: "garden")
    }

    @MainActor final class Coordinator: NSObject, WKScriptMessageHandler {
        let model: AppModel
        init(model: AppModel) { self.model = model }
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.frameInfo.isMainFrame, message.frameInfo.request.url?.isFileURL == true,
                  let view = message.webView, let args = message.body as? [String: Any],
                  let action = args["action"] as? String, !model.demo, model.state.campusSharing == true else { return }
            Task {
                do {
                    if args["sync"] as? Bool == true { await model.sync() }
                    let (current, past, user) = try await model.campus.gardenSnapshot(action: action,
                        expectedDay: args["day"] as? String ?? "", site: args["site"] as? Int ?? -1,
                        name: model.state.name, health: model.campusScore, ornament: args["ornament"] as? String,
                        note: args["note"] as? String, answer: args["answer"] as? Int, tint: args["tint"] as? String)
                    func publicRows(_ garden: CampusGarden) -> [[String: Any]] {
                        garden.plots.map { p in
                            var row: [String: Any] = ["site":p.site,"name":p.name,"mine":p.owner == user,"health":p.health]
                            if let choice = p.answer { row["bonus"] = choice == CampusGarden.correctAnswer(day: garden.day) ? 5 : 0
                                row["answered"] = true }
                            if let decor = p.ornament { row["ornament"] = decor; row["note"] = p.note ?? "" }
                            if let tint = p.tint { row["tint"] = tint }
                            return row
                        }
                    }
                    let snapshot: [String: Any] = ["day":current.day,"health":model.campusScore,"plots":publicRows(current),
                                                   "previous":publicRows(past)]
                    _ = try await view.callAsyncJavaScript("window.showGarden(snapshot)", arguments: ["snapshot": snapshot],
                                                        in: nil, contentWorld: .page)
                } catch {
                    _ = try? await view.callAsyncJavaScript("window.gardenError(reason)", arguments: ["reason":error.localizedDescription],
                                                             in: nil, contentWorld: .page)
                }
            }
        }
    }
}
