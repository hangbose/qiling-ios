import SwiftUI

struct CompanionHomeView: View {
    @EnvironmentObject private var model: AppModel
    @Binding var tab: AppTab
    @State private var detail: DetailContent?
    @State private var renaming = false
    @State private var sharingCard = false
    @State private var previewingCompanions = false
    @State private var draftName = ""
    private var earned: Int { model.today?.points ?? 0 }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 15) {
                    FieldCover(art: "BayPark", title: "伙伴营地", caption: "深圳 · 人才公园", height: 265) {
                        InteractivePetView(stage: model.stage, xp: model.xp, name: model.state.petName)
                            .frame(width: 165, height: 156).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                            .padding(.bottom, 10)
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(model.state.petName).font(BayUI.type(25))
                                Text("\(model.companionStageName) · Lv.\(1 + model.xp / 100)").font(.subheadline)
                            }
                            Spacer()
                            RoundAction(symbol: "pencil", label: "修改伙伴名字") { draftName = model.state.petName; renaming = true }
                            RoundAction(symbol: "square.and.arrow.up", label: "晒晒伙伴") { sharingCard = true }
                        }
                        ProgressView(value: Double(model.xp), total: Double(Growth.nextMilestone(model.xp))).tint(BayUI.rust)
                        HStack {
                            Text("距下一次成长还差 \(Growth.nextMilestone(model.xp) - model.xp) XP").font(.caption)
                            Spacer()
                            Button("成长手帐") { tab = .growth }.font(.subheadline)
                        }
                    }.softPanel()
                    HStack {
                        Button { previewingCompanions = true } label: {
                            Label("伙伴图鉴", systemImage: "pawprint.fill").frame(maxWidth: .infinity)
                        }.buttonStyle(BayKey(primary: true))
                        NavigationLink { ContributionView() } label: {
                            Label("今日贡献", systemImage: "book").frame(maxWidth: .infinity)
                        }.buttonStyle(BayKey())
                    }
                    SectionHeading(title: "今日补给", actionTitle: "同步详情") {
                        detail = DetailContent(title: "今日同步", text: model.status)
                    }
                    HStack(spacing: 10) {
                        HabitTile(symbol: "moon.fill", title: "睡眠", value: model.today?.sleepHours ?? 0,
                                  goal: model.today?.sleepGoal ?? model.state.sleepGoal, unit: "小时", color: BayUI.navy) { showHabit(sleep: true) }
                        HabitTile(symbol: "figure.run", title: "运动", value: model.today?.workoutMinutes ?? 0,
                                  goal: model.today?.workoutGoal ?? model.state.workoutGoal, unit: "分钟", color: BayUI.rust) { showHabit(sleep: false) }
                    }
                    let streak = GrowthSummary(days: model.ledger, now: Date(), started: model.state.started).currentStreak
                    Text("今日 \(model.today?.steps ?? 0) 步 · 已获 \(earned) 能量 · 连续达标 \(streak) 天")
                        .font(.footnote).foregroundStyle(BayUI.muted)
                    if !model.state.requestedHealth && !model.demo {
                        Button { Task { await model.connect() } } label: {
                            Label("连接 Apple 健康", systemImage: "applewatch")
                        }.buttonStyle(BayKey(primary: true))
                        Button("先体验演示") { model.enterDemo() }
                    }
                }.padding(.horizontal, 14).padding(.bottom, 20)
            }.background(BayUI.paper).toolbar(.hidden, for: .navigationBar)
            .refreshable { await model.sync() }
            .sheet(isPresented: $previewingCompanions) { NewCompanionPreview() }
            .sheet(isPresented: $sharingCard) { GrowthShareView() }
            .sheet(item: $detail) { DetailSheet(content: $0) }
            .alert("给伙伴起个名字", isPresented: $renaming) {
                TextField("伙伴名字", text: $draftName)
                Button("保存") {
                    let name = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !name.isEmpty { model.state.petName = String(name.prefix(12)); model.save() }
                }
                Button("取消", role: .cancel) { }
            }
        }
    }
    private func showHabit(sleep: Bool) {
        let value = sleep ? model.today?.sleepHours ?? 0 : model.today?.workoutMinutes ?? 0
        let unit = sleep ? "小时" : "分钟"
        detail = DetailContent(title: sleep ? "睡眠滋养" : "运动滋养",
            text: "当前记录：\(value.formatted(.number.precision(.fractionLength(1)))) \(unit)\n\n"
                + (sleep ? "只计算实际睡眠时段，清醒与卧床时间不计入。跨夜睡眠归属起床日。" : "读取已记录的锻炼时段，合并重叠记录。")
                + "\n\n新规则：睡眠达标 30 分，活动最多 70 分，规律作息 10 分。步行和训练取高值，已有经验保留。无记录时不能区分未佩戴、权限或同步延迟，不判为失败。"
                + (model.demo ? "\n\n当前为演示数据。" : ""))
    }
}

struct HabitTile: View {
    let symbol: String
    let title: String
    let value: Double
    let goal: Double
    let unit: String
    let color: Color
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 13) {
                HStack(spacing: 7) {
                    Image(systemName: symbol).font(.system(size: 17, weight: .medium))
                        .frame(width: 31, height: 31).background(color.opacity(0.13), in: Circle()).foregroundStyle(color)
                    Text(title).font(.system(size: 14, weight: .semibold))
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").font(.system(size: 11)).foregroundStyle(.secondary)
                }
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(value > 0 ? value.formatted(.number.precision(.fractionLength(0...1))) : "—")
                        .font(.system(size: 36, weight: .semibold)).tracking(-1)
                    Text(unit).font(.system(size: 13, weight: .semibold))
                }
                Text("目标 \(goal.formatted()) \(unit)\(value >= goal ? " ✓" : "")")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }.foregroundStyle(Palette.ink).frame(maxWidth: .infinity, alignment: .leading)
                .padding(13).fieldPlate(BayUI.cream)
        }.buttonStyle(.plain)
    }
}
