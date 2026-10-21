import SwiftUI

struct GrowthRecordView: View {
    @EnvironmentObject private var model: AppModel
    @State private var detail: DetailContent?
    @State private var selectedStage: Int?
    private var summary: GrowthSummary {
        GrowthSummary(days: model.ledger, now: Date(), started: model.demo ? nil : model.state.started)
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    ScreenTitle(title: "成长记录") {
                        RoundAction(symbol: "calendar", label: "查看成长日历") { showHistory() }
                    }.padding(.horizontal, 7).padding(.top, 18)

                    HStack(spacing: 0) {
                        PetView(stage: model.stage).frame(maxWidth: .infinity).frame(height: 185)
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .firstTextBaseline, spacing: 3) {
                                Text("陪伴的第").font(.system(size: 15, weight: .semibold))
                                Text("\(summary.companionDays)").font(.system(size: 29, weight: .bold))
                                Text("天").font(.system(size: 15, weight: .semibold))
                            }.minimumScaleFactor(0.7).lineLimit(1)
                            Text("好的习惯\n让我们一起成长 ✨").font(.system(size: 12)).foregroundStyle(.secondary).lineSpacing(8)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .background { RoomBackdrop().overlay(.white.opacity(0.68)) }
                    .clipShape(RoundedRectangle(cornerRadius: 24))

                    VStack(spacing: 15) {
                        SectionHeading(title: "进化历程", actionTitle: "成长规则") {
                            detail = DetailContent(title: "成长规则", text: "睡眠和运动每项达标获得 50 能量，每日最多 100。\n\n1000 经验进入逐光成长体，3000 经验进入月辉守护体。长期成长保留，周赛每周一重置。\n\n不用手动打卡或领取奖励，晚到的数据自动补算。")
                        }
                        HStack(spacing: 4) {
                            ForEach(0..<3) { stage in
                                Button { selectedStage = stage } label: {
                                    VStack(spacing: 4) {
                                        Text(["初生", "成长", "进化"][stage]).font(.system(size: 11, weight: stage == model.stage ? .semibold : .regular))
                                        PetView(stage: stage).frame(height: 83)
                                            .grayscale(stage > model.stage ? 1 : 0).opacity(stage > model.stage ? 0.25 : 1)
                                        Text(["Lv.1", "1000 XP", "3000 XP"][stage]).font(.system(size: 10))
                                    }
                                    .frame(maxWidth: .infinity).padding(.vertical, 8)
                                    .foregroundStyle(stage == model.stage ? Palette.green : .secondary)
                                    .background(stage == model.stage ? Palette.lime.opacity(0.22) : .clear,
                                                in: RoundedRectangle(cornerRadius: 15))
                                }.buttonStyle(.plain).accessibilityLabel("查看\(["星芽幼体", "逐光成长体", "月辉守护体"][stage])")
                                if stage < 2 { Image(systemName: "chevron.right").font(.system(size: 10)).foregroundStyle(.tertiary) }
                            }
                        }
                        Text("当前 \(model.xp) 经验 · 距离下一里程碑 \(Growth.nextMilestone(model.xp) - model.xp)")
                            .font(.system(size: 10)).foregroundStyle(.secondary)
                    }.softPanel()

                    VStack(spacing: 14) {
                        SectionHeading(title: "本周成长", actionTitle: "查看记录") { showHistory() }
                        HStack {
                            Text("本周已获得 \(model.weekPoints) 能量").foregroundStyle(.secondary)
                            Spacer()
                            Text("每日上限 100").foregroundStyle(Palette.green)
                        }.font(.system(size: 10))
                        HStack(alignment: .bottom, spacing: 14) {
                            ForEach(Array(summary.week.enumerated()), id: \.offset) { index, day in
                                VStack(spacing: 8) {
                                    Spacer(minLength: 0)
                                    RoundedRectangle(cornerRadius: 5)
                                        .fill(LinearGradient(colors: [Palette.green.opacity(0.58), Palette.lime], startPoint: .top, endPoint: .bottom))
                                        .frame(width: 16, height: max(2, CGFloat(day.points) * 0.72))
                                    Text("周\(["一", "二", "三", "四", "五", "六", "日"][index])")
                                        .font(.system(size: 9)).foregroundStyle(.secondary)
                                }.frame(maxWidth: .infinity)
                                    .accessibilityElement(children: .ignore)
                                    .accessibilityLabel("\(day.date.formatted(date: .abbreviated, time: .omitted))，\(day.points)能量")
                            }
                        }.frame(height: 100)
                    }.softPanel()

                    VStack(spacing: 14) {
                        SectionHeading(title: "我的成就", actionTitle: "查看全部") {
                            detail = DetailContent(title: "我的成就", text: "睡眠达人：累计 7 天完成自己的睡眠时长目标，当前 \(summary.sleepDays) 天。\n\n运动搭子：累计 30 天完成自己的运动目标，当前 \(summary.workoutDays) 天。\n\n成就按记录计算，不要求额外打卡。")
                        }
                        HStack(spacing: 9) {
                            achievement("睡眠达人", symbol: "moon.fill", color: .purple, count: summary.sleepDays, target: 7)
                            achievement("运动搭子", symbol: "figure.run", color: .orange, count: summary.workoutDays, target: 30)
                        }
                    }.softPanel()
                    if model.demo { Text("演示记录 · 真实成长由健康数据自动计算").font(.system(size: 10)).foregroundStyle(.secondary) }
                }.padding(.horizontal, 17).padding(.bottom, 20)
            }
            .background(Palette.background).toolbar(.hidden, for: .navigationBar)
            .sheet(item: $detail) { DetailSheet(content: $0) }
            .sheet(isPresented: Binding(get: { selectedStage != nil }, set: { if !$0 { selectedStage = nil } })) {
                if let stage = selectedStage {
                    VStack(spacing: 18) {
                        Text(["星芽幼体", "逐光成长体", "月辉守护体"][stage]).font(.title2.bold())
                        PetView(stage: stage).frame(height: 240)
                        Text(stage <= model.stage ? "已经解锁，一起继续成长。" : "达到 \(stage == 1 ? 1000 : 3000) 成长经验后解锁。")
                            .font(.subheadline).foregroundStyle(.secondary)
                        Button("完成") { selectedStage = nil }
                    }.padding(24).presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
                }
            }
        }
    }
    private func achievement(_ title: String, symbol: String, color: Color, count: Int, target: Int) -> some View {
        Button {
            detail = DetailContent(title: title, text: "累计 \(target) 天完成目标即可点亮。当前 \(count) / \(target) 天。\n\n\(model.demo ? "当前为演示数据。" : "根据已同步的健康目标记录计算。")")
        } label: {
            HStack(spacing: 8) {
                Image(systemName: symbol).font(.system(size: 21, weight: .semibold)).foregroundStyle(.white)
                    .frame(width: 41, height: 41)
                    .background(LinearGradient(colors: [color.opacity(0.45), color.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing), in: Circle())
                    .overlay(Circle().stroke(color.opacity(0.25), lineWidth: 3))
                VStack(alignment: .leading, spacing: 5) {
                    Text(title).font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.ink)
                    Text(count >= target ? "已点亮" : "\(count) / \(target) 天").font(.system(size: 10)).foregroundStyle(.secondary)
                }
            }.frame(maxWidth: .infinity, alignment: .leading).padding(8)
                .background(.white, in: RoundedRectangle(cornerRadius: 16)).opacity(count >= target ? 1 : 0.55)
        }.buttonStyle(.plain)
    }
    private func showHistory() {
        let entries = model.ledger.prefix(30).map { day in
            "\(day.date.formatted(date: .abbreviated, time: .omitted))  +\(day.points) 能量"
        }.joined(separator: "\n")
        detail = DetailContent(title: "成长日历", text: entries.isEmpty ? "暂未获取健康记录。连接 Apple 健康后自动同步，无需补打卡。" : entries)
    }
}
