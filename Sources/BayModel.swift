import Foundation

extension AppModel {
    func buyBaySouvenir(_ item: BaySouvenir) {
        if demo {
            _ = demoBay.buy(item)
        } else if state.bay?.buy(item) == true {
            save()
        }
    }

    func markBaySeen(_ count: Int, route: String) {
        if demo { demoBay.seen[route] = count; return }
        if state.bay?.seen[route] != count { state.bay?.seen[route] = count; save() }
    }

    func setBayBedtime(_ minutes: Int) {
        guard !demo, (0..<1440).contains(minutes) else { return }
        let next = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        state.bay?.bedtime = minutes
        state.bay?.goals[Growth.dayID(next)] = minutes
        save()
    }

    func setBayRelay(_ enabled: Bool) async {
        guard !demo, !enabled || !state.squadCode.isEmpty else { return }
        let code = state.squadCode
        state.bay?.relayCode = enabled ? code : nil
        state.bay?.relayFrom = enabled ? Growth.dayID(Date()) : nil
        state.bay?.relaySteps = []
        bayIssue = nil
        save()
        await refreshBay()
    }

    func refreshBay() async {
        guard !demo, let journal = state.bay, let code = journal.relayCode,
              code == state.squadCode, let from = journal.relayFrom else { return }
        do {
            let steps = try await campus.advanceBay(code: code, days: journal.days.keys.filter { $0 >= from },
                name: String(state.name.prefix(20)), companion: companion.rawValue)
            guard !demo, state.bay?.relayCode == code, state.squadCode == code else { return }
            if steps != state.bay?.relaySteps && steps.count >= (state.bay?.relaySteps.count ?? 0) {
                state.bay?.relaySteps = steps
                save()
            }
            bayIssue = nil
        } catch {
            if !demo && state.bay?.relayCode == code { bayIssue = "接力暂未同步，下拉可以重试。" }
        }
    }
}
