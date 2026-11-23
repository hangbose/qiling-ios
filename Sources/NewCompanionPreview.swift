import SwiftUI

struct NewCompanionPreview: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selected = CompanionKind.legacy
    @State private var pose = 0
    @State private var confirming = false
    private let species: [CompanionKind] = [.legacy, .yaya, .xiaoying]
    private let poses = ["摸摸", "散步", "打盹"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    FieldCover(art: "BayPark", title: selected.title, caption: "伙伴图鉴", height: 254) {
                        Button { pose = (pose + 1) % poses.count } label: {
                            ZStack(alignment: .topTrailing) {
                                BaySprite(kind: selected.rawValue, walking: pose == 1 && !reduceMotion)
                                    .rotationEffect(.degrees(pose == 2 ? -9 : 0))
                                if pose == 2 { Text("z Z").font(BayUI.type(15)).padding(4).fieldPlate(BayUI.cream) }
                            }.frame(width: 132, height: 132)
                        }.buttonStyle(.plain).accessibilityLabel("\(selected.title)，\(poses[pose])，点按切换姿态")
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom).padding(.bottom, 8)
                    }
                    HStack(spacing: 8) {
                        ForEach(species, id: \.rawValue) { kind in
                            Button { selected = kind; pose = 0 } label: {
                                VStack(spacing: 2) {
                                    BaySprite(kind: kind.rawValue, walking: false).frame(height: 48)
                                    Text(kind.title)
                                }.frame(maxWidth: .infinity).padding(.vertical, 6)
                            }.buttonStyle(BayKey(primary: selected == kind)).accessibilityAddTraits(selected == kind ? .isSelected : [])
                        }
                    }
                    Picker("互动姿态", selection: $pose) {
                        ForEach(poses.indices, id: \.self) { Text(poses[$0]).tag($0) }
                    }.pickerStyle(.segmented)
                    Text(selected == .legacy ? "星澜摇着星星尾巴，等你一起出发。" : selected == .yaya ? "芽芽抖抖长耳朵，从草坡上蹦了下来。" : "小影系好金围巾，沿着路灯去探险。")
                        .font(.body).softPanel()
                    Button { confirming = true } label: {
                        Text(selected == model.companion ? "正在同行" : "带\(selected.title)同行").frame(maxWidth: .infinity)
                    }.buttonStyle(BayKey(primary: true)).disabled(model.demo || selected == model.companion)
                    Text(model.demo ? "演示模式可预览伙伴。退出演示后可更换主宠。" : "更换伙伴后保留全部经验，昵称会更新为伙伴的名字。")
                        .font(.footnote).foregroundStyle(BayUI.muted)
                }.padding(16)
            }.background(BayUI.paper).navigationTitle("伙伴图鉴").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
                .onAppear { selected = model.companion }
                .confirmationDialog("带\(selected.title)一起走？", isPresented: $confirming, titleVisibility: .visible) {
                    Button("确认同行") { model.adopt(selected); dismiss() }
                }
        }
    }
}
