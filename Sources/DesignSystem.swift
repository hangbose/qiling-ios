import SwiftUI

struct RoomBackdrop: View {
    var body: some View {
        GeometryReader { proxy in
            Image("CompanionRoom").resizable().scaledToFill()
                .frame(width: proxy.size.width, height: proxy.size.height).clipped()
                .overlay(.white.opacity(0.12))
        }
        .accessibilityHidden(true)
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
                .foregroundStyle(Palette.ink).frame(width: 42, height: 42)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                .overlay(alignment: .topTrailing) {
                    if dot { Circle().fill(.red).frame(width: 7, height: 7).padding(8) }
                }
        }.accessibilityLabel(label)
    }
}

struct ScreenTitle<Trailing: View>: View {
    let title: String
    let trailing: Trailing
    init(title: String, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.trailing = trailing()
    }
    var body: some View {
        HStack {
            Text(title).font(.system(size: 32, weight: .bold)).tracking(-1)
            Spacer()
            trailing
        }.foregroundStyle(Palette.ink)
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
            .navigationTitle(content.title).navigationBarTitleDisplayMode(.inline)
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
            Text(title).font(.system(size: 17, weight: .semibold))
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
        padding(16).background(.white.opacity(0.88), in: RoundedRectangle(cornerRadius: 25))
    }
}
