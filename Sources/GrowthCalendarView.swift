import SwiftUI

struct GrowthCalendarView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var month = Date()
    @State private var selected = Calendar.current.startOfDay(for: Date())
    private let cal = Calendar.current
    private var monthStart: Date { cal.dateInterval(of: .month, for: month)!.start }
    private var offset: Int { (cal.component(.weekday, from: monthStart) + 5) % 7 }
    private var count: Int { cal.range(of: .day, in: .month, for: month)!.count }
    private func record(_ date: Date) -> DailyProgress? {
        model.ledger.first { $0.id == Growth.dayID(date) }
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    HStack {
                        Button { move(-1) } label: { Image(systemName: "chevron.left") }
                            .accessibilityLabel("上个月")
                        Spacer()
                        Text(month.formatted(.dateTime.year().month())).font(.headline)
                        Spacer()
                        Button { move(1) } label: { Image(systemName: "chevron.right") }
                            .disabled(cal.isDate(month, equalTo: Date(), toGranularity: .month))
                            .accessibilityLabel("下个月")
                    }
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 12) {
                        ForEach(["一", "二", "三", "四", "五", "六", "日"], id: \.self) { Text($0).font(.caption).foregroundStyle(.secondary) }
                        ForEach(0..<(offset + count), id: \.self) { index in
                            if index < offset { Color.clear.frame(height: 46) }
                            else {
                                let date = cal.date(byAdding: .day, value: index - offset, to: monthStart)!
                                let points = record(date)?.points ?? 0
                                Button { selected = date } label: {
                                    VStack(spacing: 4) {
                                        Text("\(index - offset + 1)").font(.subheadline)
                                        Circle().fill(points > 0 ? Palette.green : Color.gray.opacity(0.2)).frame(width: 5, height: 5)
                                    }.frame(maxWidth: .infinity).frame(height: 46)
                                        .background(cal.isDate(date, inSameDayAs: selected) ? Palette.lime : Color.clear, in: RoundedRectangle(cornerRadius: 12))
                                }.buttonStyle(.plain).disabled(date > Date())
                                    .accessibilityLabel("\(date.formatted(date: .abbreviated, time: .omitted))，\(points)能量")
                            }
                        }
                    }
                    VStack(alignment: .leading, spacing: 16) {
                        Text(selected.formatted(date: .complete, time: .omitted)).font(.headline)
                        if let day = record(selected) {
                            LabeledContent("睡眠", value: "\(day.sleepHours.formatted(.number.precision(.fractionLength(1)))) / \(day.sleepGoal.formatted()) 小时")
                            LabeledContent("锻炼", value: "\(day.workoutMinutes.formatted(.number.precision(.fractionLength(0)))) / \(day.workoutGoal.formatted()) 分钟")
                            LabeledContent("步行", value: "\(day.steps ?? 0) 步 · +\(day.walkingXP) 经验")
                            Label("已自动获得 \(day.points) 能量", systemImage: "sparkles").foregroundStyle(Palette.green)
                            if day.points == 0 { Text("暂未记录到达标数据，不代表没有努力。晚到的数据会自动补算。").font(.caption).foregroundStyle(.secondary) }
                        } else {
                            Text("这一天还没有同步记录。无需补打卡，连接 Apple 健康后会自动读取领养以来的数据。").foregroundStyle(.secondary)
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading).softPanel()
                    if model.demo { Text("当前展示演示数据").font(.caption).foregroundStyle(.secondary) }
                }.padding(20)
            }.background(Palette.background)
                .navigationTitle("成长日历").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
        }
    }
    private func move(_ direction: Int) {
        month = cal.date(byAdding: .month, value: direction, to: monthStart)!
        selected = monthStart
    }
}

struct GrowthShareView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var image: Image?
    private var card: some View {
        VStack(spacing: 18) {
            Text("栖灵 · 每一点坚持，都看得见").font(.subheadline).foregroundStyle(Palette.green)
            Image("PetStage\(model.stage)").resizable().scaledToFit().frame(height: 240)
            Text(model.state.petName).font(.largeTitle.bold())
            Text("Lv.\(1 + model.xp / 100) · \(Growth.stageName(model.xp))").font(.title3)
            Text("本周积累 \(model.weekPoints) 能量").font(.headline).foregroundStyle(Palette.green)
            Text("一起养成好习惯，一起长大").foregroundStyle(.secondary)
            if model.demo { Text("演示数据").font(.caption).foregroundStyle(.secondary) }
        }.padding(28).frame(width: 340).background(Palette.background)
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if let image {
                        image.resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: 24))
                        ShareLink(item: image, preview: SharePreview("我的栖灵伙伴", image: image)) {
                            Label("分享成长卡片", systemImage: "square.and.arrow.up")
                        }.buttonStyle(.borderedProminent)
                    } else { ProgressView("正在生成卡片") }
                    Text("卡片包含伙伴名字、等级与周积分，不包含睡眠和运动明细。").font(.caption).foregroundStyle(.secondary)
                }.padding(20)
            }.navigationTitle("晒晒我的伙伴").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
                .task {
                    let renderer = ImageRenderer(content: card.environment(\.colorScheme, .light))
                    renderer.scale = 3
                    if let uiImage = renderer.uiImage { image = Image(uiImage: uiImage) }
                }
        }
    }
}
