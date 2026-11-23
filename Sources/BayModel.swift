import Foundation

extension AppModel {
    func switchDemoRelay(_ enabled: Bool) {
        guard demo else { return }
        demoBay.relayCode = "demo"
        demoBay.relayPaused = !enabled
    }

    func demoBayDay(kind: String, relay: Bool) {
        guard demo else { return }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        let previous = demoBay.days.keys.max().flatMap { formatter.date(from: $0) } ?? Date()
        guard let next = Calendar.current.date(byAdding: .day, value: 1, to: previous) else { return }
        let day = Growth.dayID(next)
        demoBay.record(day: day, reason: ["按时入睡","步行千步","阅读"][demoBay.days.count % 3])
        if relay {
            demoBay.relaySteps.append(BayRelayStep(key: "me|" + day, name: "我", companion: kind))
            demoBay.relaySteps.append(BayRelayStep(key: "friend|" + day, name: "小雨", companion: "xiaoying"))
        }
    }

    func buyBaySouvenir(_ item: BaySouvenir) {
        if demo {
            _ = demoBay.buy(item)
        } else if state.bay?.buy(item) == true {
            save()
        }
    }

    func placeBayItem(_ item: BaySouvenir, district: Int, x: Double, trail: BayTrail) {
        if demo { demoBay.place(item, in: district, at: x, progress: trail) }
        else { state.bay?.place(item, in: district, at: x, progress: trail); save() }
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
        state.bay?.setRelay(enabled, code: code, today: Growth.dayID(Date()))
        bayIssue = nil
        save()
        await refreshBay()
    }

    func refreshBay() async {
        guard !demo, let journal = state.bay, journal.relayPaused != true, let code = journal.relayCode,
              code == state.squadCode, let from = journal.relayFrom else { return }
        do {
            let update = try await campus.advanceBay(code: code, days: journal.eligibleRelayDays,
                name: String(state.name.prefix(20)), companion: companion.rawValue)
            guard !demo, state.bay?.relayPaused != true, state.bay?.relayCode == code, state.bay?.relayFrom == from, state.squadCode == code else { return }
            if update.steps.count >= (state.bay?.relaySteps.count ?? 0), update.steps != state.bay?.relaySteps || state.bay?.relayUser != update.user || state.bay?.shortRelaySteps != update.anchor {
                state.bay?.shortRelaySteps = update.anchor
                state.bay?.relaySteps = update.steps
                state.bay?.relayUser = update.user
                save()
            }
            bayIssue = nil
        } catch {
            if !demo && state.bay?.relayPaused != true && state.squadCode == code && state.bay?.relayFrom == from { bayIssue = "接力暂未同步，下拉可以重试。" }
        }
    }
}
