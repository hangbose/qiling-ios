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
    var settled = false
    var reacting = false
    var showLooseGlass = false

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
                if showLooseGlass && corner.glass == nil {
                    Image(systemName: "diamond.fill").font(.system(size: w * 0.03))
                        .foregroundStyle(Color.mint).position(x: w * 0.54, y: h * 0.75)
                } else if corner.glass == .chime {
                    Image(systemName: "diamond.fill").font(.system(size: w * 0.022))
                        .foregroundStyle(Color.cyan)
                        .position(x: w * (ringing ? 0.242 : 0.235), y: h * 0.65)
                } else if corner.glass == .lamp {
                    Ellipse().fill(.mint.opacity(0.52)).frame(width: w * 0.048, height: w * 0.048)
                        .position(x: w * 0.73, y: h * 0.605)
                    ForEach(0..<(settled ? 5 : 3), id: \.self) { n in
                        Circle().fill(Color.yellow).frame(width: w * 0.011, height: w * 0.011)
                            .position(x: w * (0.65 + CGFloat(n) * 0.032),
                                      y: h * ((n.isMultiple(of: 2) ? 0.68 : 0.71) - (reacting ? 0.032 : 0)))
                    }
                }
                BaySprite(kind: pet, walking: false, grown: grown)
                    .frame(width: w * 0.15, height: w * 0.15)
                    .position(x: w * (corner.glass == .lamp ? 0.63 : 0.37),
                              y: h * 0.79 - w * (reacting && settled && corner.glass == .chime ? 0.10 : 0.075))
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
    @State private var reacting = false
    @State private var player: AVAudioPlayer?
    @State private var postcard: Image?
    private var corner: BayKeepsakes { model.bay.keepsakes ?? BayKeepsakes() }
    private var ready: Bool { corner.isReady(days: model.bay.days) }
    private var grown: Bool { model.trailTrick == .constellation }
    private var name: String { model.demo ? (CompanionKind(rawValue: pet)?.title ?? "精灵") : model.state.petName }
    private var hasGlassStory: Bool { corner.hasShell && (corner.glass != nil || !model.bay.days.isEmpty) }
    private var settled: Bool { corner.glassHasSettled(on: model.keepsakeDay) }
    private var glassNote: String {
        switch corner.glass {
        case nil: return name + "低头嗅了嗅。潮水退去的地方，有一片蓝玻璃。"
        case .pocket: return "海玻璃在你手里。挂在风里，还是让它透出一点蓝光？"
        case .chime: return settled ? name + "又蹲在风铃旁，举起了一只前爪。" : "海玻璃碰着白贝，" + name + "竖起了耳朵。"
        case .lamp: return settled ? "上次灯下有三只萤火虫，这回有五只了。" : "草尖映着蓝光。三只萤火虫停在灯下。"
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                BayBenchArt(corner: corner, pet: pet, grown: grown, ringing: ringing, settled: settled,
                            reacting: reacting, showLooseGlass: hasGlassStory)
                    .overlay(alignment: .topLeading) {
                        Text("深圳湾 · 海边长椅").font(BayUI.heading(20)).foregroundStyle(BayUI.cream)
                            .padding(8).fieldPlate().padding(9)
                    }
                    .overlay { if hasGlassStory { glassTargets } }
                if !message.isEmpty || hasGlassStory {
                    Text(message.isEmpty ? glassNote : message).font(.subheadline.weight(.medium))
                        .foregroundStyle(BayUI.ink)
                }
                if !corner.hasShell {
                    Text("树枝下有一枚白贝").font(BayUI.heading(24))
                    Text(name + "把白贝推到你脚边。木架上还空着一个小钩。")
                    Button("挂上白贝") {
                        model.changeKeepsakes { $0.hasShell = true }
                        message = model.bay.days.isEmpty ? "白贝晃了两下。明天想让" + name + "去哪儿？" : ""
                    }.buttonStyle(BayKey(primary: true))
                } else if let errand = corner.errand {
                    let route = errand.route
                    let find = route.finds[min(corner.level(route), route.finds.count - 1)]
                    Text(ready ? name + "带回了" + find : name + "去了" + route.title).font(BayUI.heading(24))
                    if ready {
                        Button("把" + find + "装到长椅边") {
                            let dayLog = model.bay.days
                            model.changeKeepsakes { _ = $0.unpack(days: dayLog) }
                            message = route.notes[max(0, corner.level(route) - 1)]
                        }.buttonStyle(BayKey(primary: true))
                    } else {
                        let when = model.keepsakeDay > errand.departure ? "今天" : "明天起"
                        Text(when + "，手表同步或你记下一个习惯，" + name + "就会带回" + find + "。晚几天来，它也会等你。")
                        if model.demo {
                            Button("试玩下一天") { model.demoBayDay(kind: pet, relay: relay); message = "" }.buttonStyle(BayKey(primary: true))
                        }
                    }
                } else if !corner.finished {
                    Text("让" + name + "去哪儿寻宝？").font(BayUI.heading(24))
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

    private var glassTargets: some View {
        GeometryReader { geo in
            let size = geo.size
            if corner.glass == nil {
                glassButton("拾起海玻璃", x: 0.54, y: 0.83, size: size) {
                    model.changeKeepsakes { $0.pickGlass(hasHabit: !model.bay.days.isEmpty) }
                    message = ""
                }
            } else {
                if corner.glass != .lamp {
                    glassButton(corner.glass == .pocket ? "挂到风铃上" : "拨一下风铃", x: 0.22, y: 0.84, size: size) { touchGlass(.chime) }
                }
                if corner.glass != .chime {
                    glassButton(corner.glass == .pocket ? "嵌进灯罩" : "碰碰路灯", x: 0.73, y: 0.78, size: size) { touchGlass(.lamp) }
                }
            }
        }
    }
    private func glassButton(_ title: String, x: CGFloat, y: CGFloat, size: CGSize, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.caption.weight(.semibold)).padding(.horizontal, 7).padding(.vertical, 3)
                .fieldPlate(BayUI.cream).frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
        }.buttonStyle(.plain).position(x: size.width * x, y: size.height * y)
    }
    private func touchGlass(_ place: BayGlass) {
        let placing = corner.glass == .pocket
        if placing {
            let day = model.keepsakeDay
            model.changeKeepsakes { $0.placeGlass(place, on: day) }
            message = ""
        } else if place == .chime {
            message = settled ? "叮、叮。" + name + "也用前爪轻轻拍了两下。" : name + "歪着头，一直听到最后一声。"
        } else {
            message = settled ? name + "在灯下趴好，望着五点萤火。" : "你碰了碰灯罩，三点萤火从草尖飞了起来。"
        }
        if place == .chime { ring() }
        if !reduced {
            withAnimation(.easeInOut(duration: 0.25).repeatCount(2, autoreverses: true)) { reacting = true }
            Task { @MainActor in try? await Task.sleep(for: .milliseconds(570)); reacting = false }
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
        .onChange(of: corner.glass) { _, _ in postcard = nil }
        .onChange(of: corner.levels) { _, _ in postcard = nil }
    }
    private func ring() {
        if let url = Bundle.main.url(forResource: "BayChime", withExtension: "wav") {
            player = try? AVAudioPlayer(contentsOf: url)
            player?.play()
        }
        if !reduced {
            withAnimation(.easeInOut(duration: 0.18).repeatCount(4, autoreverses: true)) { ringing = true }
            Task { @MainActor in try? await Task.sleep(for: .milliseconds(900)); ringing = false }
        }
    }
    @ViewBuilder private var playButton: some View {
        if corner.glass != .chime {
            Button(corner.level(.tide) > 0 ? "拨响风铃" : "听白贝") {
                ring()
                message = corner.level(.tide) > 0 ? "叮、叮。贝壳在风里碰了两下。" : "白贝轻轻碰在木架上。"
            }.buttonStyle(BayKey())
        }
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
                    BayBenchArt(corner: corner, pet: pet, grown: grown, settled: settled)
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

