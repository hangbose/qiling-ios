import SwiftUI

/// Geometry for the live route. Purchases and progress keep their normalized district coordinates.
struct BayPromenadeLayout {
    let district: Int
    let viewport: CGSize
    let ticks: Double
    let focus: Double?

    private var length: Int { BayDistrict.all[district].length }
    static func aspect(_ district: Int) -> Double { district == 0 || district == 3 ? 26 : 13 }
    static func duration(_ district: Int) -> Double { aspect(district) == 26 ? 6.8 : 4.8 }
    static func routeX(_ progress: Double) -> Double { 0.035 + 0.93 * min(1, max(0, progress)) }
    private static let paths: [[Double]] = [
        [0.90, 0.90, 0.89, 0.90, 0.91, 0.90, 0.91, 0.88, 0.90],
        [0.90, 0.90, 0.91, 0.91, 0.91, 0.90, 0.91, 0.90, 0.91],
        [0.90, 0.91, 0.90, 0.90, 0.89, 0.91, 0.90, 0.91, 0.92],
        [0.85, 0.84, 0.84, 0.85, 0.84, 0.84, 0.85, 0.86, 0.84],
        [0.91, 0.91, 0.89, 0.90, 0.91, 0.90, 0.90, 0.92, 0.91]
    ]

    var x: Double { Self.routeX(ticks / Double(length)) }
    var width: CGFloat {
        max(viewport.height * Self.aspect(district), viewport.width * CGFloat(length) * 0.82 / 0.93)
    }
    var height: CGFloat { width / Self.aspect(district) }
    var unit: CGFloat { min(viewport.width, viewport.height * 0.8) }

    func feet(at x: Double) -> CGFloat {
        let path = Self.paths[district]
        let t = min(1, max(0, x)) * Double(path.count - 1)
        let i = min(Int(t), path.count - 2)
        return height * (path[i] + (path[i + 1] - path[i]) * (t - Double(i)))
    }
    var cameraLeft: CGFloat {
        let lead = focus == nil ? 0.20 * sin(.pi * (ticks - floor(ticks))) : 0
        return min(max(0, width - viewport.width), max(0, (focus ?? x) * width - viewport.width * (0.40 + lead)))
    }
    var cameraTop: CGFloat { min(max(0, height - viewport.height), max(0, feet(at: focus ?? x) - viewport.height * 0.79)) }
    func screenPoint(_ x: Double) -> CGPoint {
        CGPoint(x: x * width - cameraLeft, y: feet(at: x) - cameraTop)
    }
}

/// Separate layer identities let the background dissolve while one pair of travellers keeps walking.
struct BayPromenade: View, Animatable {
    let scene: BayScene
    let travellers: Bool
    var ticks: Double
    var animatableData: Double {
        get { ticks }
        set { ticks = newValue }
    }
    @Environment(\.accessibilityReduceMotion) private var reduced

    var body: some View {
        GeometryReader { geo in
            let layout = BayPromenadeLayout(district: scene.district, viewport: geo.size, ticks: ticks, focus: scene.focusX)
            ZStack(alignment: .topLeading) {
                if travellers {
                    if let buddy = scene.together {
                        walker(buddy, grown: scene.buddyGrown, guest: true, layout: layout)
                    }
                    walker(scene.kind, grown: scene.grown, guest: false, layout: layout)
                } else {
                    ForEach(0..<2) { half in
                        Image(BayDistrict.all[scene.district].art + (half == 0 ? "WideWest" : "WideEast"))
                            .resizable().interpolation(.none)
                            .frame(width: layout.width * 0.5 + (half == 0 ? 0.5 : 0), height: layout.height)
                            .offset(x: CGFloat(half) * layout.width * 0.5 - layout.cameraLeft, y: -layout.cameraTop)
                    }
                    lamplight(layout)
                    if scene.district == 0 && scene.keepsakes.hasShell {
                        ForEach(BayOuting.allCases) { route in
                            if let tile = scene.keepsakes.benchTile(route) {
                                let point = layout.screenPoint(0.037 + Double(route.row) * 0.003)
                                let size = layout.unit * 0.12
                                BayFindSprite(column: tile.column, row: tile.row).frame(width: size, height: size)
                                    .position(x: point.x, y: point.y - size / 2)
                            }
                        }
                    }
                    ForEach(scene.souvenirs) { item in
                        let spot = scene.placements[item.id] ?? BayPlacement(district: 0, x: item.x, y: item.y)
                        if spot.district == scene.district {
                            let size = layout.unit * item.size * 2
                            let point = layout.screenPoint(spot.x)
                            Image(item.asset).resizable().interpolation(.none)
                                .frame(width: size, height: size).position(x: point.x, y: point.y - size / 2)
                        }
                    }
                }
            }.frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
              .clipped()
        }
    }

    private func walker(_ kind: String, grown: Bool, guest: Bool, layout: BayPromenadeLayout) -> some View {
        let x = guest ? max(0, layout.x - layout.unit * 0.14 / max(1, layout.width)) : layout.x
        let foot = layout.screenPoint(x)
        let size = layout.unit * (guest ? 0.15 : grown ? 0.21 : 0.17)
        return BaySprite(kind: kind, walking: scene.walking && !reduced, grown: grown, phaseOffset: guest ? 0.19 : 0)
            .frame(width: size, height: size)
            .position(x: foot.x, y: foot.y - size * 0.44 + (guest ? layout.height * 0.009 : 0))
    }

    private func lamplight(_ layout: BayPromenadeLayout) -> some View {
        Canvas { context, size in
            let length = Double(BayDistrict.all[scene.district].length)
            let edge = layout.screenPoint(layout.x).x
            let dusk = Color(red: 0.075, green: 0.10, blue: 0.23)
            if ticks < length {
                let radius = max(1, size.width * 0.55)
                let gradient = Gradient(colors: [dusk.opacity(0.04), dusk.opacity(0.44)])
                context.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(gradient,
                    startPoint: CGPoint(x: edge - radius, y: 0), endPoint: CGPoint(x: edge + radius, y: 0)))
            }
            for n in 1...3 {
                let point = layout.screenPoint(BayPromenadeLayout.routeX(Double(n) / 3))
                guard point.x > -32 && point.x < size.width + 32 else { continue }
                let top = point.y - layout.height * 0.055
                let side = layout.unit * 0.025
                let lit = ticks * 3 >= Double(n) * length
                context.fill(Path(CGRect(x: point.x - 1.5, y: top, width: 3, height: side * 2.8)), with: .color(BayUI.ink))
                if lit {
                    let glow = CGRect(x: point.x - 2 * side, y: top - 2 * side, width: 4 * side, height: 4 * side)
                    context.fill(Path(ellipseIn: glow), with: .radialGradient(Gradient(colors: [.yellow.opacity(0.6), .clear]),
                        center: CGPoint(x: point.x, y: top), startRadius: 0, endRadius: 2 * side))
                }
                context.fill(Path(CGRect(x: point.x - side / 2, y: top - side / 2, width: side, height: side)),
                    with: .color(lit ? Color(red: 1, green: 0.91, blue: 0.65) : BayUI.navy))
            }
        }.allowsHitTesting(false)
    }
}
