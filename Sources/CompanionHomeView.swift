import SwiftUI

struct CompanionHomeView: View {
    @EnvironmentObject private var model: AppModel
    @Binding var tab: AppTab
    @State private var detail: DetailContent?
    @State private var renaming = false
    @State private var draftName = ""
    private var earned: Int { model.today?.points ?? 0 }
    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        return hour < 12 ? "早上好 ☀️" : (hour < 18 ? "下午好 👋" : "晚上好 👋")
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(greeting).font(.system(size: 15, weight: .semibold))
                                Text("我的伙伴").font(.system(size: 34, weight: .bold)).tracking(-1)
                            }
                            Spacer()
                            RoundAction(symbol: "bell", label: "成长消息", dot: earned > 0) {
                                detail = DetailContent(title: "成长消息", text: earned > 0
                                    ? "今日 \(earned) 能量已自动到账。\n\n\(model.status)"
                                    : "\(model.status)\n\n晚到的数据会自动补算，没有记录不会扣除成长。")
                            }
                            RoundAction(symbol: "plus", label: "查看伙伴档案") { tab = .growth }
                        }.padding(.horizontal, 24).padding(.top, 18)
                        GeometryReader { proxy in
                            let width = proxy.size.width
                            ZStack(alignment: .bottomLeading) {
                                PetView(stage: model.stage)
                                    .frame(width: width * 0.69, height: 290).offset(x: -6, y: -6)
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(spacing: 6) {
                                        Text(model.state.petName).font(.system(size: 25, weight: .bold)).lineLimit(1)
                                        Button { draftName = model.state.petName; renaming = true } label: {
                                            Image(systemName: "square.and.pencil").font(.system(size: 13)).foregroundStyle(.secondary)
                                        }.accessibilityLabel("修改伙伴名字")
                                    }
                                    Text("Lv.\(1 + model.xp / 100)").font(.system(size: 24, weight: .semibold))
                                        .foregroundStyle(Palette.green)
                                    ProgressView(value: Double(model.xp), total: Double(Growth.nextMilestone(model.xp)))
                                        .tint(Palette.green)
                                    Text("距离下一次\(model.xp < 3000 ? "进化" : "里程碑")")
                                        .font(.system(size: 11)).foregroundStyle(.secondary)
                                    Text("\(Growth.nextMilestone(model.xp) - model.xp) 能量").font(.system(size: 14, weight: .medium))
                                }
                                .frame(width: width * 0.30, alignment: .leading)
                                .position(x: width * 0.80, y: 112)
                                Text("✦ \(Growth.stageName(model.xp))\(model.demo ? " · 演示" : "")")
                                    .font(.system(size: 10)).foregroundStyle(Palette.green)
                                    .padding(.horizontal, 11).padding(.vertical, 6)
                                    .background(.regularMaterial, in: Capsule()).padding(.leading, 24).padding(.bottom, 9)
                            }
                        }.frame(height: 330)
                    }
                    .background { RoomBackdrop().overlay(alignment: .bottom) {
                        LinearGradient(colors: [.clear, Palette.background], startPoint: .top, endPoint: .bottom).frame(height: 50)
                    } }

                    VStack(spacing: 13) {
                        HStack(spacing: 12) {
                            HabitTile(symbol: "moon.fill", title: "睡眠", value: model.today?.sleepHours ?? 0,
                                      goal: model.today?.sleepGoal ?? model.state.sleepGoal, unit: "小时", color: .indigo) {
                                showHabit(sleep: true)
                            }
                            HabitTile(symbol: "figure.run", title: "运动", value: model.today?.workoutMinutes ?? 0,
                                      goal: model.today?.workoutGoal ?? model.state.workoutGoal, unit: "分钟", color: Palette.green) {
                                showHabit(sleep: false)
                            }
                        }
                        HStack(spacing: 9) {
                            Image(systemName: earned > 0 ? "checkmark" : "applewatch")
                            Text(earned > 0 ? "今日 \(earned) 能量已自动到账" : "等待手表数据同步")
                        }
                        .font(.system(size: 17, weight: .semibold)).foregroundStyle(Palette.green)
                        .frame(maxWidth: .infinity).padding(.vertical, 16)
                        .background(Palette.lime, in: Capsule())
                        Text("无需打卡，无需领取，成长自然发生。")
                            .font(.system(size: 10)).foregroundStyle(.secondary)
                    }
                    .padding(12).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 27))
                    .padding(.horizontal, 17).padding(.top, -2)

                    HStack {
                        Label(model.demo ? "Apple Watch · 模拟连接" : (model.syncing ? "正在同步…" : model.status), systemImage: "applewatch")
                        Spacer()
                        Button("查看成长") { tab = .growth }
                    }.font(.system(size: 10)).foregroundStyle(.secondary).padding(.horizontal, 24).padding(.vertical, 18)

                    if !model.state.requestedHealth && !model.demo {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("让好习惯，自然变成成长").font(.headline)
                            Text("连接 Apple 健康，睡眠和运动达标后自动获得能量。")
                                .font(.subheadline).foregroundStyle(.secondary)
                            Button { Task { await model.connect() } } label: {
                                Label("连接 Apple 健康", systemImage: "heart.fill").frame(maxWidth: .infinity)
                            }.buttonStyle(.borderedProminent).controlSize(.large)
                            Button("先体验演示") { model.enterDemo() }.frame(maxWidth: .infinity)
                        }.softPanel().padding(.horizontal, 18)
                    }
                }
                .padding(.bottom, 10)
            }
            .background(Palette.background).toolbar(.hidden, for: .navigationBar)
            .refreshable { await model.sync() }
            .sheet(item: $detail) { DetailSheet(content: $0) }
            .alert("给伙伴起个名字", isPresented: $renaming) {
                TextField("伙伴名字", text: $draftName)
                Button("保存") {
                    let name = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !name.isEmpty { model.state.petName = String(name.prefix(12)); model.save() }
                }
                Button("取消", role: .cancel) { }
            }
        }
    }
    private func showHabit(sleep: Bool) {
        let value = sleep ? model.today?.sleepHours ?? 0 : model.today?.workoutMinutes ?? 0
        let unit = sleep ? "小时" : "分钟"
        detail = DetailContent(title: sleep ? "睡眠滋养" : "运动滋养",
            text: "当前记录：\(value.formatted(.number.precision(.fractionLength(1)))) \(unit)\n\n"
                + (sleep ? "只计算实际睡眠时段，清醒与卧床时间不计入。跨夜睡眠归属起床日。" : "读取已记录的锻炼时段，合并重叠记录。")
                + "\n\n每项达标获得 50 能量，每天最多 100。无记录时不能区分未佩戴、权限或同步延迟，不判为失败。"
                + (model.demo ? "\n\n当前为演示数据。" : ""))
    }
}

struct HabitTile: View {
    let symbol: String
    let title: String
    let value: Double
    let goal: Double
    let unit: String
    let color: Color
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 13) {
                HStack(spacing: 7) {
                    Image(systemName: symbol).font(.system(size: 17, weight: .medium))
                        .frame(width: 31, height: 31).background(color.opacity(0.13), in: Circle()).foregroundStyle(color)
                    Text(title).font(.system(size: 14, weight: .semibold))
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").font(.system(size: 11)).foregroundStyle(.secondary)
                }
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(value > 0 ? value.formatted(.number.precision(.fractionLength(0...1))) : "—")
                        .font(.system(size: 36, weight: .semibold)).tracking(-1)
                    Text(unit).font(.system(size: 13, weight: .semibold))
                }
                Text("目标 \(goal.formatted()) \(unit)\(value >= goal ? " ✓" : "")")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }.foregroundStyle(Palette.ink).frame(maxWidth: .infinity, alignment: .leading)
                .padding(13).background(.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 21))
        }.buttonStyle(.plain)
    }
}
