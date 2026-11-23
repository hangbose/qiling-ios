import SwiftUI

struct FieldCover<Overlay: View>: View {
    let art: String
    let title: String
    let caption: String
    let height: CGFloat
    @ViewBuilder let overlay: () -> Overlay
    var body: some View {
        ZStack(alignment: .topLeading) {
            GeometryReader { size in
                Image(art).resizable().interpolation(.none).scaledToFill()
                    .frame(width: size.size.width, height: size.size.height).clipped().accessibilityHidden(true)
            }
            overlay()
            VStack(alignment: .leading, spacing: 5) {
                Text(caption).font(.caption.weight(.semibold))
                Text(title).font(BayUI.type(27)).accessibilityAddTraits(.isHeader)
            }.foregroundStyle(BayUI.cream).padding(10).fieldPlate().padding(12)
        }.frame(height: height).overlay(alignment: .bottom) { BayPostmarkEdge() }
    }
}

struct FieldGroupStyle: GroupBoxStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            configuration.label.font(BayUI.type(17)).foregroundStyle(BayUI.navy)
            configuration.content
        }.frame(maxWidth: .infinity, alignment: .leading).softPanel()
    }
}

struct RoundAction: View {
    let symbol: String
    let label: String
    var dot = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 19, weight: .medium))
                .foregroundStyle(Palette.ink).frame(width: 44, height: 44)
                .fieldPlate(BayUI.cream)
                .overlay(alignment: .topTrailing) {
                    if dot { Circle().fill(.red).frame(width: 7, height: 7).padding(8) }
                }
        }.accessibilityLabel(label)
    }
}

struct DetailContent: Identifiable {
    let id = UUID()
    let title: String
    let text: String
}

struct DetailSheet: View {
    let content: DetailContent
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                Text(content.text).font(.body).lineSpacing(8)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(24)
            }
            .background(BayUI.paper).navigationTitle(content.title).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
        }
        .presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
    }
}

struct SectionHeading: View {
    let title: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    var body: some View {
        HStack {
            Rectangle().fill(BayUI.rust).frame(width: 4, height: 16)
            Text(title).font(BayUI.type(18))
            Spacer()
            if let actionTitle, let action {
                Button(action: action) {
                    HStack(spacing: 3) { Text(actionTitle); Image(systemName: "chevron.right") }
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
        }
    }
}

extension View {
    func softPanel() -> some View {
        padding(16).fieldPlate(BayUI.cream)
    }
}
