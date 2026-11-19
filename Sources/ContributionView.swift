import SwiftUI

struct ContributionView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.scenePhase) private var phase
    @State private var focusSeconds = 0
    @State private var focusing = false
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("今日贡献").font(.largeTitle.bold())
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
                GroupBox("轻习惯 · 只增加宠物经验") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("自愿记录，每项每天一次，不影响抢地和小队排名。")
                        ForEach(["喝水", "阅读"], id: \.self) { habit in
                            Button(model.habitDone(habit) ? "\(habit) · 已记录" : "\(habit)了 · +5 经验") { model.rewardHabit(habit) }
                                .disabled(model.demo || model.habitDone(habit))
                        }
                        Text("专注陪伴 · \(focusSeconds / 60):\(String(format: "%02d", focusSeconds % 60)) / 15:00")
                        Text("保持此页在前台，离开或锁屏暂停。离开页面会结束本次计时。")
                            .font(.caption).foregroundStyle(.secondary)
                        Button(model.habitDone("专注") ? "今日专注奖励已获得" : (focusing ? "暂停" : "和精灵一起专注")) { focusing.toggle() }
                            .disabled(model.demo || model.habitDone("专注"))
                        PetView(stage: model.stage, xp: model.xp, companion: model.companion).frame(height: 140)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
            }.padding()
        }
        .background(Palette.background)
        .onReceive(timer) { _ in
            guard focusing, phase == .active, !model.habitDone("专注") else { return }
            focusSeconds += 1
            if focusSeconds >= 900 { model.rewardHabit("专注"); focusing = false }
        }
        .onChange(of: phase) { _, value in if value != .active { focusing = false } }
        .refreshable { await model.sync(); await model.refreshSquad() }
    }
}
