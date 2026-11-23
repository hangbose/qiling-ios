import SwiftUI

private enum BaySheet: String, Identifiable {
    case journal, travel, card, shop, atlas, focus, bench
    var id: Self { self }
    var title: String {
        switch self {
        case .bench: return "我的海边长椅"
        case .journal: return "旅行手记"
        case .travel: return "结伴同行"
        case .card: return "深圳漫步明信片"
        case .shop: return "旅途小铺"
        case .atlas: return "深圳旅图"
        case .focus: return "和精灵专注"
        }
    }
}

struct BayJourneyView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var phase
    @Binding var tab: AppTab
    @State private var sheet: BaySheet?
    @State private var shown = 0
    @State private var walking = false
    @State private var goal = Date()
    @State private var cardImage: Image?
    @State private var visiting: Int?
    @State private var entrance: Int?
    @State private var editX = 0.5
    @State private var cameraFocus: Double?
    @State private var editing: BaySouvenir?
    @State private var editDistrict = 0
    @State private var demoPet = "legacy"
    private var relay: Bool {
        guard model.bay.relayPaused != true, let code = model.bay.relayCode else { return false }
        return model.demo ? code == "demo" : code == model.state.squadCode
    }
    private var route: String { relay ? "team-" + (model.bay.relayCode ?? "") : "solo" }
    private var count: Int { relay ? model.bay.relaySteps.count : model.bay.days.count }
    private var legacyCount: Int {
        relay ? (model.demo ? 0 : model.bay.shortRelaySteps ?? model.bay.relaySteps.count) : (model.bay.shortRouteDays ?? 0)
    }
    private var trail: BayTrail { BayTrail(shown, legacyCount: legacyCount) }
    private var earnedTrail: BayTrail { BayTrail(count, legacyCount: legacyCount) }
    private var region: Int { visiting.flatMap { earnedTrail.canVisit($0) ? $0 : nil } ?? entrance ?? trail.district }
    private var area: BayDistrict { BayDistrict.all[region] }
    private var ticks: Int { visiting != nil ? earnedTrail.visitTicks(region) : entrance != nil ? 0 : trail.ticks(in: region) }
    private var fraction: Double { Double(ticks * 3) / Double(area.length) }
    private var litCount: Int { Int(fraction) }
    private var shells: Int { model.bay.balance }
    private var souvenirs: [BaySouvenir] { BaySouvenir.catalog.filter { model.bay.owns($0) } }
    private var actor: String { model.demo ? demoPet : model.companion.rawValue }
    private var grown: Bool { model.bay.days.count >= 5 }
    private var corner: BayKeepsakes { model.bay.keepsakes ?? BayKeepsakes() }
    private var friend: BayRelayStep? {
        guard relay else { return nil }
        return model.bay.relaySteps.last(where: { !$0.key.hasPrefix((model.demo ? "me" : model.bay.relayUser ?? "") + "|") })
    }
    private var lastEntry: String {
        if visiting != nil { return "重游" + area.title }
        if walking { return "正走向" + area.stops[min(2, litCount)] }
        if shown == 0 { return "从海边长椅出发" }
        if relay, let step = model.bay.relaySteps.prefix(shown).last { return step.name + "接上了一程" }
        return litCount > 0 && fraction == Double(litCount) ? "点亮了" + area.stops[litCount-1] : "走向" + area.stops[min(2,litCount)]
    }

    private func scene(_ region: Int, ticks: Int, follows: Bool = false, previewFocus: Double? = nil) -> BayScene {
        let progress = Double(ticks * 3) / Double(BayDistrict.all[region].length)
        return BayScene(stop: Int(progress), kind: actor, together: friend?.companion,
            walking: follows && previewFocus == nil && walking, follows: follows, souvenirs: souvenirs,
            district: region, fraction: progress, placements: model.bay.placements ?? [:], keepsakes: corner, grown: grown,
            buddyGrown: friend.map { f in model.bay.relaySteps.filter { $0.key.split(separator: "|").first == f.key.split(separator: "|").first }.count >= 5 } ?? false,
            focusX: previewFocus ?? (follows ? cameraFocus : nil), onPan: follows && previewFocus == nil ? { cameraFocus = $0 } : nil)
    }

    var body: some View {
        NavigationStack {
            GeometryReader { viewport in
                ScrollView {
                    let height = viewport.size.height
                    let needsHealthInvite = !model.demo && !model.state.requestedHealth
                    let controlHeight: CGFloat = needsHealthInvite ? 220 : 167
                    let sceneHeight = min(height * 0.765, max(height * 0.56, height - controlHeight))
                    journey(sceneHeight: sceneHeight)
                }
                .refreshable { await model.sync(); await model.refreshBay() }
            }.background(BayUI.paper.ignoresSafeArea()).foregroundStyle(BayUI.ink)
                .toolbar(.hidden, for: .navigationBar)
                .tint(BayUI.rust)
                .task { await model.refreshBay() }
                .onChange(of: phase) { _, value in if value == .active { Task { await model.refreshBay() } } }
                .task(id: "\(model.demo)|\(route)|\(count)") { await playArrival() }
                .sheet(item: $sheet) { item in
                    NavigationStack {
                        Group {
                            switch item {
                            case .bench: BayBenchView(pet: actor, relay: relay)
                            case .atlas: atlas
                            case .shop: shop
                            case .journal: journal
                            case .travel: travel
                            case .focus: FocusHabitView(startOnAppear: true).padding(24)
                            case .card:
                                if let image = cardImage {
                                    VStack(spacing: 22) {
                                        image.resizable().scaledToFit()
                                        ShareLink(item: image, preview: SharePreview("深圳漫步明信片", image: image)) {
                                            Label("分享明信片", systemImage: "square.and.arrow.up")
                                        }.buttonStyle(BayKey(primary: true))
                                    }.padding(20)
                                }
                            }
                        }.navigationTitle(item.title)
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { sheet = nil } } }
                    }.foregroundStyle(BayUI.ink).tint(BayUI.rust).presentationBackground(BayUI.cream).presentationDragIndicator(.visible)
                }
        }
    }

    private func journey(sceneHeight: CGFloat) -> some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                scene(region, ticks: ticks, follows: true)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 1.25), value: region)
                    .frame(height: sceneHeight)
                    .clipped()
                    .overlay(alignment: .bottomLeading) {
                        Button { sheet = .bench } label: {
                            Label(corner.isReady(days: model.bay.days) ? "精灵带回了礼物" : corner.entry,
                                  systemImage: corner.errand == nil ? "fossil.shell" : "bag")
                        }.buttonStyle(BayKey()).padding(12)
                    }
                    .overlay(alignment: .bottomTrailing) {
                        if cameraFocus != nil {
                            Button("回到精灵") { cameraFocus = nil }.buttonStyle(BayKey()).padding(12)
                        }
                    }
                HStack(alignment: .top) {
                    Button { sheet = .atlas } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("深圳旅图  \(ticks)/\(area.length) 程 ›").font(.caption.weight(.medium).monospacedDigit()).foregroundStyle(BayUI.blush)
                            Text(area.title).font(BayUI.heading(area.title.count > 4 ? 24 : 30)).foregroundStyle(BayUI.cream)
                        }.padding(.horizontal, 11).padding(.vertical, 7).fieldPlate()
                    }.buttonStyle(.plain).accessibilityLabel("打开深圳旅图，当前在" + area.title)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Button { sheet = .shop } label: {
                            Label("小铺 · \(shells)", systemImage: "fossil.shell.fill")
                        }.buttonStyle(BayKey()).accessibilityLabel("贝壳 \(shells) 枚，打开海湾小铺")
                        if !walking, let last = model.bay.payments.last, last.day == Growth.dayID(Date()),
                           let reason = model.bay.days[last.day] {
                            Text("\(reason) · +\(last.amount) 贝壳").font(.caption.monospacedDigit())
                                .foregroundStyle(BayUI.cream).padding(.horizontal, 7).padding(.vertical, 3).fieldPlate()
                                .accessibilityLabel("今天通过\(reason)获得 \(last.amount) 枚贝壳")
                        }
                    }
                }.padding(12)
            }
            BayPostmarkEdge()
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 6) {
                    ForEach(0..<3) { i in
                        HStack(spacing: 5) {
                            Image(systemName: i < litCount ? "diamond.fill" : "diamond").font(.system(size: 8))
                            Text(area.stops[i]).font(.caption.weight(.medium))
                        }.layoutPriority(1).foregroundStyle(i < litCount ? BayUI.rust : BayUI.muted)
                        if i < 2 { Rectangle().fill(BayUI.rim).frame(minWidth: 2, maxWidth: .infinity).frame(height: 1) }
                    }
                }.accessibilityLabel("亮灯 \(litCount) / 3")
                HStack(alignment: .center, spacing: 9) {
                    BaySprite(kind: actor, walking: false, grown: grown)
                        .frame(width: 36, height: 36).padding(4)
                        .background(BayUI.blush)
                        .overlay {
                            Rectangle().inset(by: 3).stroke(BayUI.rust.opacity(0.65),
                                style: StrokeStyle(lineWidth: 1, dash: [2, 3]))
                        }
                    VStack(alignment: .leading, spacing: 6) {
                        Text(lastEntry).font(.headline.weight(.semibold))
                        Text(voice).font(.subheadline).foregroundStyle(BayUI.muted).lineSpacing(3).fixedSize(horizontal: false, vertical: true)
                        if !model.demo && !model.state.requestedHealth {
                            Button { Task { await model.connect() } } label: {
                                Label(model.connectingHealth ? "正在连接…" : "连接 Apple 健康", systemImage: "heart")
                            }.buttonStyle(.plain).font(.subheadline.bold()).foregroundStyle(BayUI.rust)
                                .disabled(model.connectingHealth)
                        }
                        if let issue = model.bayIssue, relay { Text(issue).font(.caption) }
                    }
                }.padding(8).frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundStyle(BayUI.ink).background(BayUI.cream)
                    .overlay(alignment: .leading) { Rectangle().fill(BayUI.rust).frame(width: 3) }
                HStack {
                    if model.demo {
                        Button { model.demoBayDay(kind: actor, relay: relay) } label: { Label("试玩下一天", systemImage: "sunrise") }.buttonStyle(BayKey(primary: true))
                    } else {
                        let habit = model.bay.quickHabit ?? "阅读"
                        Button {
                            if habit == "专注" { sheet = .focus } else { model.rewardHabit(habit) }
                        } label: {
                            Label(model.habitDone(habit) ? "已记" + habit : habit == "专注" ? "开始专注" : habit + "打卡",
                                  systemImage: model.habitDone(habit) ? "checkmark" : habit == "专注" ? "timer" : "plus")
                        }.buttonStyle(BayKey(primary: true)).disabled(model.habitDone(habit))
                    }
                    Button { sheet = .journal } label: { Text("手记") }.buttonStyle(BayKey())
                    Button { sheet = .travel } label: { Label(relay ? "小队接力" : "结伴同行", systemImage: "person.2") }
                        .buttonStyle(BayKey())
                }
            }.padding(.horizontal, 14).padding(.vertical, 8).frame(maxWidth: .infinity, alignment: .leading).background(BayUI.paper)
        }
    }

    private var voice: String {
        if !model.demo && !model.state.requestedHealth && count == 0 { return "记下一件好习惯，精灵就会出发。连接健康后，步数、睡眠和训练也能自动点亮路程。" }
        if shown == 0 { return "从树荫下出发，点亮深圳的第一盏灯。" }
        if visiting != nil || litCount == 3 { return area.notes[max(0, litCount-1)] }
        if fraction != Double(litCount) { return "再走 \((litCount + 1) * area.length / 3 - ticks) 程，到" + area.stops[litCount] + "。" }
        return area.notes[max(0,litCount-1)]
    }

    @MainActor private func playArrival() async {
        walking = false
        entrance = nil
        let destination = count, key = route
        let last = min(destination, model.bay.seen[key] ?? 0)
        visiting = nil
        cameraFocus = nil
        shown = max(last, destination - 2)
        if reduceMotion { shown = destination }
        else {
            while shown < destination {
                do { try await Task.sleep(for: .milliseconds(400)) } catch { return }
                let next = BayTrail(shown + 1, legacyCount: legacyCount).district
                if next != trail.district {
                    entrance = next
                    // Mount the entrance before moving so the new camera starts inside this district.
                    do { try await Task.sleep(for: .milliseconds(100)) } catch { return }
                }
                walking = true
                let duration = BayPromenadeLayout.duration(next)
                withAnimation(.timingCurve(0.42, 0, 0.58, 1, duration: duration)) {
                    shown += 1
                    entrance = nil
                }
                do { try await Task.sleep(for: .seconds(duration)) } catch { return }
                walking = false
                model.markBaySeen(shown, route: key)
            }
        }
        walking = false
        model.markBaySeen(destination, route: key)
    }

    private var shop: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let editing {
                    Picker("放在哪一站", selection: $editDistrict) {
                        ForEach(BayDistrict.all.indices.filter { earnedTrail.canVisit($0) }, id: \.self) { i in Text(BayDistrict.all[i].title).tag(i) }
                    }
                    scene(editDistrict, ticks: earnedTrail.visitTicks(editDistrict), follows: true, previewFocus: editX)
                        .frame(height: 155)
                    Slider(value: $editX, in: 0.06...0.94).accessibilityLabel("沿路位置")
                    HStack {
                        Button("摆在这里") { place(editing, at: editX) }.buttonStyle(BayKey(primary: true))
                        Spacer()
                        Button("取消") { self.editing = nil }
                    }
                } else {
                    scene(region, ticks: ticks, follows: true, previewFocus: cameraFocus ?? BayPromenadeLayout.routeX(fraction / 3))
                        .frame(height: 155)
                }
                HStack {
                    Label("\(shells) 枚贝壳", systemImage: "fossil.shell.fill").font(.headline)
                    Spacer()
                    Button("收支手记") { sheet = .journal }
                }
                if let last = model.bay.payments.last {
                    Text("最近入账　\(model.bay.days[last.day] ?? "好习惯") +\(last.amount)")
                        .font(.subheadline).foregroundStyle(BayUI.muted)
                } else {
                    Text("完成今天的第一项好习惯，收下 50 枚贝壳。").font(.subheadline)
                }
                ForEach(BaySouvenir.catalog) { item in
                    let owned = model.bay.owns(item)
                    HStack(spacing: 12) {
                        Image(item.asset).resizable().interpolation(.none).frame(width: 44, height: 44)
                            .padding(6).background(BayUI.paper).accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title).font(.headline)
                            Text(owned ? "已摆在" + BayDistrict.all[model.bay.position(of: item).district].title : item.detail)
                                .font(.footnote).foregroundStyle(BayUI.muted)
                            if item == .cottage && !owned {
                                ProgressView(value: Double(min(shells, item.price)), total: Double(item.price))
                                    .tint(BayUI.rust).accessibilityLabel("小屋储蓄进度")
                            }
                        }
                        Spacer(minLength: 0)
                        if owned {
                            Button("换位置") {
                                let spot = model.bay.position(of: item)
                                editDistrict = spot.district; editX = spot.x; editing = item
                            }.buttonStyle(BayKey())
                        } else {
                            VStack(spacing: 4) {
                                Button { model.buyBaySouvenir(item); editDistrict = region; editX = item.x; editing = item } label: {
                                    Text("\(item.price) 枚").monospacedDigit()
                                }.buttonStyle(BayKey(primary: shells >= item.price))
                                    .disabled(shells < item.price)
                                    .accessibilityLabel("花 \(item.price) 枚贝壳买\(item.title)")
                                if shells < item.price {
                                    Text("还差 \(item.price - shells) 枚").font(.caption).foregroundStyle(BayUI.muted)
                                }
                            }
                        }
                    }
                    Divider()
                }
            }.padding(16)
        }.background(BayUI.cream)
    }

    private func place(_ item: BaySouvenir, at x: Double) {
        model.placeBayItem(item, district: editDistrict, x: x, trail: earnedTrail)
        visiting = editDistrict
        cameraFocus = x
        editing = nil
    }

    private var atlas: some View {
        List {
            Section("第 \(trail.lap) 圈 · \(earnedTrail.local)/\(BayDistrict.lapLength) 程") {
                ForEach(BayDistrict.all.indices, id: \.self) { i in
                    let d = BayDistrict.all[i]
                    Button {
                        visiting = i; cameraFocus = nil; sheet = nil
                    } label: {
                        HStack {
                            Image(d.art).resizable().scaledToFill().frame(width: 62,height: 46).clipped()
                            VStack(alignment: .leading) {
                                Text(d.title).font(.headline)
                                Text(d.stops.joined(separator: " · ")).font(.caption)
                            }
                            Spacer()
                            Image(systemName: earnedTrail.canVisit(i) ? "chevron.right" : "lock")
                        }
                    }.disabled(!earnedTrail.canVisit(i))
                }
                Button("回到当前进度") { visiting = nil; cameraFocus = nil; sheet = nil }
                if earnedTrail.lap > 1 || ticks == area.length { Button("收藏这站的明信片") { makeCard(); sheet = .card } }
            }
            Section(grown ? "同行的精灵 · 已长大" : "同行的精灵 · 再走 \(5-model.bay.days.count) 个习惯日长大") {
                ForEach([CompanionKind.legacy, .yaya, .xiaoying], id: \.rawValue) { kind in
                    Button {
                        if model.demo { demoPet = kind.rawValue } else { model.adopt(kind) }
                    } label: {
                        HStack {
                            BaySprite(kind: kind.rawValue, walking: false, grown: grown).frame(width: 42,height: 42)
                            Text(kind.title)
                            Spacer()
                            if actor == kind.rawValue { Image(systemName: "checkmark") }
                        }
                    }
                }
            }
        }.scrollContentBackground(.hidden).background(BayUI.cream)
    }

    private var journal: some View {
        List {
            Section("今日记录") {
                if let today = model.bay.days[Growth.dayID(Date())] { Label(today + "已结算", systemImage: "checkmark.circle.fill") }
                if !model.demo {
                    if !model.state.requestedHealth {
                        Button("连接 Apple 健康，自动点亮路线") { Task { await model.connect() } }
                            .disabled(model.connectingHealth)
                    } else {
                        Text(model.status).font(.footnote)
                        if let last = model.state.lastSync { Text("上次读取 " + last.formatted()).font(.caption) }
                    }
                    Picker("首页一键打卡", selection: Binding(get: { model.bay.quickHabit ?? "阅读" }, set: { model.state.bay?.quickHabit = $0; model.save() })) {
                        ForEach(["阅读","喝水","专注"], id: \.self) { Text($0).tag($0) }
                    }
                }
            }
            Section("我的作息") {
                DatePicker("希望几点入睡", selection: $goal, displayedComponents: .hourAndMinute)
                    .disabled(model.demo)
                    .onAppear { goal = Calendar.current.date(bySettingHour: model.bay.bedtime / 60, minute: model.bay.bedtime % 60, second: 0, of: Date()) ?? Date() }
                    .onChange(of: goal) { _, date in
                        let c = Calendar.current.dateComponents([.hour,.minute], from: date)
                        let minutes = (c.hour ?? 23) * 60 + (c.minute ?? 0)
                        if minutes != model.bay.bedtime { model.setBayBedtime(minutes) }
                    }
                Text("新目标从下一晚生效。按时入睡、睡够目标、当天累计训练 10 分钟（目标更低时按你的目标）或走满 1000 步，会自动前进。每天第一项好习惯结算一次。").font(.footnote)
            }
            Section("贝壳 · \(shells) 枚") {
                Text("每天结算一次，从 50 枚起，连续达成每天多 10 枚，最多 80 枚。间隔一天少一档，已存贝壳一直保留。").font(.footnote)
                ForEach(souvenirs) { item in
                    HStack {
                        Text(item.title)
                        Spacer()
                        Text("−\(model.bay.purchases?[item.id] ?? item.price)").monospacedDigit()
                    }
                }
                ForEach(model.bay.payments.reversed(), id: \.day) { payment in
                    HStack {
                        VStack(alignment: .leading) { Text(model.bay.days[payment.day] ?? "旅途"); Text(payment.day).font(.caption).foregroundStyle(.secondary) }
                        Spacer()
                        Text("+\(payment.amount)").monospacedDigit().foregroundStyle(BayUI.rust)
                    }
                }
            }
        }.scrollContentBackground(.hidden).background(BayUI.cream)
    }
    private var travel: some View {
        List {
            Section {
                Text("加入同一个小队后，可以一起走完深圳五站。每人每天的第一次进步都能接上一段路。贝壳记在各自的背包里。")
                Text("开启后会把昵称、精灵和完成日期同步到小队旅程。睡眠、步数和具体习惯留在自己的手记里。").font(.footnote)
                if model.demo {
                    Button(relay ? "回到单人旅程" : "和示例伙伴接力") { model.switchDemoRelay(!relay) }
                }
                else if model.state.squadCode.isEmpty {
                    Button("去广场创建或加入小队") { sheet = nil; tab = .square }
                } else {
                    Button(relay ? "回到单人旅程" : "开启小队接力") { Task { await model.setBayRelay(!relay) } }
                }
            }
            if relay {
                Section("这一程的同行者") {
                    ForEach(Array(model.bay.relaySteps.suffix(12).reversed()), id: \.key) { step in
                        Label(step.name + " · " + String(step.key.split(separator: "|").last ?? ""), systemImage: "flag.fill")
                    }
                }
            }
        }.scrollContentBackground(.hidden).background(BayUI.cream)
    }
    @MainActor private func makeCard() {
        let card = VStack(alignment: .leading, spacing: 0) {
            scene(region, ticks: area.length)
            VStack(alignment: .leading, spacing: 9) {
                Text(area.title).font(BayUI.heading(32))
                Text(relay ? model.bay.relaySteps.map(\.name).reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }.joined(separator: "、") + " · 一起走过深圳" : model.state.petName + " · 深圳漫步纪念")
                    .font(.subheadline)
            }.padding(20)
        }.frame(width: 360).background(BayUI.cream).foregroundStyle(BayUI.ink)
        let render = ImageRenderer(content: card); render.scale = 3
        cardImage = render.uiImage.map { Image(uiImage: $0) }
    }
}
