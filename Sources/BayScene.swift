import SwiftUI

enum BayInk {
    static let paper = Color(red: 0.98, green: 0.96, blue: 0.90)
    static let text = Color(red: 0.09, green: 0.21, blue: 0.23)
    static let sea = Color(red: 0.15, green: 0.38, blue: 0.40)
    static let coral = Color(red: 0.68, green: 0.26, blue: 0.16)
}

/// Positions are in the original 1448×1086 plate so the lights and sprite stay on the path.
struct BayScene: View {
    let stop: Int
    let kind: String
    var together: String?
    var walking = false
    var follows = false
    var souvenirs: [BaySouvenir] = []
    var district = 0
    var fraction: Double?
    var placements: [String: BayPlacement] = [:]
    var keepsakes = BayKeepsakes()
    var grown = false
    var buddyGrown = false
    var focusX: Double?
    var onPan: ((Double) -> Void)?
    var trick: BayTrick = .hop
    var call: Date?
    var onCall: (() -> Void)?
    var petName = ""
    @State private var dragOrigin: Double?
    @Environment(\.accessibilityReduceMotion) private var reduced
    private let walkerX = [0.11, 0.25, 0.51, 0.86]
    private let walkerY = [0.745, 0.738, 0.727, 0.624]
    private var lamps: [CGPoint] {
        if district == 0 { return [CGPoint(x: 0.203, y: 0.606), CGPoint(x: 0.478, y: 0.607), CGPoint(x: 0.731, y: 0.594)] }
        return [0.27, 0.52, 0.82].map { x in CGPoint(x: x, y: BayDistrict.pathY(district, at: x) - 0.06) }
    }

    private var litCount: Int {
        guard walking else { return stop }
        return max(0, Int((fraction ?? Double(stop)) - 3.0 / Double(BayDistrict.all[district].length)))
    }
    private var track: CGPoint {
        let tick = min(3, max(0, fraction ?? Double(stop))), i = min(2, Int(tick))
        let x = walkerX[i] + (walkerX[i+1] - walkerX[i]) * (tick - Double(i))
        let y = district == 0 ? walkerY[i] + (walkerY[i+1] - walkerY[i]) * (tick - Double(i)) : BayDistrict.pathY(district, at: x) - 0.045
        return CGPoint(x: x, y: y)
    }

    var body: some View {
        if follows {
            promenade
        } else {
            landscape.aspectRatio(4.0 / 3.0, contentMode: .fit)
        }
    }

    private var promenade: some View {
        let ticks = (fraction ?? Double(stop)) * Double(BayDistrict.all[district].length) / 3
        return GeometryReader { geo in
            let layout = BayPromenadeLayout(district: district, viewport: geo.size, ticks: ticks, focus: focusX)
            ZStack {
                BayPromenade(scene: self, travellers: false, ticks: ticks)
                    .id(district).transition(reduced ? .identity : .opacity)
                if onCall != nil { BayBreeze(district: district) }
                BayPromenade(scene: self, travellers: true, ticks: ticks)
                    .id(district).transition(.identity).zIndex(1)
            }.contentShape(Rectangle())
                .simultaneousGesture(DragGesture(minimumDistance: 10)
                            .onChanged { drag in
                                guard let onPan, abs(drag.translation.width) > abs(drag.translation.height) else { return }
                                if dragOrigin == nil { dragOrigin = layout.cameraLeft }
                                let start = dragOrigin ?? layout.cameraLeft
                                let left = min(max(0, start - drag.translation.width), max(0, layout.width - geo.size.width))
                                onPan((left + geo.size.width * 0.40) / max(1, layout.width))
                            }.onEnded { _ in dragOrigin = nil })
        }.clipped()
    }

    private var landscape: some View {
        GeometryReader { geo in
            let frame = geo.size
            let w = frame.width
            let h = w * 0.75
            ZStack {
                Image(BayDistrict.all[district].art).resizable().interpolation(.none)
                BayLamplight(lamps: lamps, progress: fraction ?? Double(stop))
                    .animation(reduced ? nil : .easeOut(duration: 0.95), value: fraction)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                ForEach(lamps.indices, id: \.self) { i in
                    let lit = i < litCount
                    ZStack {
                        if lit {
                            Circle().fill(RadialGradient(colors: [.yellow.opacity(0.58), .orange.opacity(0.14), .clear], center: .center, startRadius: 0, endRadius: w * 0.031))
                        }
                        if district != 0 {
                            Rectangle().fill(BayUI.navy).frame(width: w*0.005, height: h*0.043).offset(y: h*0.021)
                        }
                        Ellipse().fill(lit ? Color(red: 1, green: 0.90, blue: 0.58) : Color(red: 0.30, green: 0.32, blue: 0.37))
                            .frame(width: w * 0.015, height: h * 0.019)
                    }.frame(width: w * 0.066, height: w * 0.066)
                        .position(x: w * lamps[i].x, y: h * lamps[i].y)
                }
                ForEach(souvenirs) { item in
                    let size = w * item.size
                    let location = placements[item.id] ?? BayPlacement(district: 0, x: item.x, y: item.y)
                    if location.district == district {
                    Image(item.asset).resizable().interpolation(.none)
                        .frame(width: size, height: size)
                        .position(x: w * location.x, y: h * location.y - size / 2)
                    }
                }
                if district == 0 && keepsakes.hasShell {
                    ForEach(BayOuting.allCases) { route in
                        if let tile = keepsakes.benchTile(route) {
                            let size = w * 0.105
                            BayFindSprite(column: tile.column, row: tile.row).frame(width: size, height: size)
                                .position(x: w * route.benchX, y: h * 0.76 - size / 2)
                        }
                    }
                }
            }.frame(width: w, height: h)
                .frame(width: frame.width, height: frame.height, alignment: .topLeading)
            if let together {
                BaySprite(kind: together, walking: walking && !reduced, grown: buddyGrown, phaseOffset: 0.19)
                    .frame(width: w * 0.092, height: w * 0.092)
                    .position(x: w * (track.x - 0.073), y: h * (track.y + 0.018))
                    .zIndex(1)
            }
            BaySprite(kind: kind, walking: walking && !reduced, grown: grown)
                .frame(width: w * 0.108, height: w * 0.108)
                .position(x: w * track.x, y: h * track.y)
                .zIndex(1)
        }
            .clipped().accessibilityLabel("\(BayDistrict.all[district].title)，已点亮 \(litCount) 盏路灯")
    }
}

/// The light pools live on the map so the illuminated stretch stays put as the camera pans.
private struct BayLamplight: View {
    let lamps: [CGPoint]
    let progress: Double

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                LinearGradient(stops: [
                    .init(color: Color(red: 0.10, green: 0.14, blue: 0.29).opacity(0.70), location: 0),
                    .init(color: Color(red: 0.06, green: 0.14, blue: 0.25).opacity(0.68), location: 0.55),
                    .init(color: Color(red: 0.05, green: 0.10, blue: 0.20).opacity(0.76), location: 1)
                ], startPoint: .top, endPoint: .bottom)
                .mask {
                    ZStack {
                        Color.white
                        ForEach(lamps.indices, id: \.self) { i in
                            EllipticalGradient(stops: [
                                .init(color: .black, location: 0),
                                .init(color: .black.opacity(0.93), location: 0.43),
                                .init(color: .clear, location: 1)
                            ], center: .center, startRadiusFraction: 0, endRadiusFraction: 0.5)
                            .frame(width: w * 0.60, height: h * 0.80)
                            .opacity(min(1, max(0, progress - Double(i))))
                            .position(x: w * lamps[i].x, y: h * (lamps[i].y + 0.055))
                            .blendMode(.destinationOut)
                        }
                    }.compositingGroup()
                }
                .opacity(progress >= Double(lamps.count) ? 0 : 1)

                ForEach(lamps.indices, id: \.self) { i in
                    EllipticalGradient(colors: [
                        Color(red: 1, green: 0.77, blue: 0.40).opacity(0.20), .clear
                    ], center: .center, startRadiusFraction: 0, endRadiusFraction: 0.5)
                    .frame(width: w * 0.30, height: h * 0.30)
                    .opacity(min(1, max(0, progress - Double(i))))
                    .position(x: w * lamps[i].x, y: h * (lamps[i].y + 0.055))
                }
            }
        }
    }
}

struct BaySprite: View {
    let kind: String
    let walking: Bool
    var grown = false
    var phaseOffset = 0.0
    private var art: String {
        let species = kind == "yaya" ? "Bun" : kind == "xiaoying" ? "Cat" : "Fox"
        return "Trail" + species + (grown ? "1" : "0")
    }
    private var sprite: some View {
        Image(art).resizable().interpolation(.none).scaledToFit().accessibilityHidden(true)
    }
    var body: some View {
        if walking {
            TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { time in
                let cycle = kind == "yaya" ? 0.84 : kind == "xiaoying" ? 0.70 : 0.62
                let phase = (time.date.timeIntervalSinceReferenceDate + phaseOffset).truncatingRemainder(dividingBy: cycle) / cycle
                let frame = min(3, Int(phase * 4))
                GeometryReader { geo in
                    let side = min(geo.size.width, geo.size.height)
                    Image(art + "Walk").resizable().interpolation(.none)
                        .frame(width: side * 4, height: side)
                        .offset(x: -CGFloat(frame) * side)
                        .frame(width: side, height: side, alignment: .leading)
                        .clipped()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }.accessibilityHidden(true)
        } else {
            sprite
        }
    }
}
