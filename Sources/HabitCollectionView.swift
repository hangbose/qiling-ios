import SwiftUI

struct CampusShareView: View {
    @EnvironmentObject private var model: AppModel
    @State private var image: Image?
    var body: some View {
        VStack(spacing: 20) {
            if let image {
                image.resizable().scaledToFit()
                ShareLink(item: image, preview: SharePreview("我的校园足迹", image: image)) {
                    Label("分享纪念卡", systemImage: "square.and.arrow.up")
                }.buttonStyle(.borderedProminent)
            } else { ProgressView("正在制作纪念卡") }
            Text("只包含精灵名字、领地和贡献，不含健康明细。").font(.caption).foregroundStyle(.secondary)
        }.padding(24)
        .task {
            let plot = model.campusBoard?.plots.first { $0.owner == model.campusUser }
            let card = VStack(spacing: 22) {
                Text("栖灵 · 深大校园足迹").font(.title.bold())
                Text(model.campusBoard?.day ?? CampusBoard.dayID(Date())).foregroundStyle(.secondary)
                PetView(stage: model.stage, xp: model.xp, companion: model.companion).frame(width: 260, height: 260)
                Text(model.state.petName).font(.title2.bold())
                Text(plot.map { "正在守护 · \(CampusMapView.title($0.id))" } ?? "今天也在探索校园")
                Text("今日健康贡献 \(model.campusScore)").font(.headline).foregroundStyle(Palette.green)
                Text("一起坚持，一起长大").foregroundStyle(.secondary)
            }.padding(28).frame(width: 340).background(Palette.background)
            let renderer = ImageRenderer(content: card.environment(\.colorScheme, .light))
            renderer.scale = 3
            if let rendered = renderer.uiImage { image = Image(uiImage: rendered) }
        }
    }
}

struct HabitCollectionView: View {
    @EnvironmentObject private var model: AppModel
    private var items: [(String, String, String, Bool)] {
        let days = model.ledger
        let ball = Set(["羽毛球", "篮球", "足球", "网球", "乒乓球"])
        return [
            ("leaf.fill", "散步的叶子", "有一天步行达到 1000 步", days.contains { ($0.steps ?? 0) >= 1000 }),
            ("basketball.fill", "运动小球", "同步一段至少 5 分钟的球类训练", days.contains { ($0.workouts ?? []).contains { ball.contains($0.kind) && $0.minutes >= 5 } }),
            ("moon.stars.fill", "安睡月亮", "获得一次规律作息奖励", days.contains { $0.regularSleep == true }),
            ("book.closed.fill", "陪读书签", "完成一次专注陪伴", (model.state.habitRewards ?? [:]).keys.contains { $0.hasSuffix("|专注") })
        ]
    }
    var body: some View {
        GroupBox("精灵的小收藏") {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(items, id: \.0) { item in
                    HStack(spacing: 12) {
                        Image(systemName: item.0).font(.title2).frame(width: 34).foregroundStyle(item.3 ? Palette.green : .gray)
                        VStack(alignment: .leading) {
                            Text(item.1 + (item.3 ? " · 已收藏" : " · 待发现")).font(.headline)
                            Text(item.2).font(.caption).foregroundStyle(.secondary)
                        }
                    }.opacity(item.3 ? 1 : 0.6)
                }
                Text("随习惯自动解锁的纪念图标，不增加抢地优势。").font(.caption).foregroundStyle(.secondary)
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
