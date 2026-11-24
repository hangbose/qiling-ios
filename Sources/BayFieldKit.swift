import SwiftUI

enum BayUI {
    static let ink = Color(red: 0.16, green: 0.19, blue: 0.26)
    static let navy = Color(red: 0.20, green: 0.27, blue: 0.39)
    static let muted = Color(red: 0.38, green: 0.35, blue: 0.34)
    static let rim = Color(red: 0.75, green: 0.69, blue: 0.60)
    static let paper = Color(red: 0.96, green: 0.93, blue: 0.87)
    static let cream = Color(red: 1, green: 0.98, blue: 0.94)
    static let blush = Color(red: 0.95, green: 0.86, blue: 0.78)
    static let rust = Color(red: 0.59, green: 0.27, blue: 0.18)
    static func heading(_ size: CGFloat) -> Font { .custom("QilingJournal", size: size, relativeTo: .title2) }
}
struct BayCut: Shape {
    func path(in box: CGRect) -> Path {
        let w = box.width, h = box.height, n = min(4, min(w,h)/2)
        var p = Path()
        p.addLines([CGPoint(x:n,y:0),CGPoint(x:w-n,y:0),CGPoint(x:w-n,y:n),CGPoint(x:w,y:n),
            CGPoint(x:w,y:h-n),CGPoint(x:w-n,y:h-n),CGPoint(x:w-n,y:h),CGPoint(x:n,y:h),
            CGPoint(x:n,y:h-n),CGPoint(x:0,y:h-n),CGPoint(x:0,y:n),CGPoint(x:n,y:n)])
        p.closeSubpath()
        return p
    }
}
extension View {
    func fieldPlate(_ fill: Color = BayUI.navy, edge: Color = BayUI.rim) -> some View {
        background(BayCut().fill(fill))
            .overlay(BayCut().stroke(edge, lineWidth: 1))
    }
}
struct BayKey: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    var primary: Bool = false

    init(primary: Bool = false) { self.primary = primary }
    func makeBody(configuration: Configuration) -> some View {
        let fill: Color = !enabled ? BayUI.paper : primary ? BayUI.navy : BayUI.cream
        return configuration.label.font(.subheadline.weight(.semibold)).monospacedDigit()
            .padding(.horizontal, 11).frame(minHeight: 44)
            .foregroundStyle(!enabled ? BayUI.muted : primary ? BayUI.cream : BayUI.ink)
            .background {
                BayCut().fill(fill)
                    .overlay { if configuration.isPressed && enabled { BayCut().fill(BayUI.ink.opacity(0.12)) } }
            }
            .overlay(BayCut().stroke(primary && enabled ? BayUI.ink : BayUI.rim, lineWidth: 1))
    }
}

/// The striped edge where the illustrated map meets the paper of the travel journal.
struct BayPostmarkEdge: View {
    var body: some View {
        Canvas { context, size in
            for x in stride(from: CGFloat(-5), to: size.width, by: 40) {
                for (offset, color) in [(CGFloat.zero, BayUI.rust), (CGFloat(20), BayUI.navy)] {
                    let left = x + offset
                    var stripe = Path()
                    stripe.move(to: CGPoint(x: left, y: size.height))
                    stripe.addLine(to: CGPoint(x: left + 4, y: 0))
                    stripe.addLine(to: CGPoint(x: left + 11, y: 0))
                    stripe.addLine(to: CGPoint(x: left + 7, y: size.height))
                    stripe.closeSubpath()
                    context.fill(stripe, with: .color(color))
                }
            }
        }.frame(height: 4).background(BayUI.paper).accessibilityHidden(true)
    }
}
