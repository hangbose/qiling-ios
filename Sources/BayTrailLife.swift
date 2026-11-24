import SwiftUI

/// Small, viewport-sized details remain visible as the panorama scrolls.
struct BayBreeze: View {
    let district: Int
    @Environment(\.accessibilityReduceMotion) private var reduced
    @Environment(\.scenePhase) private var phase

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 12, paused: reduced || phase != .active)) { clock in
            Canvas { ctx, size in
                let t = reduced ? 4.0 : clock.date.timeIntervalSinceReferenceDate
                let coast = district == 0 || district == 4
                for n in 0..<(coast ? 3 : 5) {
                    let i = Double(n)
                    let cycle = (t / (coast ? 27 : 13) + i * (coast ? 0.038 : 0.23)).truncatingRemainder(dividingBy: 1)
                    let x = cycle * (size.width + 32) - 16
                    let y = size.height * (coast ? 0.32 + i * 0.025 : 0.40 + i * 0.065) + sin(t * 0.7 + i) * 4
                    if coast {
                        var wings = Path()
                        let tip = sin(t * 2.5 + i) * 1.8 - 1
                        wings.move(to: CGPoint(x: x - 5, y: y + tip))
                        wings.addLine(to: CGPoint(x: x, y: y + 1))
                        wings.addLine(to: CGPoint(x: x + 5, y: y + tip))
                        ctx.stroke(wings, with: .color(BayUI.ink.opacity(0.65)), lineWidth: 1.6)
                    } else {
                        ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 5, height: 2.5)),
                                 with: .color((district == 2 ? Color.orange : Color.yellow).opacity(0.8)))
                    }
                }
            }
        }.allowsHitTesting(false).accessibilityHidden(true)
    }
}

struct BayLivingPet: View {
    let kind: String
    let size: CGFloat
    let walking: Bool
    let trick: BayTrick
    let call: Date?
    let summon: () -> Void
    let name: String
    @Environment(\.accessibilityReduceMotion) private var reduced
    @Environment(\.scenePhase) private var phase

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 15, paused: reduced || phase != .active)) { clock in
            let t = reduced ? 0 : clock.date.timeIntervalSinceReferenceDate
            let age = call.map { max(0, clock.date.timeIntervalSince($0)) } ?? 10
            let jump = reduced ? 0 : sin(.pi * min(1, age / 0.64)) * size * 0.23
            ZStack {
                Canvas { ctx, box in
                    let mid = CGPoint(x: box.width / 2, y: box.height / 2)
                    if trick.rawValue >= BayTrick.tracks.rawValue {
                        for i in 0..<3 {
                            let x = mid.x - size * (0.28 + Double(i) * 0.14)
                            let y = mid.y + size * (i % 2 == 0 ? 0.41 : 0.45)
                            ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: size * 0.075, height: size * 0.036)),
                                     with: .color(Color.yellow.opacity(0.9 - Double(i) * 0.18)))
                        }
                    }
                    if trick.rawValue >= BayTrick.fireflies.rawValue {
                        var points: [CGPoint] = []
                        for i in 0..<(trick == .constellation ? 5 : 2) {
                            let a = t * 0.85 + Double(i) * 2.4
                            let p = CGPoint(x: mid.x + cos(a) * size * 0.48,
                                            y: mid.y - size * 0.24 + sin(a) * size * 0.27 - jump)
                            points.append(p)
                            ctx.fill(Path(ellipseIn: CGRect(x: p.x-4, y: p.y-4, width: 8, height: 8)),
                                     with: .color(Color.yellow.opacity(0.28)))
                            ctx.fill(Path(CGRect(x: p.x-1.5, y: p.y-1.5, width: 3, height: 3)), with: .color(.white))
                        }
                        if trick == .constellation && call != nil {
                            var line = Path()
                            line.addLines(points)
                            ctx.stroke(line, with: .color(Color.yellow.opacity(0.85)), lineWidth: 1.3)
                        }
                    }
                }
                BaySprite(kind: kind, walking: walking && !reduced, grown: trick == .constellation)
                    .frame(width: size, height: size)
                    .scaleEffect(x: 1, y: walking || reduced ? 1 : 1 + sin(t * 2) * 0.024, anchor: .bottom)
                    .offset(y: -jump)
            }
        }.frame(width: size * 1.65, height: size * 2)
        .overlay {
            Text(call == nil ? "唤一声" : trick.title)
                .font(.caption.weight(.semibold)).fixedSize()
                .foregroundStyle(BayUI.ink).padding(.horizontal, 6).padding(.vertical, 2)
                .background(BayUI.cream, in: Capsule())
                .offset(y: -size * 0.86)
                .allowsHitTesting(false).accessibilityHidden(true)
        }
        .overlay {
            Button(action: summon) { Color.clear.frame(width: max(48, size), height: max(48, size * 2)).contentShape(Rectangle()) }
                .buttonStyle(.plain).accessibilityLabel("呼唤" + name + "，" + trick.title)
        }
        .accessibilityElement(children: .contain)
    }
}
