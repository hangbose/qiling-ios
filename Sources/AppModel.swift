import SwiftUI

struct SavedState: Codable {
    var name = "同行者"
    var petName = "星澜"
    var sleepGoal = 8.0
    var workoutGoal = 30.0
    var goalEffectiveDate = Date.distantPast
    var previousSleepGoal = 8.0
    var previousWorkoutGoal = 30.0
    var started: Date?
    var requestedHealth = false
    var ledger: [String: DailyProgress] = [:]
    var lastSync: Date?
    var squadCode = ""
    var sharing = false
}

@MainActor
final class AppModel: ObservableObject {
    @Published var state: SavedState
    @Published var demo = false
    @Published var syncing = false
    @Published var socialBusy = false
    @Published var message: String?
    @Published var status = "连接 Apple 健康，让成长自然发生"
    @Published var members: [SquadMember] = []
    private let health = HealthService()
    private let squad = SquadService()
    private let storageKey = "qiling.state.v1"
    private var demoLedger: [String: DailyProgress] = [:]
    private var demoCheered: Set<String> = []
    private var syncTask: Task<Void, Never>?
    private var syncAgain = false
    private var generation = 0

    init() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode(SavedState.self, from: data) {
            state = saved
        } else { state = SavedState() }
        if state.requestedHealth { startObservers() }
    }

    var ledger: [DailyProgress] {
        Array((demo ? demoLedger : state.ledger).values).sorted { $0.date > $1.date }
    }
    var xp: Int { ledger.reduce(0) { $0 + $1.points } }
    var weekPoints: Int {
        ledger.filter { Growth.weekID($0.date) == Growth.weekID(Date()) }.reduce(0) { $0 + $1.points }
    }
    var today: DailyProgress? { ledger.first { $0.id == Growth.dayID(Date()) } }
    var stage: Int { Growth.stage(xp) }

    func save() {
        do { UserDefaults.standard.set(try JSONEncoder().encode(state), forKey: storageKey) }
        catch { message = "本地保存失败：\(error.localizedDescription)" }
    }

    func connect() async {
        guard !syncing else { return }
        do {
            try await health.authorize()
            generation += 1
            demo = false
            members = []
            if state.started == nil { state.started = Calendar.current.startOfDay(for: Date()) }
            state.requestedHealth = true
            save()
            startObservers()
            await sync()
        } catch { message = error.localizedDescription }
    }

    private func startObservers() {
        health.observe(onChange: { [weak self] completion in
            Task { @MainActor in
                if let self { await self.sync() }
                completion()
            }
        }, onError: { [weak self] error in
            Task { @MainActor in self?.status = "后台同步暂不可用，打开 App 时会重试：\(error.localizedDescription)" }
        })
    }

    func sync() async {
        guard !demo, state.requestedHealth else { return }
        if let task = syncTask {
            syncAgain = true
            await task.value
            return
        }
        syncing = true
        let task = Task { @MainActor in
            repeat {
                self.syncAgain = false
                await self.performSync()
            } while self.syncAgain && !self.demo
        }
        syncTask = task
        await task.value
        syncTask = nil
        syncing = false
    }

    private func performSync() async {
        guard let started = state.started else { return }
        let token = generation
        let cal = Calendar.current
        // Query from adoption date so a long absence still catches up.
        let queryStart = cal.date(byAdding: .day, value: -1, to: started)!
        do {
            let data = try await health.fetch(since: queryStart)
            guard token == generation, !demo else { return }
            var date = cal.startOfDay(for: started)
            let end = cal.startOfDay(for: Date())
            var found = false
            while date <= end {
                let key = Growth.dayID(date)
                let old = state.ledger[key]
                let useNew = date >= state.goalEffectiveDate
                var progress = Growth.progress(
                    on: date, sleep: data.sleep, workouts: data.workouts,
                    sleepGoal: old?.sleepGoal ?? (useNew ? state.sleepGoal : state.previousSleepGoal),
                    workoutGoal: old?.workoutGoal ?? (useNew ? state.workoutGoal : state.previousWorkoutGoal))
                // Empty reads also occur when permission is denied; never revoke earned growth.
                if let old {
                    progress.sleepHours = max(old.sleepHours, progress.sleepHours)
                    progress.workoutMinutes = max(old.workoutMinutes, progress.workoutMinutes)
                }
                if progress.sleepHours > 0 || progress.workoutMinutes > 0 { found = true }
                state.ledger[key] = progress
                date = cal.date(byAdding: .day, value: 1, to: date)!
            }
            state.lastSync = Date()
            status = found ? "已自动结算 · 无需领取" : "暂未获取数据 · 请检查健康权限、佩戴与同步情况"
            save()
        } catch {
            status = "暂时无法同步 · 已有成长已保留"
            message = error.localizedDescription
        }
        // Cloud upload is separate from the HealthKit observer completion.
    }

    func updateGoals(sleep: Double, workout: Double) {
        // Freeze today's targets even if the first health read hasn't finished.
        let todayDate = Calendar.current.startOfDay(for: Date())
        let key = Growth.dayID(todayDate)
        if state.ledger[key] == nil {
            state.ledger[key] = Growth.progress(on: todayDate, sleep: [], workouts: [],
                                              sleepGoal: state.sleepGoal, workoutGoal: state.workoutGoal)
        }
        if state.goalEffectiveDate <= Date() {
            state.previousSleepGoal = state.sleepGoal
            state.previousWorkoutGoal = state.workoutGoal
        }
        state.sleepGoal = sleep
        state.workoutGoal = workout
        state.goalEffectiveDate = Calendar.current.date(byAdding: .day, value: 1, to: todayDate)!
        save()
    }

    func enterDemo() {
        generation += 1
        demo = true
        demoLedger = [:]
        for offset in 0..<9 {
            let date = Calendar.current.date(byAdding: .day, value: -offset, to: Date())!
            let p = DailyProgress(id: Growth.dayID(date), date: date, sleepHours: offset == 0 ? 8.2 : 8.5,
                                  workoutMinutes: offset == 0 ? 18 : 35, sleepGoal: 8, workoutGoal: 30)
            demoLedger[p.id] = p
        }
        status = "演示模式 · 所有数据均为示例"
        demoCheered = []
        members = [
            SquadMember(id: "demo-1", name: "小雨", points: 550, xp: 1800, cheers: 3, updated: Date()),
            SquadMember(id: "demo-me", name: state.petName, points: weekPoints, xp: xp, cheers: 1, updated: Date()),
            SquadMember(id: "demo-2", name: "阿森", points: 400, xp: 3200, cheers: 2, updated: Date())
        ]
    }

    func leaveDemo() async {
        generation += 1
        demo = false
        members = []
        status = "连接 Apple 健康，让成长自然发生"
        await sync()
    }

    func connectSquad(code: String?) async {
        guard !demo, !socialBusy, state.sharing else { return }
        socialBusy = true
        defer { socialBusy = false }
        do {
            if let code {
                let cleaned = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                guard cleaned.range(of: "^[A-F0-9]{10}$", options: .regularExpression) != nil else {
                    message = "邀请码应为 10 位字母或数字。"; return
                }
                try await squad.validate(code: cleaned)
                state.squadCode = cleaned
            } else { state.squadCode = try await squad.create() }
            save()
            await refreshSquad()
        } catch { message = error.localizedDescription }
    }

    func refreshSquad() async {
        guard !demo, !state.squadCode.isEmpty else { return }
        let code = state.squadCode
        let week = Growth.weekID(Date())
        do {
            if state.sharing {
                try await squad.publish(code: code, week: week, name: String(state.name.prefix(20)),
                                        points: weekPoints, xp: xp)
            }
            let result = try await squad.members(code: code, week: week)
            guard !demo, state.squadCode == code else { return }
            members = result
        } catch { message = "小队暂未同步：\(error.localizedDescription)" }
    }

    func cheer(_ member: SquadMember) async {
        if demo {
            guard demoCheered.insert(member.id).inserted else { return }
            members = members.map {
                $0.id == member.id ? SquadMember(id: $0.id, name: $0.name, points: $0.points,
                                                xp: $0.xp, cheers: $0.cheers + 1, updated: $0.updated) : $0
            }
            return
        }
        do {
            try await squad.cheer(member: member, code: state.squadCode, week: Growth.weekID(Date()))
            await refreshSquad()
        } catch { message = error.localizedDescription }
    }
}
