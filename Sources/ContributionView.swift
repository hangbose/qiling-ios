import SwiftUI

struct ContributionView: View {
    @EnvironmentObject private var model: AppModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                FieldCover(art: "BayPark", title: "今日贡献", caption: "营地 · 补给记录", height: 130) { EmptyView() }
                Text("\(model.today?.contribution ?? 0) / 110").font(.system(size: 38, weight: .bold)).foregroundStyle(Palette.green)
                Text("健康数据自动贡献给领地和小队。精灵经验永久保留，领地贡献每天重置。")
                GroupBox("自动结算") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("日常步行 · \(model.today?.steps ?? 0) 步")
                        Text("训练 · \(Int(model.today?.workoutMinutes ?? 0)) 分钟")
                        Text("活动贡献 \(model.today?.activityContribution ?? 0) / 70")
                        Text("步行每千步 10 分，上限 60；训练每 5 分钟 10 分，上限 60。两者取高值，训练满 15 分钟再加 10 分。")
                            .font(.caption).foregroundStyle(.secondary)
                        Divider()
                        Text("睡眠达标 · \(model.today?.sleepComplete == true ? 30 : 0) / 30")
                        Text("规律作息 · \(model.today?.regularSleep == true ? 10 : 0) / 10")
                        Text("连续三天主要睡眠的入睡时间相差不超过 1 小时；每段至少读到 4 小时睡眠才参与判断。这是游戏规则，不是睡眠建议。")
                            .font(.caption).foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
                GroupBox("今天的运动") {
                    VStack(alignment: .leading, spacing: 10) {
                        if (model.today?.workouts ?? []).isEmpty {
                            Text("还没有读到分类训练。华为运动健康需先把训练同步至 Apple 健康；仅有步数不会自动识别成某项运动。")
                        }
                        ForEach(model.today?.workouts ?? []) { item in
                            HStack {
                                Text(item.kind)
                                Spacer()
                                Text("\(Int(item.minutes)) 分钟")
                                Text(item.start, style: .time).foregroundStyle(.secondary)
                            }
                        }
                        Text("记录用于展示；重叠时段合并计分，不累加多台设备的训练时长。")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                HabitCollectionView()
                GroupBox("轻习惯") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("自愿记录，每项每天一次，不影响抢地和小队排名。")
                        ForEach(["喝水", "阅读"], id: \.self) { habit in
                            Button(model.habitDone(habit) ? "\(habit) · 已记录" : "\(habit)了 · +5 经验") { model.rewardHabit(habit) }
                                .disabled(model.demo || model.habitDone(habit))
                        }
                        FocusHabitView()
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
            }.padding()
        }
        .background(Palette.background)
        .refreshable { await model.sync(); await model.refreshSquad() }
    }
}

struct FocusSession {
    static let target = 15 * 60
    private var accumulated: TimeInterval = 0
    private(set) var started: TimeInterval?

    mutating func start(at now: TimeInterval) {
        if started == nil { started = now }
    }
    mutating func pause(at now: TimeInterval) {
        guard let started else { return }
        accumulated += max(0, now - started)
        self.started = nil
    }
    func seconds(at now: TimeInterval) -> Int {
        min(Self.target, Int(accumulated + (started.map { max(0, now - $0) } ?? 0)))
    }
}

struct FocusHabitView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.scenePhase) private var phase
    var startOnAppear = false
    @State private var session = FocusSession()
    @State private var elapsed = 0
    private var now: TimeInterval { ProcessInfo.processInfo.systemUptime }
    private var done: Bool { model.habitDone("专注") }

    private func update() {
        let time = now
        elapsed = session.seconds(at: time)
        if elapsed == FocusSession.target {
            session.pause(at: time)
            model.rewardHabit("专注", focusedSeconds: elapsed)
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PetView(stage: model.stage, xp: model.xp, companion: model.companion).frame(height: 140)
            Text(done ? "今天的专注已完成" : String(format: "%02d:%02d / 15:00", elapsed / 60, elapsed % 60))
                .font(.title2.monospacedDigit())
            Text("和精灵专注 15 分钟可得 10 经验。锁屏会暂停，关闭此页会结束本次计时。")
                .font(.footnote).foregroundStyle(.secondary)
            if !done {
                Button(session.started != nil ? "暂停" : elapsed > 0 ? "继续专注" : "开始专注") {
                    if session.started != nil { update(); session.pause(at: now) }
                    else { session.start(at: now) }
                }.disabled(model.demo)
            }
        }
        .onAppear { if startOnAppear && !done && !model.demo && phase == .active { session.start(at: now) } }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            if session.started != nil && phase == .active { update() }
        }
        .onChange(of: phase) { _, value in
            if value != .active && session.started != nil { update(); session.pause(at: now) }
        }
        .onDisappear { if session.started != nil { update(); session.pause(at: now) } }
    }
}
