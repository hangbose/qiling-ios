import SwiftUI

private enum BaySheet: String, Identifiable {
    case journal, travel, card
    var id: Self { self }
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
    private let names = ["海边长椅", "海湾转角", "观景平台"]
    private var relay: Bool { !model.demo && model.bay.relayCode != nil && model.bay.relayCode == model.state.squadCode }
    private var route: String { relay ? "team-" + model.state.squadCode : "solo" }
    private var count: Int { min(3, relay ? model.bay.relaySteps.count : model.bay.days.count) }
    private var shells: Int { model.bay.payments.reduce(0) { $0 + $1.amount } }
    private var actor: String {
        if relay, shown > 0, let step = model.bay.relaySteps.prefix(shown).last { return step.companion }
        return model.companion.rawValue
    }
    private var second: String? {
        guard relay, shown >= 2 else { return nil }
        let steps = Array(model.bay.relaySteps.prefix(shown))
        guard let last = steps.last else { return nil }
        let user = last.key.split(separator: "|").first
        return steps.dropLast().last(where: { $0.key.split(separator: "|").first != user })?.companion
    }
    private var lastEntry: String {
        if relay, let step = model.bay.relaySteps.prefix(shown).last { return step.name + "点亮了" + names[shown-1] }
        if shown == 0 { return model.state.petName + "在海边等你" }
        return model.state.petName + "走到了" + names[shown-1]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Label("栖灵旅行手记", systemImage: "book.pages").font(.subheadline.weight(.semibold))
                        Spacer()
                        Button { sheet = .journal } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "fossil.shell.fill").foregroundStyle(BayInk.coral)
                                Text("\(shells)").monospacedDigit().bold()
                            }.padding(.horizontal, 13).padding(.vertical, 8)
                                .background(.white.opacity(0.68), in: Capsule())
                        }.accessibilityLabel("贝壳 \(shells) 枚，查看旅行手记")
                    }.padding(.horizontal, 22).padding(.top, 12)
                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("深圳  /  第一站" + (model.demo ? "  ·  演示" : ""))
                                .font(.caption.weight(.semibold)).foregroundStyle(BayInk.coral)
                            Text("深圳湾").font(.system(size: 42, weight: .semibold, design: .serif))
                        }
                        Spacer()
                        Button { sheet = .travel } label: {
                            Label(relay ? "小队接力" : "结伴同行", systemImage: "person.2")
                                .font(.subheadline).padding(.vertical, 10)
                        }
                    }.padding(.horizontal, 22).padding(.top, 12).padding(.bottom, 14)
                    BayScene(stop: shown, kind: actor, together: second, walking: walking)
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Label("海堤漫步", systemImage: "map").font(.headline)
                            Spacer()
                            Text("亮灯 \(shown) / 3").font(.caption.monospacedDigit()).foregroundStyle(BayInk.sea)
                        }
                        HStack(spacing: 0) {
                            ForEach(0..<3) { i in
                                VStack(alignment: .leading, spacing: 7) {
                                    HStack(spacing: 0) {
                                        Image(systemName: i < shown ? "sun.max.fill" : "circle")
                                            .font(.caption).foregroundStyle(i < shown ? BayInk.coral : BayInk.sea)
                                        Rectangle().fill(i < shown ? BayInk.coral.opacity(0.65) : BayInk.sea.opacity(0.22)).frame(height: 1)
                                    }
                                    Text(names[i]).font(.caption.weight(i < shown ? .semibold : .regular))
                                }.frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }.accessibilityElement(children: .combine)
                        Divider()
                        Text(lastEntry).font(.title3.weight(.semibold))
                        if shown == 3 {
                            Button { makeCard(); sheet = .card } label: { Label("收下深圳湾明信片", systemImage: "photo") }
                                .buttonStyle(.borderedProminent)
                        } else if !model.state.requestedHealth && !model.demo {
                            Text("连接健康后，精灵会随着你的睡眠和运动记录自动出发。").font(.subheadline)
                            Button { Task { await model.connect() } } label: { Label("连接 Apple 健康", systemImage: "heart") }
                                .buttonStyle(.borderedProminent)
                        } else {
                            Text(note).font(.subheadline).foregroundStyle(BayInk.sea)
                        }
                        if let issue = model.bayIssue, relay { Text(issue).font(.caption).foregroundStyle(BayInk.coral) }
                        Button("作息目标与旅行手记") { sheet = .journal }.font(.subheadline)
                    }.padding(20).background(Color.white.opacity(0.58), in: RoundedRectangle(cornerRadius: 18))
                        .padding(.horizontal, 16).padding(.vertical, 15)
                }
            }.background(BayInk.paper.ignoresSafeArea()).foregroundStyle(BayInk.text)
                .toolbar(.hidden, for: .navigationBar)
                .tint(BayInk.sea)
                .refreshable { await model.sync(); await model.refreshBay() }
                .task { await model.refreshBay() }
                .onChange(of: phase) { _, value in if value == .active { Task { await model.refreshBay() } } }
                .task(id: "\(model.demo)|\(route)|\(count)") { await playArrival() }
                .sheet(item: $sheet) { item in
                    NavigationStack {
                        Group {
                            switch item {
                            case .journal: journal
                            case .travel: travel
                            case .card:
                                if let image = cardImage {
                                    VStack(spacing: 22) {
                                        image.resizable().scaledToFit()
                                        ShareLink(item: image, preview: SharePreview("深圳湾明信片", image: image)) {
                                            Label("分享明信片", systemImage: "square.and.arrow.up")
                                        }.buttonStyle(.borderedProminent)
                                    }.padding(20)
                                }
                            }
                        }.navigationTitle(item == .journal ? "旅行手记" : item == .travel ? "结伴同行" : "深圳湾明信片")
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { sheet = nil } } }
                    }.tint(BayInk.sea).presentationDragIndicator(.visible)
                }
        }
    }

    private var note: String {
        if let payment = model.bay.payments.last, payment.day == Growth.dayID(Date()) {
            return "今天\(model.bay.days[payment.day] ?? "完成习惯")，\(payment.amount) 枚贝壳已经收进背包。"
        }
        return "下一段路，会在好习惯记录同步后亮起。"
    }

    @MainActor private func playArrival() async {
        walking = false
        let destination = count, key = route
        let last = min(destination, model.bay.seen[key] ?? 0)
        shown = last
        if reduceMotion { shown = destination }
        else {
            while shown < destination {
                do { try await Task.sleep(for: .milliseconds(400)) } catch { return }
                walking = true
                withAnimation(.easeInOut(duration: 1.1)) { shown += 1 }
                do { try await Task.sleep(for: .milliseconds(1150)) } catch { return }
                model.markBaySeen(shown, route: key)
            }
        }
        walking = false
        model.markBaySeen(destination, route: key)
    }

    private var journal: some View {
        List {
            Section("我的作息") {
                DatePicker("希望几点入睡", selection: $goal, displayedComponents: .hourAndMinute)
                    .disabled(model.demo)
                    .onAppear { goal = Calendar.current.date(bySettingHour: model.bay.bedtime / 60, minute: model.bay.bedtime % 60, second: 0, of: Date()) ?? Date() }
                    .onChange(of: goal) { _, date in
                        let c = Calendar.current.dateComponents([.hour,.minute], from: date)
                        let minutes = (c.hour ?? 23) * 60 + (c.minute ?? 0)
                        if minutes != model.bay.bedtime { model.setBayBedtime(minutes) }
                    }
                Text("新目标从下一晚生效。按时入睡、睡眠或训练达标、走满一千步，或在伙伴页记下一项习惯，都能前进一步。").font(.footnote)
            }
            Section("贝壳 · \(shells) 枚") {
                Text("每天结算一次，从 50 枚起，连续达成每天多 10 枚，最多 80 枚。间隔一天少一档，已存贝壳一直保留。").font(.footnote)
                ForEach(model.bay.payments.reversed(), id: \.day) { payment in
                    HStack {
                        VStack(alignment: .leading) { Text(model.bay.days[payment.day] ?? "旅途"); Text(payment.day).font(.caption).foregroundStyle(.secondary) }
                        Spacer()
                        Text("+\(payment.amount)").monospacedDigit().foregroundStyle(BayInk.coral)
                    }
                }
            }
        }
    }
    private var travel: some View {
        List {
            Section {
                Text("加入同一个小队后，可以一起点亮这三盏灯。每人每天的第一次进步都能接上一段路。贝壳记在各自的背包里。")
                Text("开启后会把昵称、精灵和完成日期同步到小队旅程。睡眠、步数和具体习惯留在自己的手记里。").font(.footnote)
                if model.demo { Text("演示使用本机示例。").foregroundStyle(.secondary) }
                else if model.state.squadCode.isEmpty {
                    Button("去广场创建或加入小队") { sheet = nil; tab = .square }
                } else {
                    Button(relay ? "回到单人旅程" : "开启小队接力") { Task { await model.setBayRelay(!relay) } }
                }
            }
            if relay {
                Section("这一程的同行者") {
                    ForEach(Array(model.bay.relaySteps.enumerated()), id: \.element.key) { i, step in
                        Label(step.name + " · " + names[i], systemImage: "flag.fill")
                    }
                }
            }
        }
    }
    @MainActor private func makeCard() {
        let card = VStack(alignment: .leading, spacing: 0) {
            BayScene(stop: 3, kind: actor, together: second)
            VStack(alignment: .leading, spacing: 9) {
                Text("深圳湾").font(.largeTitle.bold())
                Text(relay ? model.bay.relaySteps.map(\.name).reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }.joined(separator: "、") + " · 一起点亮海堤" : model.state.petName + " · 海堤漫步纪念")
                    .font(.subheadline)
            }.padding(20)
        }.frame(width: 360).background(BayInk.paper).foregroundStyle(BayInk.text)
        let render = ImageRenderer(content: card); render.scale = 3
        cardImage = render.uiImage.map { Image(uiImage: $0) }
    }
}
