import SwiftUI

enum BayUI {
    static let ink = Color(red: 0.09, green: 0.20, blue: 0.23)
    static let pine = Color(red: 0.15, green: 0.29, blue: 0.30)
    static let rim = Color(red: 0.78, green: 0.66, blue: 0.46)
    static let cream = Color(red: 1, green: 0.94, blue: 0.81)
    static let honey = Color(red: 1, green: 0.79, blue: 0.47)
    static let peach = Color(red: 0.94, green: 0.63, blue: 0.46)
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
    func fieldPlate(_ fill: Color = BayUI.pine, edge: Color = BayUI.rim) -> some View {
        background(BayCut().fill(fill))
            .shadow(color: BayUI.ink, radius: 0, y: 3)
            .overlay(BayCut().stroke(edge, lineWidth: 1))
    }
}
struct BayKey: ButtonStyle {
    var light = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(BayUI.type(16))
            .padding(.horizontal, 11).frame(minHeight: 44)
            .foregroundStyle(light ? BayUI.ink : BayUI.cream)
            .background(BayCut().fill(light ? BayUI.honey : BayUI.pine))
            .overlay(BayCut().stroke(light ? BayUI.cream : BayUI.rim, lineWidth: 1.4))
            .shadow(color: BayUI.ink, radius: 0, y: configuration.isPressed ? 0 : 3)
            .offset(y: configuration.isPressed ? 2 : 0)
    }
}
