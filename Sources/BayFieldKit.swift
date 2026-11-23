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
    static func type(_ size: CGFloat) -> Font { .custom("BayLetterpress", size: size, relativeTo: .body) }
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
            .shadow(color: BayUI.ink.opacity(0.30), radius: 0, y: 2)
            .overlay(BayCut().stroke(edge, lineWidth: 1))
    }
}
struct BayKey: ButtonStyle {
    var primary = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(BayUI.type(16))
            .padding(.horizontal, 11).frame(minHeight: 44)
            .foregroundStyle(primary ? BayUI.cream : BayUI.ink)
            .background(BayCut().fill(primary ? BayUI.navy : BayUI.cream))
            .overlay(BayCut().stroke(primary ? BayUI.ink : BayUI.rim, lineWidth: 1))
            .shadow(color: BayUI.ink.opacity(0.22), radius: 0, y: configuration.isPressed ? 0 : 2)
            .offset(y: configuration.isPressed ? 2 : 0)
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
