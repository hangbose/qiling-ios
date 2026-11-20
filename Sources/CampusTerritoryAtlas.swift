import SwiftUI

/// An illustrated campus, not georeferenced boundaries. IDs match the existing daily board.
struct CampusTerritoryAtlas: View {
    let plots: [CampusPlot]
    let user: String
    @Binding var selected: Int?
    var zoom: CGFloat
    private let mint = Color(red: 0.65, green: 0.96, blue: 0.72)

    static func tint(_ plot: CampusPlot?, user: String) -> Color {
        guard let plot else { return Color(red: 0.26, green: 0.34, blue: 0.33) }
        if plot.owner == user { return Color(red: 0.65, green: 0.96, blue: 0.72) }
        let colors: [Color] = [.orange, .cyan, .pink, .purple]
        return colors[plot.owner.utf8.reduce(0) { ($0 + Int($1)) % colors.count }]
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(red: 0.09, green: 0.14, blue: 0.14)
                Canvas { context, size in
                    // Quiet street texture, with a broad campus promenade through the blocks.
                    for index in 0..<18 {
                        var path = Path()
                        let y = CGFloat(index) * size.height / 14
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: size.width, y: y - 65))
                        context.stroke(path, with: .color(.white.opacity(0.035)), lineWidth: 1)
                    }
                    var road = Path()
                    road.move(to: CGPoint(x: size.width * 0.46, y: 0))
                    road.addCurve(to: CGPoint(x: size.width * 0.54, y: size.height),
                                  control1: CGPoint(x: size.width * 0.64, y: size.height * 0.4),
                                  control2: CGPoint(x: size.width * 0.32, y: size.height * 0.6))
                    context.stroke(road, with: .color(.white.opacity(0.10)), lineWidth: 14)
                    context.stroke(road, with: .color(.white.opacity(0.15)), style: StrokeStyle(lineWidth: 1, dash: [3, 5]))
                }
                ForEach(0..<24, id: \.self) { id in
                    let row = id / 4
                    let column = id % 4
                    let plot = plots.first { $0.id == id }
                    let tint = Self.tint(plot, user: user)
                    let width = geo.size.width * 0.205
                    let height = geo.size.height * 0.126
                    Button { withAnimation(.easeInOut(duration: 0.2)) { selected = id } } label: {
                        ZStack {
                            CampusParcel(variant: id % 3)
                                .fill(tint.opacity(plot == nil ? 0.60 : 0.30))
                            CampusParcel(variant: id % 3)
                                .stroke(selected == id ? Color.white : tint.opacity(plot == nil ? 0.65 : 1),
                                        lineWidth: selected == id ? 3 : (plot == nil ? 1 : 2))
                            VStack(spacing: 3) {
                                if let plot {
                                    Image(systemName: plot.owner == user ? "flag.fill" : "pawprint.fill")
                                        .font(.system(size: 16, weight: .bold))
                                    Text(plot.name).font(.system(size: 10, weight: .semibold)).lineLimit(1)
                                    Text("\(plot.score)").font(.system(size: 11, weight: .bold, design: .rounded))
                                } else {
                                    Text(String(format: "%02d", id + 1))
                                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                                }
                            }.foregroundStyle(plot == nil ? Color.white.opacity(0.45) : tint)
                                .padding(8)
                        }.frame(width: width, height: height)
                            .contentShape(CampusParcel(variant: id % 3))
                    }.buttonStyle(.plain)
                        .position(x: geo.size.width * (0.15 + CGFloat(column) * 0.232 + (row % 2 == 0 ? -0.015 : 0.015)),
                                  y: geo.size.height * (0.14 + CGFloat(row) * 0.143))
                        .accessibilityLabel("\(CampusMapView.title(id))，\(plot?.name ?? "空地")，\(plot?.score ?? 0)分")
                        .accessibilityAddTraits(selected == id ? .isSelected : [])
                }
                VStack {
                    HStack {
                        Text("N ↑").font(.caption.monospaced().bold())
                        Spacer()
                        Text("YUEHAI / 24 ZONES").font(.system(size: 9, weight: .medium, design: .monospaced))
                    }
                    Spacer()
                    Text("深大 · 校园主题示意图 · 非实景地图")
                        .font(.system(size: 10)).tracking(1)
                }.foregroundStyle(.white.opacity(0.45)).padding(18).allowsHitTesting(false)
            }.scaleEffect(zoom)
        }.clipped()
    }
}

private struct CampusParcel: Shape {
    var variant: Int
    func path(in rect: CGRect) -> Path {
        let inset: CGFloat = variant == 0 ? 0.10 : 0.04
        let points: [CGPoint] = [
            CGPoint(x: inset, y: 0.04), CGPoint(x: 0.86, y: 0),
            CGPoint(x: 1, y: 0.20), CGPoint(x: 0.94, y: 0.90),
            CGPoint(x: 0.18, y: 1), CGPoint(x: 0, y: 0.76)
        ]
        var path = Path()
        path.addLines(points.map { CGPoint(x: rect.minX + $0.x * rect.width, y: rect.minY + $0.y * rect.height) })
        path.closeSubpath()
        return path
    }
}
