import SwiftUI

struct GrowthCelebration: Identifiable {
    let previous: Int
    let current: Int
    var id: Int { current }
    var evolved: Bool { Growth.stage(current) > Growth.stage(previous) }
    var leveledUp: Bool { current / 100 > previous / 100 }
    var title: String { evolved ? "我们的新模样" : (leveledUp ? "伙伴升级啦" : "你的努力，我收到了") }
}

struct InteractivePetView: View {
    let stage: Int
    let name: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var taps = 0
    @State private var bouncing = false
    @State private var response: String?
    private let responses = ["在呢，今天也陪着你。", "摸摸收到啦！", "慢慢来，我们一起长大。", "能见到你就很开心。"]
    var body: some View {
        Button {
            response = responses[taps % responses.count]
            taps += 1
            withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.45)) { bouncing = true }
        } label: {
            PetView(stage: stage)
                .scaleEffect(bouncing && !reduceMotion ? 1.06 : 1)
                .rotationEffect(.degrees(bouncing && !reduceMotion ? -3 : 0))
                .overlay(alignment: .top) {
                    if let response {
                        Text(response).font(.caption.weight(.medium)).foregroundStyle(Palette.green)
                            .multilineTextAlignment(.center).padding(10)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                            .padding(.horizontal, 8).allowsHitTesting(false)
                    }
                }
        }.buttonStyle(.plain)
            .accessibilityLabel("摸摸\(name)")
            .accessibilityValue(response ?? "点一下，和伙伴打招呼")
            .sensoryFeedback(.selection, trigger: taps)
            .task(id: taps) {
                guard taps > 0 else { return }
                do {
                    try await Task.sleep(for: .milliseconds(300))
                    withAnimation(reduceMotion ? nil : .spring()) { bouncing = false }
                    try await Task.sleep(for: .seconds(3))
                    response = nil
                } catch { }
            }
    }
}

struct GrowthCelebrationView: View {
    let event: GrowthCelebration
    let name: String
    let dismiss: () -> Void
    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: event.evolved ? "sparkles" : "heart.fill")
                .font(.largeTitle).foregroundStyle(Palette.green)
            Text(event.title).font(.title.bold())
            PetView(stage: Growth.stage(event.current)).frame(height: 220)
            Text("\(name)获得了 \(event.current - event.previous) 成长能量")
                .font(.headline).multilineTextAlignment(.center)
            Text(event.evolved ? "已解锁\(Growth.stageName(event.current))" : "Lv.\(1 + event.current / 100) · 每一点坚持都有回应")
                .foregroundStyle(Palette.green)
            Text("能量已自动保存，无需领取。")
                .font(.caption).foregroundStyle(.secondary)
            Button("一起继续成长", action: dismiss).buttonStyle(.borderedProminent).controlSize(.large)
        }.padding(24).frame(maxWidth: .infinity).background(Palette.background)
            .presentationDetents([.large]).presentationDragIndicator(.visible)
    }
}
