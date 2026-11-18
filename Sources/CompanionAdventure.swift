import SwiftUI
import UIKit

enum CompanionKind: String, Codable {
    case legacy, yaya, xiaoying
    var title: String { self == .yaya ? "芽芽" : self == .xiaoying ? "小影" : "星澜" }
    static func phase(_ xp: Int) -> Int { xp >= 1000 ? 3 : xp >= 300 ? 2 : xp >= 50 ? 1 : 0 }
}

enum CompanionArt {
    private static let images: [UIImage] = {
        guard let atlas = UIImage(named: "CompanionGrowth")?.cgImage else { return [] }
        return (0..<8).map { index in
            let rect = CGRect(x: (index % 4) * atlas.width / 4, y: (index / 4) * atlas.height / 2,
                              width: atlas.width / 4, height: atlas.height / 2)
            return atlas.cropping(to: rect).map { UIImage(cgImage: $0) } ?? UIImage()
        }
    }()
    static func image(kind: CompanionKind, xp: Int) -> UIImage {
        let index = (kind == .xiaoying ? 4 : 0) + CompanionKind.phase(xp)
        return images.indices.contains(index) ? images[index] : UIImage()
    }
}

// Uses already-shared weekly summaries; no raw health records or new CloudKit
// schema are needed. A fixed route avoids moving the goal when a friend joins.
struct ExpeditionProgress {
    static let target = 1400
    static let memberCap = 700
    let total: Int
    init(members: [SquadMember]) {
        let unique = Dictionary(members.map { ($0.id, $0.points) }, uniquingKeysWith: max)
        total = unique.values.reduce(0) { $0 + min(Self.memberCap, max(0, $1)) }
    }
    var finished: Bool { total >= Self.target }
    var checkpoint: Int { total >= 1400 ? 3 : total >= 900 ? 2 : total >= 400 ? 1 : 0 }
}

struct ExpeditionView: View {
    @EnvironmentObject private var model: AppModel
    private let stops = ["森林入口", "萤光溪流", "树下营地", "星光花园"]
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("本周远征 · 萤光森林", systemImage: "leaf.fill").font(.headline)
            Text("\(Growth.weekID(Date())) · \(model.demo ? "演示远征" : "全队共同推进")")
                .font(.caption).foregroundStyle(.secondary)
            ProgressView(value: Double(min(model.expedition.total, ExpeditionProgress.target)), total: Double(ExpeditionProgress.target))
            Text("\(model.expedition.total) / \(ExpeditionProgress.target) 探索能量")
            HStack {
                ForEach(0..<4, id: \.self) { index in
                    VStack {
                        Image(systemName: index <= model.expedition.checkpoint ? "checkmark.circle.fill" : "circle")
                        Text(stops[index]).font(.caption2)
                    }.frame(maxWidth: .infinity)
                        .foregroundStyle(index <= model.expedition.checkpoint ? Palette.green : .secondary)
                }
            }
            Text(model.expedition.finished ? "我们一起抵达了星光花园！" : "健康数据同步后，精灵就会自动带来探索能量。")
                .font(.subheadline)
            Text("每人每周最多贡献 700，至少两人一起完成。个人经验不受此上限影响。每周重新出发，缺席不扣分。")
                .font(.caption).foregroundStyle(.secondary)
            Text("完成后，有本周贡献并同步成功的伙伴自动获得一枚远征纪念章。纪念章保存在这台设备上。")
                .font(.caption).foregroundStyle(.secondary)
            if !model.demo, let memories = model.state.expeditionMemories, !memories.isEmpty {
                Divider()
                Label("我的远征纪念章 · \(memories.count)", systemImage: "seal.fill")
                    .foregroundStyle(Palette.green)
                ForEach(Array(memories.suffix(4)), id: \.self) { memory in
                    Text("萤光森林 · \(memory.components(separatedBy: "|").first ?? "")")
                        .font(.caption)
                }
            }
        }.softPanel()
    }
}
