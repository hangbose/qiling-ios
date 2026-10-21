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
    case companion = "伙伴", square = "广场", growth = "成长", profile = "我的"
    var symbol: String {
        switch self {
        case .companion: return "pawprint.fill"
        case .square: return "person.2.fill"
        case .growth: return "chart.bar.fill"
        case .profile: return "person.fill"
        }
    }
}

enum Palette {
    static let background = Color(red: 0.97, green: 0.98, blue: 0.97)
    static let ink = Color(red: 0.08, green: 0.11, blue: 0.09)
    static let green = Color(red: 0.08, green: 0.51, blue: 0.37)
    static let lime = Color(red: 0.65, green: 0.92, blue: 0.81)
}

struct RootView: View {
    @EnvironmentObject private var model: AppModel
    @State private var tab: AppTab = .companion
    var body: some View {
        Group {
            switch tab {
            case .companion: CompanionHomeView(tab: $tab)
            case .square: FriendSquareView()
            case .growth: GrowthRecordView()
            case .profile: SettingsView()
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            HStack(spacing: 4) {
                ForEach(AppTab.allCases, id: \.self) { item in
                    Button { tab = item } label: {
                        VStack(spacing: 5) {
                            Image(systemName: item.symbol).font(.system(size: 21, weight: .semibold))
                            Text(item.rawValue).font(.system(size: 10, weight: tab == item ? .semibold : .regular))
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                        .background(tab == item ? Palette.lime.opacity(0.30) : .clear,
                                    in: RoundedRectangle(cornerRadius: 25))
                        .foregroundStyle(tab == item ? Palette.green : .gray)
                    }
                    .accessibilityAddTraits(tab == item ? .isSelected : [])
                }
            }
            .padding(5).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 30))
            .overlay(RoundedRectangle(cornerRadius: 30).stroke(.white.opacity(0.9), lineWidth: 1))
            .shadow(color: .black.opacity(0.04), radius: 15, y: -3)
            .padding(.horizontal, 15).padding(.bottom, 4)
        }
        .tint(Palette.green)
        .alert("栖灵", isPresented: Binding(get: { model.message != nil }, set: { if !$0 { model.message = nil } })) {
            Button("知道了") { model.message = nil }
        } message: { Text(model.message ?? "") }
    }
}

// Original generated creature art, shared with the interactive preview.
struct PetView: View {
    var stage: Int = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var floating = false
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Ellipse().fill(Palette.green.opacity(0.12))
                    .frame(width: proxy.size.width * 0.50, height: 12)
                    .offset(y: proxy.size.height * 0.43)
                Image("PetStage\(min(2, max(0, stage)))")
                    .resizable().scaledToFit()
                    .padding(8)
                    .offset(y: floating && !reduceMotion ? -4 : 2)
                    .shadow(color: Palette.green.opacity(0.16), radius: 14, y: 8)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true)) { floating = true }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("星澜，\(stage == 0 ? "星芽幼体" : stage == 1 ? "逐光成长体" : "月辉守护体")")
    }
}

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var sleep = 8.0
    @State private var workout = 30.0
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 18) {
                        PetView(stage: model.stage).frame(width: 96, height: 104)
                        VStack(alignment: .leading, spacing: 8) {
                            Text(model.state.name).font(.title3.bold())
                            Text("与\(model.state.petName)一起成长").font(.subheadline).foregroundStyle(.secondary)
                            Text("\(model.xp) 成长经验").font(.caption).foregroundStyle(Palette.green)
                        }
                    }.padding(.vertical, 7)
                }
                Section("伙伴档案") {
                    TextField("我的昵称", text: $model.state.name)
                        .onChange(of: model.state.name) { _, _ in model.save() }
                    TextField("精灵名字", text: $model.state.petName)
                        .onChange(of: model.state.petName) { _, _ in model.save() }
                }
                Section {
                    Stepper("睡眠目标  \(sleep.formatted()) 小时", value: $sleep, in: 6...10, step: 0.5)
                    Stepper("锻炼目标  \(workout.formatted()) 分钟", value: $workout, in: 10...90, step: 5)
                    Button("保存目标，明天生效") {
                        model.updateGoals(sleep: sleep, workout: workout)
                        model.message = "目标已保存，从明天起生效。今天的奖励规则不变。"
                    }.disabled(model.demo)
                } header: { Text("按自己的节奏来") } footer: {
                    Text("默认 8 小时与 30 分钟是可调整的游戏目标，并非个体健康建议。睡眠按前一日中午至当日中午归属，运动读取已记录的锻炼时段。")
                }
                Section("Apple 健康") {
                    Text(model.status).font(.subheadline)
                    if let last = model.state.lastSync, !model.demo {
                        LabeledContent("上次读取", value: last.formatted(date: .abbreviated, time: .shortened))
                    }
                    Button("连接／检查健康授权") { Task { await model.connect() } }
                    Button("重新同步") { Task { await model.sync() } }
                        .disabled(model.syncing || model.demo || !model.state.requestedHealth)
                    Text("没有记录不代表没有努力。权限、未佩戴和同步延迟都可能导致缺少数据；不会扣除精灵经验。可在系统健康权限设置中撤销读取。")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("社交隐私") {
                    Toggle("自动共享成长摘要", isOn: $model.state.sharing)
                        .onChange(of: model.state.sharing) { _, enabled in
                            model.save()
                            if enabled { Task { await model.refreshSquad() } }
                        }.disabled(model.demo)
                    Text("只共享昵称、总经验和周积分。关闭后停止新的上传，已共享的记录仍保留。当前为邀请测试版，尚未提供云端删除和正式账号管理。")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("体验预览") {
                    if model.demo {
                        Button("退出演示，返回真实数据") { Task { await model.leaveDemo() } }
                    } else {
                        Button("进入演示模式") { model.enterDemo() }
                    }
                    Text("演示记录与真实成长账本隔离，不上传到小队。").font(.caption).foregroundStyle(.secondary)
                }
                Section {
                    Text("栖灵 · 0.1 邀请测试版").foregroundStyle(.secondary)
                }
            }
            .navigationTitle("我的")
            .onAppear { sleep = model.state.sleepGoal; workout = model.state.workoutGoal }
        }
    }
}

extension View {
    func card() -> some View {
        padding(18).background(.white, in: RoundedRectangle(cornerRadius: 22))
    }
}
