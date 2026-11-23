import SwiftUI

@main
struct QilingApp: App {
    @StateObject private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase
    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(model).preferredColorScheme(.light)
                .task {
                    if ProcessInfo.processInfo.arguments.contains("--demo") { model.enterDemo() }
                    else { await model.sync(); await model.refreshSquad() }
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { Task { await model.sync(); await model.refreshSquad() } }
                }
        }
    }
}

enum AppTab: String, CaseIterable {
    case journey = "旅途", companion = "伙伴", square = "广场", growth = "成长", profile = "我的"
    var symbol: String {
        switch self {
        case .journey: return "map.fill"
        case .companion: return "pawprint.fill"
        case .square: return "person.2.fill"
        case .growth: return "chart.bar.fill"
        case .profile: return "person.fill"
        }
    }
}

enum Palette {
    static let background = BayUI.paper
    static let ink = BayUI.ink
    static let green = BayUI.rust
    static let lime = BayUI.blush
}

struct RootView: View {
    @EnvironmentObject private var model: AppModel
    @State private var tab: AppTab = {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("--preview-companion") { return .companion }
        if args.contains("--preview-square") { return .square }
        if args.contains("--preview-growth") { return .growth }
        if args.contains("--preview-profile") { return .profile }
        return .journey
    }()
    var body: some View {
        VStack(spacing: 0) {
            content.frame(maxWidth: .infinity, maxHeight: .infinity)
            journeyTabs.fixedSize(horizontal: false, vertical: true)
        }
        .background(BayUI.paper).foregroundStyle(BayUI.ink)
        .groupBoxStyle(FieldGroupStyle()).tint(BayUI.rust)
        .sheet(item: Binding(get: { tab == .journey ? nil : model.celebration }, set: { if $0 == nil { model.dismissCelebration() } })) { event in
            GrowthCelebrationView(event: event, name: model.state.petName) { model.dismissCelebration() }
        }
        .alert("栖灵", isPresented: Binding(get: { model.message != nil }, set: { if !$0 { model.message = nil } })) {
            Button("知道了") { model.message = nil }
        } message: { Text(model.message ?? "") }
    }

    private var content: some View {
        Group {
            if ProcessInfo.processInfo.arguments.contains("--preview-contributions") {
                NavigationStack { ContributionView() }
            } else if ProcessInfo.processInfo.arguments.contains("--preview-campus") {
                NavigationStack { CampusMapView() }
            } else {
                switch tab {
                case .journey: BayJourneyView(tab: $tab)
                case .companion: CompanionHomeView(tab: $tab)
                case .square: FriendSquareView(tab: $tab)
                case .growth: GrowthRecordView()
                case .profile: SettingsView()
                }
            }
        }
    }

    private var journeyTabs: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { item in
                Button { tab = item } label: {
                    VStack(spacing: 3) {
                        Image(systemName: item.symbol).font(.system(size: 15))
                        Text(item.rawValue).font(BayUI.type(13))
                    }.frame(maxWidth: .infinity, minHeight: 47)
                }.foregroundStyle(tab == item ? BayUI.rust : BayUI.muted)
                    .accessibilityAddTraits(tab == item ? .isSelected : [])
            }
        }.padding(.horizontal, 9).background(BayUI.cream)
            .overlay(alignment: .top) { Rectangle().fill(BayUI.rim).frame(height: 1) }
    }

}

struct PetView: View {
    var stage: Int = 0
    var xp: Int? = nil
    var companion: CompanionKind = .legacy
    private var detailLevel: Int { xp.map { Growth.appearance($0) } ?? 0 }
    var body: some View {
        GeometryReader { geo in
            ZStack {
                Ellipse().fill(BayUI.ink.opacity(0.16)).frame(width: min(geo.size.width, geo.size.height) * 0.49, height: max(3, geo.size.height * 0.04)).offset(y: geo.size.height * 0.34)
                BaySprite(kind: companion.rawValue, walking: false, grown: stage > 0 || detailLevel >= 3)
                    .scaleEffect(stage >= 2 ? 1.06 : detailLevel == 0 && stage == 0 ? 0.84 : 0.96)
                    .saturation(detailLevel >= 2 ? 1.16 : 1)
                if detailLevel >= 3 || stage > 0 {
                    Image(systemName: detailLevel >= 4 || stage >= 2 ? "sparkles" : "star.fill")
                        .foregroundStyle(BayUI.rust).offset(x: geo.size.width * 0.31, y: -geo.size.height * 0.25)
                }
            }.frame(width: geo.size.width, height: geo.size.height)
        }.accessibilityLabel("\(companion.title)，成长中的伙伴")
    }
}

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var sleep = 8.0
    @State private var workout = 30.0
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    FieldCover(art: "BayShore", title: "旅行护照", caption: "深圳 · 海岸签发", height: 168) { EmptyView() }
                    HStack(spacing: 16) {
                        PetView(stage: model.stage, xp: model.xp, companion: model.companion)
                            .frame(width: 68, height: 76).background(BayUI.blush).overlay(Rectangle().stroke(BayUI.rim))
                        VStack(alignment: .leading, spacing: 5) {
                            Text(model.state.name).font(BayUI.type(22))
                            Text("同行伙伴　\(model.state.petName)").font(.subheadline)
                            Text("\(model.xp) XP").font(.caption.monospacedDigit()).foregroundStyle(BayUI.rust)
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading).softPanel()
                    GroupBox("旅人登记") {
                        LabeledContent("我的昵称") { TextField("昵称", text: $model.state.name).multilineTextAlignment(.trailing) }
                            .onChange(of: model.state.name) { _, _ in model.save() }
                        LabeledContent("精灵名字") { TextField("名字", text: $model.state.petName).multilineTextAlignment(.trailing) }
                            .onChange(of: model.state.petName) { _, _ in model.save() }
                    }
                    GroupBox("每日目标") {
                        Stepper("睡眠目标  \(sleep.formatted()) 小时", value: $sleep, in: 6...10, step: 0.5)
                        Stepper("锻炼目标  \(workout.formatted()) 分钟", value: $workout, in: 10...90, step: 5)
                        Button("保存目标，明天生效") {
                            model.updateGoals(sleep: sleep, workout: workout)
                            model.message = "目标已保存，从明天起生效。今天的奖励规则不变。"
                        }.disabled(model.demo)
                        Text("默认 8 小时与 30 分钟是可调整的游戏目标，并非个体健康建议。睡眠按前一日中午至当日中午归属，运动读取已记录的锻炼时段。").font(.footnote).foregroundStyle(BayUI.muted)
                    }
                    GroupBox("手表与健康") {
                        Text(model.status).font(.subheadline)
                        if let last = model.state.lastSync, !model.demo {
                            LabeledContent("上次读取", value: last.formatted(date: .abbreviated, time: .shortened))
                        }
                        if !model.demo, let report = model.sensorReport {
                            Text(report).font(.caption).foregroundStyle(.secondary)
                        }
                        DisclosureGroup("华为手表有记录，栖灵没有？") {
                            Text("请在 iPhone 自带的‘健康’里查看‘睡眠’、‘步数’或‘体能训练’，确认记录来自华为运动健康。步行与训练取高计分，睡眠单独结算。再到健康头像 → 隐私 → App → 栖灵检查读取权限，返回这里重新同步。成长从领养当天起计算。")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                        Button("连接／检查健康授权") { Task { await model.connect() } }
                        Button("重新同步") { Task { await model.sync() } }
                            .disabled(model.syncing || model.demo || !model.state.requestedHealth)
                        Text("没有记录不代表没有努力。权限、未佩戴和同步延迟都可能导致缺少数据；不会扣除精灵经验。可在系统健康权限设置中撤销读取。")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    GroupBox("小队共享") {
                        Toggle("自动共享成长摘要", isOn: $model.state.sharing)
                            .onChange(of: model.state.sharing) { _, enabled in
                                model.save()
                                if enabled { Task { await model.refreshSquad() } }
                            }.disabled(model.demo)
                        Text("只共享昵称、总经验和周积分。关闭后停止新的上传，已共享的记录仍保留。当前为邀请测试版，尚未提供云端删除和正式账号管理。")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    GroupBox("演示模式") {
                        if model.demo {
                            Button("退出演示，返回真实数据") { Task { await model.leaveDemo() } }
                        } else {
                            Button("进入演示模式") { model.enterDemo() }
                        }
                        Text("演示记录与真实成长账本隔离，不上传到小队。").font(.caption).foregroundStyle(.secondary)
                    }
                }.padding(.horizontal, 14).padding(.bottom, 20)
            }.background(BayUI.paper).toolbar(.hidden, for: .navigationBar)
            .onAppear { sleep = model.state.sleepGoal; workout = model.state.workoutGoal }
        }
    }
}
