import SwiftUI
import UIKit

// Static key poses from the approved concept atlas. This preview deliberately
// does not change the user's existing pet or award growth for repeated taps.
struct NewCompanionPreview: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var species = 0
    @State private var pose = 0
    private let names = ["芽芽", "小影"]
    private let poses = ["摸摸", "开心", "睡觉"]
    private static let sprites: [[UIImage?]] = {
        guard let atlas = UIImage(named: "CompanionPoses")?.cgImage else { return [] }
        let width = atlas.width / 3
        let height = atlas.height / 2
        return (0..<2).map { row in
            (0..<3).map { column in
                atlas.cropping(to: CGRect(x: column * width, y: row * height,
                                         width: width, height: height)).map { UIImage(cgImage: $0) }
            }
        }
    }()
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Picker("预览伙伴", selection: $species) {
                        ForEach(0..<2, id: \.self) { Text(names[$0]).tag($0) }
                    }.pickerStyle(.segmented)
                    Text(names[species]).font(.largeTitle.bold())
                    Text(species == 0 ? "软乎乎的叶耳伙伴" : "爱追光点的小狐狸")
                        .foregroundStyle(.secondary)
                    Button {
                        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { pose = (pose + 1) % 3 }
                    } label: {
                        Group {
                            if Self.sprites.indices.contains(species), let sprite = Self.sprites[species][pose] {
                                Image(uiImage: sprite).resizable().scaledToFit()
                            } else {
                                Image(systemName: "pawprint.fill").resizable().scaledToFit().padding(60)
                            }
                        }.frame(maxWidth: .infinity).frame(height: 300)
                            .contentShape(Rectangle())
                    }.buttonStyle(.plain)
                        .accessibilityLabel("\(names[species])，\(poses[pose])，轻点切换姿态")
                    Picker("互动姿态", selection: $pose) {
                        ForEach(0..<3, id: \.self) { Text(poses[$0]).tag($0) }
                    }.pickerStyle(.segmented)
                    Text(pose == 0 ? "摸摸收到啦，今天也陪着你。" : pose == 1 ? "见到你就很开心！" : "休息一会儿，醒来再一起玩。")
                        .font(.headline).multilineTextAlignment(.center)
                    Text("新伙伴外观预览 · 轻点精灵切换姿态\n当前伙伴和成长记录不会改变。")
                        .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }.padding(24)
            }.background(Palette.background)
                .navigationTitle("认识新伙伴").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
        }
    }
}
