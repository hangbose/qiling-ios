import SwiftUI

struct CampusMapView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.scenePhase) private var phase
    @State private var selected: Int?
    @State private var confirming = false
    @State private var sharingCard = false
    @State private var showingGuide = false
    @State private var now = Date()
    private let dayTimer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()
    private let mint = Color(red: 0.65, green: 0.96, blue: 0.72)
    private let night = Color(red: 0.07, green: 0.10, blue: 0.10)
    static func title(_ index: Int) -> String {
        ["书香", "运动", "林荫", "湖畔", "生活", "花园"][index / 4] + " \(index % 4 + 1)"
    }
    private var board: CampusBoard? {
        guard model.demo || model.state.campusSharing == true,
              let board = model.campusBoard, board.day == CampusBoard.dayID(now) else { return nil }
        return board
    }
    private var ownPlot: CampusPlot? { board?.plots.first { $0.owner == model.campusUser } }
    private var chosenPlot: CampusPlot? { board?.plots.first { $0.id == selected } }
    private var protected: Bool {
        guard let plot = chosenPlot else { return false }
        return plot.owner != model.campusUser && plot.protectedUntil > now
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ZStack(alignment: .bottomTrailing) {
                GeometryReader { geometry in
                    ScrollView(.vertical) {
                        CampusTerritoryAtlas(plots: board?.plots ?? [], user: model.campusUser, selected: $selected)
                            .frame(height: max(400, geometry.size.height))
                    }.scrollBounceBehavior(.basedOnSize)
                        .allowsHitTesting(board != nil)
                }
                if board == nil {
                    VStack(spacing: 8) {
                        Image(systemName: "map").font(.title)
                        Text(model.campusBusy ? "正在连接校园…" : "你的校园，等你点亮")
                            .font(.headline)
                        Text("连接后显示今日真实领地").font(.caption).foregroundStyle(.secondary)
                    }.padding(20).background(night.opacity(0.94), in: RoundedRectangle(cornerRadius: 22))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                Button {
                    if let ownPlot { selected = ownPlot.id }
                    else { selected = nil }
                } label: {
                    Image(systemName: "flag.fill").font(.body.bold()).frame(width: 44, height: 44)
                }.foregroundStyle(mint).background(night, in: Circle())
                    .accessibilityLabel("查看我的领地").padding(.trailing, 14).padding(.bottom, 34)
                    .disabled(board == nil)
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
            bottomCard
        }
        .foregroundStyle(.white)
        .background(night)
        .toolbarBackground(night, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingGuide) { guide }
        .sheet(isPresented: $sharingCard) { CampusShareView() }
        .task {
            await model.refreshCampus()
            if ProcessInfo.processInfo.arguments.contains("--demo") && ProcessInfo.processInfo.arguments.contains("--preview-campus-selection") { selected = 2 }
        }
        .onReceive(dayTimer) { date in
            now = date
            if model.campusBoard?.day != CampusBoard.dayID(Date()) {
                selected = nil
                Task { await model.refreshCampus() }
            }
        }
        .onChange(of: phase) { _, value in
            if value == .active { now = Date(); Task { await model.refreshCampus() } }
        }
        .confirmationDialog("确认占领或挑战？成功后原有领地会释放；有效挑战会使用一次机会。", isPresented: $confirming, titleVisibility: .visible) {
            Button("确认") { if let selected { Task { await model.refreshCampus(plot: selected) } } }
            Button("取消", role: .cancel) { }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("深大 · 精灵领地").font(.title2.bold())
                    Text(model.demo ? "演示地图 · 不参与真实抢地" : "粤海校园 · 每日刷新")
                        .font(.caption).foregroundStyle(.white.opacity(0.55))
                }
                Spacer()
                Button { showingGuide = true } label: {
                    Image(systemName: "info.circle").font(.title3).frame(width: 44, height: 44)
                }.accessibilityLabel("守护规则与校园足迹")
                Button { Task { await model.sync(); await model.refreshCampus() } } label: {
                    if model.campusBusy { ProgressView().tint(mint).frame(width: 44, height: 44) }
                    else { Image(systemName: "arrow.clockwise").font(.title3).frame(width: 44, height: 44) }
                }.disabled(model.campusBusy || model.demo || model.state.campusSharing != true)
                    .accessibilityLabel("同步健康贡献并刷新地图")
            }
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text("\(model.campusScore)").font(.system(size: 36, weight: .bold, design: .rounded)).foregroundStyle(mint)
                Text("/ 110 今日贡献").font(.caption).foregroundStyle(.white.opacity(0.65))
                Spacer()
                Label(CampusBoard.open(now) ? "22:00 休战" : "今日已休战", systemImage: "moon")
                    .font(.caption2).foregroundStyle(.white.opacity(0.65))
            }
        }.padding(.horizontal, 20).padding(.vertical, 12)
    }

    private var bottomCard: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Capsule().fill(.white.opacity(0.2)).frame(width: 32, height: 4).frame(maxWidth: .infinity)
                if let error = model.campusError {
                    Label(error, systemImage: "exclamationmark.circle").font(.caption).foregroundStyle(.orange)
                }
                if model.state.campusSharing != true && !model.demo {
                    Text("让日常坚持，变成你的领地").font(.headline)
                    Text("参与后公开昵称、精灵、贡献分和领地，不公开原始健康记录。当前为邀请测试。")
                        .font(.caption).foregroundStyle(.white.opacity(0.65))
                    action("参与校园地图", icon: "flag.fill") {
                        model.state.campusSharing = true; model.save()
                        Task { await model.refreshCampus() }
                    }
                } else if let selected, board != nil {
                    selectionCard(selected)
                } else {
                    HStack {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(ownPlot == nil ? "下一块领地，属于你" : "你的精灵正在守护校园").font(.headline)
                            Text(ownPlot.map { "\(Self.title($0.id)) · 守护值 \($0.score)" } ?? "点选地图地块，查看占领与保护状态")
                                .font(.caption).foregroundStyle(.white.opacity(0.6))
                        }
                        Spacer()
                        Image(systemName: "pawprint.fill").font(.title).foregroundStyle(mint)
                    }
                    HStack(spacing: 18) {
                        legend("我的", tint: mint)
                        legend("他人", tint: .orange)
                        legend("空地", tint: .gray)
                        Spacer()
                        Text("机会 \(max(0, 3 - (board?.challenges[model.campusUser] ?? 0)))/3").font(.caption)
                    }
                    Text("20 分起占 · 首次空地免费 · 保护 2 小时").font(.caption2).foregroundStyle(mint)
                }
            }.padding(18)
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(height: selected == nil ? 184 : 240)
        .background(Color(red: 0.11, green: 0.14, blue: 0.14), in: UnevenRoundedRectangle(topLeadingRadius: 26, topTrailingRadius: 26))
    }

    private func selectionCard(_ id: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                if let plot = chosenPlot {
                    PetView(xp: 0, companion: CompanionKind(rawValue: plot.companion) ?? .legacy)
                        .frame(width: 64, height: 64).clipped()
                } else {
                    Image(systemName: "flag.checkered").font(.title).foregroundStyle(mint).frame(width: 48)
                }
                VStack(alignment: .leading, spacing: 5) {
                    Text(Self.title(id)).font(.title3.bold())
                    Text(chosenPlot.map { "\($0.name) · 守护值 \($0.score)" } ?? "无人驻守 · 20 分即可占领")
                        .font(.caption).foregroundStyle(.white.opacity(0.65))
                }
                Spacer()
                Button { selected = nil } label: { Image(systemName: "xmark").frame(width: 36, height: 36) }
                    .accessibilityLabel("收起地块详情")
            }
            if let plot = chosenPlot, plot.protectedUntil > now {
                Label("保护至 \(plot.protectedUntil.formatted(date: .omitted, time: .shortened))", systemImage: "shield.fill")
                    .font(.caption).foregroundStyle(mint)
            } else {
                Text(chosenPlot == nil ? "占领后精灵将为你守护这块地" : "挑战需高出 10 分 · 今日剩余 \(max(0, 3 - (board?.challenges[model.campusUser] ?? 0))) 次")
                    .font(.caption).foregroundStyle(.white.opacity(0.65))
            }
            HStack {
                action(protected ? "领地保护中" : chosenPlot?.owner == model.campusUser ? "更新守护值" : chosenPlot == nil ? "占领这里" : "挑战这块地", icon: protected ? "lock.fill" : "flag.fill") { confirming = true }
                    .disabled(model.demo || model.campusBusy || protected || !CampusBoard.open(now))
                Button { sharingCard = true } label: {
                    Image(systemName: "square.and.arrow.up").frame(width: 48, height: 48)
                }.background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
                    .accessibilityLabel("分享我的今日纪念卡")
            }
        }
    }
    private func legend(_ title: String, tint: Color) -> some View {
        HStack(spacing: 5) { Circle().fill(tint).frame(width: 6, height: 6); Text(title).font(.caption2) }
    }
    private func action(_ title: String, icon: String, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            Label(title, systemImage: icon).font(.subheadline.bold()).frame(maxWidth: .infinity).frame(minHeight: 48)
        }.buttonStyle(CampusActionStyle(tint: mint))
    }
    private var guide: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("校园主题示意图，不读取定位；地块不对应真实校园边界。")
                        .font(.subheadline).foregroundStyle(.secondary)
                GroupBox("守护约定") {
                    Text("20 分即可占空地，每人同时拥有一块地。首次占领保护 2 小时，换地不刷新保护。挑战需比对方最近同步的分数高至少 10 分，每天最多 3 次挑战或换地，失败也计次数；首次占空地免费。保护期内不可挑战。分数最高 110，同分原主人守住。丢地不扣经验；地图和挑战次数次日重置。")
                        .font(.caption).frame(maxWidth: .infinity, alignment: .leading)
                }
                let explored = Set((model.state.campusVisits ?? []).compactMap { $0.split(separator: "|").last.map(String.init) }).count
                GroupBox("我的校园足迹") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(explored >= 20 ? "校园漫游家" : explored >= 10 ? "校园探路者" : "校园初访者").font(.headline)
                        Text("已探索 \(explored) / 24 个区域 · 保存在本机")
                        ForEach(Array((model.state.campusVisits ?? []).suffix(7).reversed()), id: \.self) { key in
                            let parts = key.split(separator: "|")
                            if parts.count == 2, let id = Int(parts[1]), (0..<24).contains(id) {
                                Text("\(parts[0]) · \(Self.title(id))").font(.caption)
                            }
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
                if model.state.campusSharing == true {
                    Button("停止新的地图共享") {
                        model.state.campusSharing = false; model.campusBoard = nil; model.save()
                    }
                    Text("停止后不再上传；已共享的领地在当天地图仍可见。")
                        .font(.caption).foregroundStyle(.secondary)
                }

                }.padding()
            }.navigationTitle("守护约定与足迹")
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { showingGuide = false } } }
        }.foregroundStyle(Color.primary)
    }
}

private struct CampusActionStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    let tint: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.foregroundStyle(Color.black.opacity(0.85))
            .background(tint.opacity(enabled ? 1 : 0.35), in: RoundedRectangle(cornerRadius: 16))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}
