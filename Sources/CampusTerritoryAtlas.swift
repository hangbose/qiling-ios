import SwiftUI

/// An illustrated campus, not georeferenced boundaries. IDs match the existing daily board.
struct CampusTerritoryAtlas: View {
    let plots: [CampusPlot]
    let user: String
    @Binding var selected: Int?

    static func tint(_ plot: CampusPlot?, user: String) -> Color {
        guard let plot else { return BayUI.rim }
        if plot.owner == user { return BayUI.rust }
        let colors: [Color] = [BayUI.navy, .indigo, .brown, .teal]
        return colors[plot.owner.utf8.reduce(0) { ($0 + Int($1)) % colors.count }]
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                BayUI.paper
                Canvas { context, size in
                    // Quiet street texture, with a broad campus promenade through the blocks.
                    for index in 0..<18 {
                        var path = Path()
                        let y = CGFloat(index) * size.height / 14
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: size.width, y: y - 65))
                        context.stroke(path, with: .color(BayUI.rim.opacity(0.37)), lineWidth: 1)
                    }
                    var road = Path()
                    road.move(to: CGPoint(x: size.width * 0.46, y: 0))
                    road.addCurve(to: CGPoint(x: size.width * 0.54, y: size.height),
                                  control1: CGPoint(x: size.width * 0.64, y: size.height * 0.4),
                                  control2: CGPoint(x: size.width * 0.32, y: size.height * 0.6))
                    context.stroke(road, with: .color(BayUI.rim.opacity(0.7)), lineWidth: 14)
                    context.stroke(road, with: .color(BayUI.navy.opacity(0.6)), style: StrokeStyle(lineWidth: 1, dash: [3, 5]))
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
                                .stroke(selected == id ? BayUI.ink : tint.opacity(plot == nil ? 0.65 : 1),
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
                            }.foregroundStyle(plot == nil ? BayUI.muted : BayUI.ink)
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
                }.foregroundStyle(BayUI.muted).padding(18).allowsHitTesting(false)
            }
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
