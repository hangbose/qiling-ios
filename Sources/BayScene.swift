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
    private let walkerX = [0.11, 0.25, 0.51, 0.86]
    private let walkerY = [0.745, 0.738, 0.727, 0.624]
    private let lamps = [CGPoint(x: 0.203, y: 0.606), CGPoint(x: 0.478, y: 0.607), CGPoint(x: 0.731, y: 0.594)]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                Image("BayJourney").resizable().interpolation(.none)
                ForEach(lamps.indices, id: \.self) { i in
                    let lit = i < stop
                    Ellipse()
                        .fill(lit ? Color.yellow.opacity(0.72) : Color(red: 0.24, green: 0.30, blue: 0.33))
                        .frame(width: w * 0.015, height: h * 0.019)
                        .shadow(color: lit ? .yellow : .clear, radius: 6)
                        .position(x: w * lamps[i].x, y: h * lamps[i].y)
                }
                if let together {
                    BaySprite(kind: together, walking: false).frame(width: w * 0.10, height: w * 0.10)
                        .position(x: w * (walkerX[stop] - 0.085), y: h * (walkerY[stop] + 0.018))
                }
                BaySprite(kind: kind, walking: walking).frame(width: w * 0.115, height: w * 0.115)
                    .position(x: w * walkerX[stop], y: h * walkerY[stop])
            }
        }.aspectRatio(4.0 / 3.0, contentMode: .fit)
          .accessibilityLabel("深圳湾海堤，已点亮 \(stop) 盏路灯")
    }
}

/// A tiny travel sprite with the companion's ears, tuft and a coral kerchief.
struct BaySprite: View {
    let kind: String
    let walking: Bool
    private let pixels = [
        "       d       d    ", "      ded     ded   ", "      defdddddffd   ",
        "      dfffffffffd   ", "  dd  dffffeffefd   ", " dffd dffffdeffdd   ",
        " dffddddffcccfccd   ", " ddffffdffcccdccd   ", "  dfffffrrrccccd    ",
        "   dffefffrrrrd     ", "    dffeffffrcd     ", "    dffeccffccd     ",
        "     ddccddccd      ", "     dccd dccd      ", "     ddd   ddd      "
    ]
    var body: some View {
        TimelineView(.animation(minimumInterval: 0.16, paused: !walking)) { timeline in
            Canvas { ctx, size in
                let unit = floor(size.width * 3 / 20) / 3
                let pulse = walking && Int(timeline.date.timeIntervalSinceReferenceDate * 5) % 2 == 0
                let fur = kind == "yaya" ? Color(red: 0.64, green: 0.80, blue: 0.49) :
                    kind == "xiaoying" ? Color(red: 0.54, green: 0.58, blue: 0.85) : Color(red: 0.65, green: 0.79, blue: 0.89)
                let inks: [Character: Color] = ["d": BayInk.text, "f": fur, "c": .init(white: 0.98),
                    "e": .init(red: 0.98, green: 0.84, blue: 0.69), "r": .init(red: 0.87, green: 0.33, blue: 0.21)]
                ctx.fill(Path(ellipseIn: CGRect(x: 3*unit, y: 15*unit, width: 13*unit, height: 2*unit)), with: .color(.black.opacity(0.20)))
                for (y,row) in pixels.enumerated() {
                    for (x,char) in row.enumerated() {
                        guard let ink = inks[char] else { continue }
                        let shift = pulse && y > 11 ? (x < 9 ? -1 : 1) : 0
                        ctx.fill(Path(CGRect(x: CGFloat(x + shift)*unit, y: CGFloat(y + (pulse ? 1 : 2))*unit, width: unit, height: unit)), with: .color(ink))
                    }
                }
            }
        }.accessibilityHidden(true)
    }
}
