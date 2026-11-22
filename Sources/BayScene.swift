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
    @Environment(\.accessibilityReduceMotion) private var reduced
    private let walkerX = [0.11, 0.25, 0.51, 0.86]
    private let walkerY = [0.745, 0.738, 0.727, 0.624]
    private let lamps = [CGPoint(x: 0.203, y: 0.606), CGPoint(x: 0.478, y: 0.607), CGPoint(x: 0.731, y: 0.594)]

    var body: some View {
        GeometryReader { geo in
            let frame = geo.size
            let w = follows ? max(frame.width * 1.78, frame.height * 4 / 3) : frame.width
            let h = w * 0.75
            let cameraX = min(max(0, walkerX[stop] * w - frame.width * 0.49), max(0, w - frame.width))
            let cameraY = min(max(0, walkerY[stop] * h - frame.height * 0.76), max(0, h - frame.height))
            ZStack {
                Image("BayJourney").resizable().interpolation(.none)
                if follows {
                    BayWeather(quiet: reduced)
                    Color(red: 0.28, green: 0.30, blue: 0.58).opacity([0.14, 0.08, 0.04, 0][stop])
                        .allowsHitTesting(false)
                }
                ForEach(lamps.indices, id: \.self) { i in
                    let lit = i < (walking ? max(0, stop-1) : stop)
                    ZStack {
                        if lit {
                            Circle().fill(RadialGradient(colors: [.yellow.opacity(0.58), .orange.opacity(0.14), .clear], center: .center, startRadius: 0, endRadius: w * 0.031))
                        }
                        Ellipse().fill(lit ? Color(red: 1, green: 0.90, blue: 0.58) : Color(red: 0.30, green: 0.32, blue: 0.37))
                            .frame(width: w * 0.015, height: h * 0.019)
                    }.frame(width: w * 0.066, height: w * 0.066)
                        .position(x: w * lamps[i].x, y: h * lamps[i].y)
                }
                if let together {
                    BaySprite(kind: together, walking: false).frame(width: w * 0.075, height: w * 0.075)
                        .position(x: w * (walkerX[stop] - 0.073), y: h * (walkerY[stop] + 0.018))
                }
                BaySprite(kind: kind, walking: walking && !reduced).frame(width: w * 0.09, height: w * 0.09)
                    .position(x: w * walkerX[stop], y: h * walkerY[stop])
            }.frame(width: w, height: h).offset(x: -cameraX, y: -cameraY)
        }.aspectRatio(follows ? 0.98 : 4.0 / 3.0, contentMode: .fit)
            .clipped().accessibilityLabel("深圳湾海堤，已点亮 \(stop) 盏路灯")
    }
}

private struct BayWeather: View {
    let quiet: Bool
    var body: some View {
        TimelineView(.animation(minimumInterval: 0.16, paused: quiet)) { time in
            Canvas { ctx, size in
                let t = quiet ? 0 : time.date.timeIntervalSinceReferenceDate
                let w = size.width, h = size.height
                for i in 0..<13 {
                    let phase = (sin(t * 0.8 + Double(i) * 1.8) + 1) / 2
                    let x = (0.09 + CGFloat(i * 29 % 83) / 100) * w
                    let y = (0.48 + CGFloat(i * 7 % 10) / 100) * h
                    ctx.fill(Path(CGRect(x: x, y: y, width: 2 + 5 * phase, height: 1.3)), with: .color(.white.opacity(phase * 0.80)))
                }
                for i in 0..<3 {
                    let x = (0.25 + (t.truncatingRemainder(dividingBy: 42) / 42) * 0.43 + Double(i) * 0.025) * w
                    let y = (0.26 + sin(t / 4 + Double(i)) * 0.012 + Double(i % 2) * 0.016) * h
                    let wing = sin(t * 1.8 + Double(i)) > 0 ? -2.0 : 0.0
                    var bird = Path(); bird.move(to: CGPoint(x: x - 4, y: y + wing))
                    bird.addLine(to: CGPoint(x: x, y: y + 1)); bird.addLine(to: CGPoint(x: x + 4, y: y + wing))
                    ctx.stroke(bird, with: .color(BayUI.ink.opacity(0.65)), lineWidth: 1.5)
                }
            }
        }.accessibilityHidden(true).allowsHitTesting(false)
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
        if walking {
            TimelineView(.animation(minimumInterval: 0.16)) { timeline in
                sprite(pulse: Int(timeline.date.timeIntervalSinceReferenceDate * 5) % 2 == 0)
            }
        } else {
            sprite(pulse: false)
        }
    }
    private func sprite(pulse: Bool) -> some View {
            Canvas { ctx, size in
                let unit = floor(size.width * 3 / 20) / 3
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
            }.accessibilityHidden(true)
    }
}
