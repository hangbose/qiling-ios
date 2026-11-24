import Foundation

enum BayOuting: String, Codable, CaseIterable, Identifiable {
    case tide, light, post
    var id: Self { self }
    var title: String {
        switch self { case .tide: return "退潮的小径"; case .light: return "堤边灯铺"; case .post: return "老邮局" }
    }
    var row: Int { Self.allCases.firstIndex(of: self)! }
    var benchX: CGFloat {
        switch self { case .tide: return 0.21; case .light: return 0.065; case .post: return 0.71 }
    }
    var finds: [String] {
        switch self {
        case .tide: return ["一枚蓝贝", "两片海玻璃", "珊瑚色坠子"]
        case .light: return ["琥珀灯罩", "黄铜提梁", "星纹灯帽"]
        case .post: return ["旧木信箱", "海鸥邮戳", "红色信号旗"]
        }
    }
    var notes: [String] {
        switch self {
        case .tide: return ["蓝贝碰上白贝，听见第一声海风。", "海玻璃碰在一起，多了一对清亮的音。", "坠子接住海风，这串风铃终于齐了。"]
        case .light: return ["长椅脚边有了一盏小灯。点一下可以换灯色。", "提梁架起来，晚归的人也看得清小路。", "灯帽把星星留在这段海堤。"]
        case .post: return ["长椅旁有了自己的信箱。可以寄张海湾明信片。", "海鸥邮戳落在了你的明信片上。", "小红旗升起来了，今天也有一封海边来信。"]
        }
    }
}

enum BayGlass: String, Codable {
    case pocket, chime, lamp
}

// Stored in the personal journal. Only a habit on a later local calendar day can bring a find home.
struct BayKeepsakes: Codable {
    struct Errand: Codable {
        let route: BayOuting
        let departure: String
    }
    var hasShell = false
    var levels: [String: Int] = [:]
    var errand: Errand?
    var lastUsedDay: String?
    var seaGlassLamp = false
    var glass: BayGlass?
    var glassPlacedOn: String?

    mutating func pickGlass(hasHabit: Bool) {
        guard hasShell, hasHabit, glass == nil else { return }
        glass = .pocket
    }
    mutating func placeGlass(_ place: BayGlass, on day: String) {
        guard glass == .pocket, place != .pocket else { return }
        glass = place
        glassPlacedOn = day
    }
    func glassHasSettled(on day: String) -> Bool {
        glassPlacedOn.map { day > $0 } ?? false
    }

    func level(_ route: BayOuting) -> Int { min(route.finds.count, max(0, levels[route.rawValue] ?? 0)) }
    var finished: Bool { BayOuting.allCases.allSatisfy { level($0) == $0.finds.count } }
    func isReady(days: [String: String]) -> Bool {
        guard let errand else { return false }
        return days.keys.contains { $0 > errand.departure }
    }
    mutating func send(_ route: BayOuting, on day: String) {
        guard hasShell, errand == nil, level(route) < route.finds.count else { return }
        errand = Errand(route: route, departure: max(day, lastUsedDay ?? day))
    }
    @discardableResult mutating func unpack(days: [String: String]) -> Bool {
        guard let trip = errand, let day = days.keys.filter({ $0 > trip.departure }).min() else { return false }
        let route = trip.route
        guard level(route) < route.finds.count else { return false }
        levels[route.rawValue] = level(route) + 1
        lastUsedDay = day
        errand = nil
        return true
    }
    func sprite(_ route: BayOuting) -> (column: Int, row: Int)? {
        let count = level(route)
        guard count > 0 else { return nil }
        return route == .light && seaGlassLamp ? (count, 3) : (count - 1, route.row)
    }
    var entry: String {
        if !hasShell { return "拾起长椅边的白贝" }
        if glass == .pocket { return "安放海玻璃" }
        if errand != nil { return "看看行囊" }
        return finished ? "回长椅坐坐" : "去长椅寻宝"
    }
    func benchTile(_ route: BayOuting) -> (column: Int, row: Int)? {
        if route == .tide && hasShell && level(.tide) == 0 { return (0, 3) }
        return sprite(route)
    }
    func visitURL(pet: String, grown: Bool) -> URL? {
        guard hasShell else { return nil }
        let traveler = ["legacy","yaya","xiaoying"].contains(pet) ? pet : "legacy"
        var parts = [traveler, grown ? "1" : "0"] + BayOuting.allCases.map { String(level($0)) } + [seaGlassLamp ? "1" : "0"]
        if glass == .chime || glass == .lamp { parts.append(glass == .chime ? "c" : "l") }
        return URL(string: "https://hangbose.github.io/qiling-ios/#bench=" + parts.joined(separator: "."))
    }
}

extension AppModel {
    var keepsakeDay: String { demo ? demoBay.days.keys.max() ?? Growth.dayID(Date()) : Growth.dayID(Date()) }

    func changeKeepsakes(_ action: (inout BayKeepsakes) -> Void) {
        var corner = bay.keepsakes ?? BayKeepsakes()
        action(&corner)
        if demo { demoBay.keepsakes = corner }
        else { state.bay?.keepsakes = corner; save() }
    }
}

