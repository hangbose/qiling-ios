import SwiftUI
import AVFoundation

struct BayFindSprite: View {
    let column: Int
    let row: Int
    var body: some View {
        GeometryReader { geo in
            Image("BayFinds").resizable().interpolation(.none)
                .frame(width: geo.size.width * 4, height: geo.size.height * 4)
                .offset(x: -CGFloat(column) * geo.size.width, y: -CGFloat(row) * geo.size.height)
        }.clipped().accessibilityHidden(true)
    }
}

struct BayBenchArt: View {
    let corner: BayKeepsakes
    let pet: String
    let grown: Bool
    var ringing = false

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack(alignment: .topLeading) {
                Image("BayJourney").resizable().interpolation(.none)
                if corner.hasShell {
                    let sprite = corner.sprite(.tide) ?? (column: 0, row: 3)
                    BayFindSprite(column: sprite.column, row: sprite.row)
                        .rotationEffect(.degrees(ringing ? 7 : 0), anchor: .bottomLeading)
                        .frame(width: w * 0.17, height: w * 0.17)
                        .position(x: w * 0.21, y: h * 0.763 - w * 0.085)
                }
                if let sprite = corner.sprite(.light) {
                    BayFindSprite(column: sprite.column, row: sprite.row)
                        .frame(width: w * 0.115, height: w * 0.115)
                        .position(x: w * 0.065, y: h * 0.795 - w * 0.0575)
                }
                if let sprite = corner.sprite(.post) {
                    BayFindSprite(column: sprite.column, row: sprite.row)
                        .frame(width: w * 0.16, height: w * 0.16)
                        .position(x: w * 0.71, y: h * 0.706 - w * 0.08)
                }
                BaySprite(kind: pet, walking: false, grown: grown)
                    .frame(width: w * 0.15, height: w * 0.15)
                    .position(x: w * 0.37, y: h * 0.79 - w * 0.075)
            }
        }.aspectRatio(4 / 3.0, contentMode: .fit)
        .accessibilityLabel("深圳湾长椅，已布置 \(corner.levels.values.reduce(0, +)) 件寻回物")
    }
}

struct BayBenchView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduced
    let pet: String
    let relay: Bool
    @State private var message = ""
    @State private var ringing = false
    @State private var player: AVAudioPlayer?
    @State private var postcard: Image?
    private var corner: BayKeepsakes { model.bay.keepsakes ?? BayKeepsakes() }
    private var ready: Bool { corner.isReady(days: model.bay.days) }
    private var grown: Bool { model.trailTrick == .constellation }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                BayBenchArt(corner: corner, pet: pet, grown: grown, ringing: ringing)
                    .overlay(alignment: .topLeading) {
                        Text("深圳湾 · 海边长椅").font(BayUI.heading(20)).foregroundStyle(BayUI.cream)
                            .padding(8).fieldPlate().padding(9)
                    }
                if !message.isEmpty { Text(message).font(.subheadline.weight(.medium)).foregroundStyle(BayUI.rust) }
                if !corner.hasShell {
                    Text("树枝下有一枚白贝").font(BayUI.heading(24))
                    Text("精灵把它推到你掌心。旁边的木架，刚好可以挂下第一枚贝壳。")
                    Button("挂上第一枚白贝") {
                        model.changeKeepsakes { $0.hasShell = true }
                        message = "白贝轻轻晃了两下，精灵抬起头等你指路。"
                    }.buttonStyle(BayKey(primary: true))
                } else if let errand = corner.errand {
                    let route = errand.route
                    let find = route.finds[min(corner.level(route), route.finds.count - 1)]
                    Text(ready ? "精灵带回了" + find : "精灵惦记着" + route.title).font(BayUI.heading(24))
                    if ready {
                        Button("把" + find + "装到长椅边") {
                            let dayLog = model.bay.days
                            model.changeKeepsakes { _ = $0.unpack(days: dayLog) }
                            message = route.notes[max(0, corner.level(route) - 1)]
                        }.buttonStyle(BayKey(primary: true))
                    } else {
                        Text("出发日之后，记下一天好习惯就能带回" + find + "。手表同步或手动打卡都算，晚几天来也会等你。")
                        if model.demo {
                            Button("试玩下一天") { model.demoBayDay(kind: pet, relay: relay); message = "" }.buttonStyle(BayKey(primary: true))
                        }
                    }
                } else if !corner.finished {
                    Text("下一趟，去哪里？").font(BayUI.heading(24))
                    ForEach(BayOuting.allCases.filter { corner.level($0) < $0.finds.count }) { route in
                        Button {
                            let day = model.keepsakeDay
                            model.changeKeepsakes { $0.send(route, on: day) }
                            message = ""
                        } label: {
                            HStack(spacing: 10) {
                                BayFindSprite(column: corner.level(route), row: route.row).frame(width: 46, height: 46)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(route.title).font(.headline)
                                    Text("寻找" + route.finds[corner.level(route)]).font(.subheadline).foregroundStyle(BayUI.muted)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").foregroundStyle(BayUI.rust)
                            }.padding(8).background(BayUI.paper)
                        }.buttonStyle(.plain)
                    }
                } else {
                    Text("这段海湾有了你的模样").font(BayUI.heading(24))
                    Text("九件寻回物都到了。可以来听风、给长椅换灯色，或寄出一张此刻的风景。")
                }
                if corner.hasShell { benchActions }
            }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var benchActions: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            Text("长椅边").font(.headline)
            ViewThatFits(in: .horizontal) {
                HStack { playButton; lampButton; cardButton }
                VStack(alignment: .leading) { playButton; lampButton; cardButton }
            }
            if let url = corner.visitURL(pet: pet, grown: grown) {
                ShareLink(item: url) { Label("请朋友来坐坐", systemImage: "envelope.open") }
                    .buttonStyle(BayKey())
            }
            if let postcard {
                ShareLink(item: postcard, preview: SharePreview("我的深圳湾长椅", image: postcard)) {
                    Label("分享这张明信片", systemImage: "square.and.arrow.up")
                }.buttonStyle(BayKey(primary: true))
            }
        }
        .onChange(of: corner.seaGlassLamp) { _, _ in postcard = nil }
        .onChange(of: corner.levels) { _, _ in postcard = nil }
    }
    private var playButton: some View {
        Button(corner.level(.tide) > 0 ? "拨响风铃" : "听白贝") {
            if let url = Bundle.main.url(forResource: "BayChime", withExtension: "wav") {
                player = try? AVAudioPlayer(contentsOf: url)
                player?.play()
            }
            message = corner.level(.tide) > 0 ? "叮、叮。海风拨过你串好的贝壳。" : "白贝轻轻碰在木架上。"
            if !reduced {
                withAnimation(.easeInOut(duration: 0.18).repeatCount(4, autoreverses: true)) { ringing = true }
                Task { @MainActor in try? await Task.sleep(for: .milliseconds(900)); ringing = false }
            }
        }.buttonStyle(BayKey())
    }
    @ViewBuilder private var lampButton: some View {
        if corner.level(.light) > 0 {
            Button("换灯色") {
                model.changeKeepsakes { $0.seaGlassLamp.toggle() }
                message = corner.seaGlassLamp ? "灯光变成了海玻璃的青色。" : "灯光变回暖暖的琥珀色。"
            }.buttonStyle(BayKey())
        }
    }
    @ViewBuilder private var cardButton: some View {
        if corner.level(.post) > 0 {
            Button("印明信片") {
                let card = VStack(alignment: .leading, spacing: 0) {
                    BayBenchArt(corner: corner, pet: pet, grown: grown)
                    HStack {
                        Text("我的深圳湾长椅").font(BayUI.heading(24))
                        Spacer()
                        Text(["", "深圳湾", "海鸥邮戳", "海鸥邮戳 · 红旗"][corner.level(.post)]).font(.caption).foregroundStyle(BayUI.rust)
                    }.padding(14)
                }.frame(width: 360).background(BayUI.cream).foregroundStyle(BayUI.ink)
                let renderer = ImageRenderer(content: card)
                renderer.scale = 3
                postcard = renderer.uiImage.map { Image(uiImage: $0) }
            }.buttonStyle(BayKey())
        }
    }
}

