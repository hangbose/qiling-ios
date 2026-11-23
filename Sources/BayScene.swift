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
    @Environment(\.accessibilityReduceMotion) private var reduced
    private let walkerX = [0.11, 0.25, 0.51, 0.86]
    private let walkerY = [0.745, 0.738, 0.727, 0.624]
    private let lamps = [CGPoint(x: 0.203, y: 0.606), CGPoint(x: 0.478, y: 0.607), CGPoint(x: 0.731, y: 0.594)]

    private var litCount: Int { walking ? max(0, stop - 1) : stop }

    var body: some View {
        if follows {
            landscape
        } else {
            landscape.aspectRatio(4.0 / 3.0, contentMode: .fit)
        }
    }

    private var landscape: some View {
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
                }
                BayLamplight(lamps: lamps, litCount: litCount)
                    .animation(reduced ? nil : .easeOut(duration: 0.95), value: litCount)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                ForEach(lamps.indices, id: \.self) { i in
                    let lit = i < litCount
                    ZStack {
                        if lit {
                            Circle().fill(RadialGradient(colors: [.yellow.opacity(0.58), .orange.opacity(0.14), .clear], center: .center, startRadius: 0, endRadius: w * 0.031))
                        }
                        Ellipse().fill(lit ? Color(red: 1, green: 0.90, blue: 0.58) : Color(red: 0.30, green: 0.32, blue: 0.37))
                            .frame(width: w * 0.015, height: h * 0.019)
                    }.frame(width: w * 0.066, height: w * 0.066)
                        .position(x: w * lamps[i].x, y: h * lamps[i].y)
                }
                ForEach(souvenirs) { item in
                    let size = w * item.size
                    Image(item.asset).resizable().interpolation(.none)
                        .frame(width: size, height: size)
                        .position(x: w * item.x, y: h * item.y - size / 2)
                }
                if let together {
                    BaySprite(kind: together, walking: false).frame(width: w * 0.075, height: w * 0.075)
                        .position(x: w * (walkerX[stop] - 0.073), y: h * (walkerY[stop] + 0.018))
                }
                BaySprite(kind: kind, walking: walking && !reduced).frame(width: w * 0.09, height: w * 0.09)
                    .position(x: w * walkerX[stop], y: h * walkerY[stop])
            }.frame(width: w, height: h).offset(x: -cameraX, y: -cameraY)
        }
            .clipped().accessibilityLabel("深圳湾海堤，已点亮 \(litCount) 盏路灯")
    }
}

/// The light pools live on the map so the illuminated stretch stays put as the camera pans.
private struct BayLamplight: View {
    let lamps: [CGPoint]
    let litCount: Int

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
                            .opacity(i < litCount ? 1 : 0)
                            .position(x: w * lamps[i].x, y: h * (lamps[i].y + 0.055))
                            .blendMode(.destinationOut)
                        }
                    }.compositingGroup()
                }
                .opacity(litCount == lamps.count ? 0 : 1)

                ForEach(lamps.indices, id: \.self) { i in
                    EllipticalGradient(colors: [
                        Color(red: 1, green: 0.77, blue: 0.40).opacity(0.20), .clear
                    ], center: .center, startRadiusFraction: 0, endRadiusFraction: 0.5)
                    .frame(width: w * 0.30, height: h * 0.30)
                    .opacity(i < litCount ? 1 : 0)
                    .position(x: w * lamps[i].x, y: h * (lamps[i].y + 0.055))
                }
            }
        }
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
