import SwiftUI

struct CampusMapView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.scenePhase) private var phase
    @State private var selected: Int?
    @State private var confirming = false
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)
    private let colors: [Color] = [.teal, .orange, .purple, .blue, .pink, .indigo]
    static func title(_ index: Int) -> String {
        ["书香", "运动", "林荫", "湖畔", "生活", "花园"][index / 4] + " \(index % 4 + 1)"
    }
    private func color(_ plot: CampusPlot?) -> Color {
        guard let plot else { return .gray.opacity(0.15) }
        if plot.owner == model.campusUser { return Palette.green }
        let hash = plot.owner.utf8.reduce(0) { ($0 + Int($1)) % colors.count }
        return colors[hash]
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("深大 · 精灵领地").font(.largeTitle.bold())
                Text("校园主题示意图 · 非实景地图，不读取定位")
                    .font(.caption).foregroundStyle(.secondary)
                Text("每日健康贡献 \(model.campusScore) / 110").font(.title3.bold())
                Text("北京时间每日刷新 · 22:00 停止抢夺")
                if model.state.campusSharing != true {
                    Text("参与后公开昵称、精灵种类、贡献分和领地，不公开原始健康记录。当前为邀请测试玩法。")
                    Button("参与校园地图") {
                        model.state.campusSharing = true; model.save()
                        Task { await model.refreshCampus() }
                    }.buttonStyle(.borderedProminent).disabled(model.demo)
                } else {
                    HStack {
                        Button("刷新地图") { Task { await model.sync(); await model.refreshCampus() } }
                        Spacer()
                        if model.campusBusy { ProgressView() }
                        Text("已挑战 \(model.campusBoard?.challenges[model.campusUser] ?? 0)/3")
                    }
                }
                if let error = model.campusError {
                    Text(error).font(.caption).foregroundStyle(.red)
                }
                if let board = model.campusBoard, board.day == CampusBoard.dayID(Date()), model.state.campusSharing == true {
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(0..<24, id: \.self) { id in
                            let plot = board.plots.first { $0.id == id }
                            Button { selected = id } label: {
                                VStack(spacing: 8) {
                                    Image(systemName: plot == nil ? "leaf" : "flag.fill")
                                    Text(Self.title(id)).font(.caption.bold())
                                    Text(plot?.name ?? "空地").font(.caption2).lineLimit(1)
                                    if let plot { Text("\(plot.score) 分").font(.caption2) }
                                }.frame(maxWidth: .infinity, minHeight: 95)
                                    .foregroundStyle(plot == nil ? Color.primary : .white)
                                    .background(color(plot), in: RoundedRectangle(cornerRadius: 16))
                                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(selected == id ? Color.primary : .clear, lineWidth: 3))
                            }.buttonStyle(.plain)
                                .accessibilityLabel("\(Self.title(id))，\(plot?.name ?? "空地")")
                        }
                    }
                    if let selected {
                        let plot = board.plots.first { $0.id == selected }
                        GroupBox(Self.title(selected)) {
                            VStack(alignment: .leading, spacing: 10) {
                                if let plot {
                                    PetView(xp: 0, companion: CompanionKind(rawValue: plot.companion) ?? .legacy).frame(height: 120)
                                    Text("\(plot.name) · 最近同步守护值 \(plot.score)")
                                    if plot.protectedUntil > Date() {
                                        Text("保护至 \(plot.protectedUntil.formatted(date: .omitted, time: .shortened))")
                                    }
                                } else { Text("还没有精灵驻守，来插上你的旗子。") }
                                Button(plot?.owner == model.campusUser ? "更新守护值" : (plot == nil ? "占领这里" : "挑战这块地")) { confirming = true }
                                    .buttonStyle(.borderedProminent)
                                    .disabled(model.campusBusy || !CampusBoard.open(Date()))
                            }.frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    ShareLink(item: "我的精灵今天在栖灵深大校园地图获得了 \(model.campusScore) 点健康贡献，来一起探索吧！") {
                        Label("分享今日足迹", systemImage: "square.and.arrow.up")
                    }
                } else {
                    ContentUnavailableView("等待校园地图", systemImage: "map", description: Text("连接后显示真实领地；不会用示例占领者代替其他用户。"))
                }
                GroupBox("守护约定") {
                    Text("20 分即可占空地，每人同时拥有一块地。首次占领保护 2 小时，换地不刷新保护。挑战需比对方最近同步的分数高至少 10 分，每天最多 3 次，失败也计次数。保护期内不可挑战。分数最高 110，同分原主人守住。丢地不扣经验；地图和挑战次数次日重置。")
                        .font(.caption).frame(maxWidth: .infinity, alignment: .leading)
                }
                Text("累计足迹 \(model.state.campusVisits?.count ?? 0) 次 · 保存在本机")
                if model.state.campusSharing == true {
                    Button("停止新的地图共享") {
                        model.state.campusSharing = false; model.campusBoard = nil; model.save()
                    }
                    Text("停止后不再上传；已共享的领地在当天地图仍可见。")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }.padding()
        }
        .background(Palette.background)
        .task { await model.refreshCampus() }
        .onChange(of: phase) { _, value in if value == .active { Task { await model.refreshCampus() } } }
        .refreshable { await model.sync(); await model.refreshCampus() }
        .confirmationDialog("确认占领或挑战？成功后原有领地会释放；有效挑战会使用一次机会。", isPresented: $confirming, titleVisibility: .visible) {
            Button("确认") { if let selected { Task { await model.refreshCampus(plot: selected) } } }
            Button("取消", role: .cancel) { }
        }
    }
}
