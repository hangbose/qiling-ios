import Foundation

/// Habits and existing companion XP are two ways to learn the same trail tricks.
/// Only the owner's progress counts, even on a relay route.
enum BayTrick: Int, CaseIterable {
    case hop, tracks, fireflies, constellation

    var days: Int { [0, 1, 3, 5][rawValue] }
    var xp: Int { [0, 50, 300, 1000][rawValue] }
    var title: String { ["轻轻一跃", "发光脚印", "引来流萤", "点出星座"][rawValue] }
    var next: Self? { Self(rawValue: rawValue + 1) }
    static func learned(days: Int, xp: Int) -> Self {
        allCases.last { days >= $0.days || xp >= $0.xp } ?? .hop
    }
}

struct BayDistrict: Identifiable {
    let id: String
    let title: String
    let art: String
    let stops: [String]
    let notes: [String]
    let length: Int

    static let all = [
        BayDistrict(id: "bay", title: "深圳湾", art: "BayJourney", stops: ["海边长椅","海湾转角","观景平台"],
                    notes: ["风从红树林吹过来。","两盏路灯之间，潮水慢慢涨了。","海平线被晚霞染成了金色。"], length: 12),
        BayDistrict(id: "park", title: "人才公园", art: "BayPark", stops: ["星光桥","湖畔草坡","春笋倒影"],
                    notes: ["桥下的湖面碎成一片星光。","草叶上还有露水。","春笋的倒影一直延伸到岸边。"], length: 15),
        BayDistrict(id: "loft", title: "华侨城创意园", art: "BayLoft", stops: ["红砖巷","榕树庭院","街角咖啡"],
                    notes: ["老厂房的砖墙被太阳晒暖了。","停一停，听榕树里的鸟叫。","窗台旁飘来烘豆子的香气。"], length: 15),
        BayDistrict(id: "ridge", title: "莲花山", art: "BayRidge", stops: ["风筝草坪","山脊小径","山顶看台"],
                    notes: ["有只风筝偷偷跃过了树梢。","绿荫深处露出一角天际线。","从山顶看，整座城都亮了。"], length: 18),
        BayDistrict(id: "shore", title: "大梅沙", art: "BayShore", stops: ["听潮栈道","拾贝浅滩","海边灯火"],
                    notes: ["浪花正拍打木栈道下的石头。","沙滩上躺着一枚螺旋贝壳。","海边的灯亮起来了，这一圈到家了。"], length: 18)
    ]
    static let lapLength = all.reduce(0) { $0 + $1.length }
}

// At the final stamp we stay at the lookout. The following stamp starts the next circuit.
struct BayTrail {
    let total: Int
    // Translate only the already-earned part of a short route. New stamps advance one step each.
    init(_ stamps: Int, legacyCount: Int = 0) {
        let earned = max(0, stamps)
        let legacy = min(earned, max(0, legacyCount))
        let oldLengths = [3, 6, 6, 6, 6]
        let oldLap = oldLengths.reduce(0, +)
        var position = legacy / oldLap * BayDistrict.lapLength
        var remainder = legacy % oldLap
        for (old, area) in zip(oldLengths, BayDistrict.all) {
            let segment = min(old, remainder)
            position += (segment * area.length + old - 1) / old
            remainder -= segment
        }
        total = position + earned - legacy
    }
    var lap: Int { max(0, total - 1) / BayDistrict.lapLength + 1 }
    var local: Int { total == 0 ? 0 : (total - 1) % BayDistrict.lapLength + 1 }
    func ticks(in index: Int) -> Int {
        let start = BayDistrict.all.prefix(index).reduce(0) { $0 + $1.length }
        return min(BayDistrict.all[index].length, max(0, local - start))
    }
    var district: Int { BayDistrict.all.indices.last(where: { ticks(in: $0) > 0 }) ?? 0 }
    func canVisit(_ i: Int) -> Bool { BayDistrict.all.indices.contains(i) && (lap > 1 || i <= district) }
    func visitTicks(_ i: Int) -> Int { lap > 1 && i > district ? BayDistrict.all[i].length : ticks(in: i) }
}

struct BayPlacement: Codable, Equatable {
    let district: Int
    let x: Double
    let y: Double

    static func onPath(_ index: Int, x input: Double) -> Self {
        let x = min(0.94, max(0.06, input))
        let y = index == 0 ? 0.756 - max(0, x - 0.36) * 0.20 : BayDistrict.pathY(index, at: x)
        return Self(district: index, x: x, y: y)
    }
}

extension BayDistrict {
    static func pathY(_ district: Int, at x: Double) -> Double {
        // Depth of the hand-painted promenade at the left and right edge.
        switch district {
        case 1: return 0.80 - 0.012*x
        case 2: return 0.79 - 0.035*x
        case 3: return 0.76 + 0.016*x
        case 4: return 0.77 - 0.022*x
        default: return 0.756 - max(0,x - 0.36)*0.20
        }
    }
}

extension BayJournal {
    func position(of item: BaySouvenir) -> BayPlacement {
        placements?[item.id] ?? BayPlacement(district: 0, x: item.x, y: item.y)
    }

    mutating func place(_ item: BaySouvenir, in index: Int, at x: Double, progress: BayTrail) {
        guard owns(item), x.isFinite, progress.canVisit(index) else { return }
        var values = placements ?? [:]
        values[item.id] = .onPath(index, x: x)
        placements = values
    }
}
