import SwiftUI

struct FriendSquareView: View {
    @EnvironmentObject private var model: AppModel
    @State private var section = 0
    @State private var invitation = ""
    @State private var search = ""
    @State private var searching = false
    @State private var inviting = false
    @State private var detail: DetailContent?
    private var filtered: [SquadMember] {
        model.members.filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) }
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 13) {
                    ScreenTitle(title: "好友广场") {
                        HStack(spacing: 9) {
                            RoundAction(symbol: "magnifyingglass", label: "搜索小队成员") { searching = true }
                            RoundAction(symbol: "person.badge.plus", label: "邀请好友") { inviting = true }
                        }
                    }.padding(.top, 18).padding(.horizontal, 7)
                    Picker("广场内容", selection: $section) {
                        Text("动态").tag(0)
                        Text("本周榜").tag(1)
                    }.pickerStyle(.segmented).padding(.horizontal, 26)

                    if !model.members.isEmpty { podium }

                    if model.demo {
                        Text("演示小队 · 成绩与互动均为示例").font(.system(size: 10)).foregroundStyle(.secondary)
                    }
                    if model.state.squadCode.isEmpty && !model.demo {
                        joinPanel
                    } else if filtered.isEmpty {
                        ContentUnavailableView(search.isEmpty ? "等待伙伴加入" : "没有找到伙伴",
                            systemImage: "person.2", description: Text(search.isEmpty ? "下拉同步或邀请朋友，一起开始本周挑战。" : "试试其他昵称。"))
                    } else if section == 0 {
                        ForEach(filtered) { member in summaryCard(member) }
                        Text("依据已共享的经验与周积分生成成长摘要，不公开原始健康明细。")
                            .font(.system(size: 10)).foregroundStyle(.secondary).padding(.horizontal, 6)
                    } else {
                        VStack(spacing: 12) {
                            SectionHeading(title: "本周同行榜")
                            ForEach(filtered) { member in
                                HStack(spacing: 10) {
                                    Text(String(format: "%02d", rank(member)))
                                        .font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                                    PetView(stage: Growth.stage(member.xp)).frame(width: 54, height: 58)
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(member.name).font(.system(size: 14, weight: .semibold))
                                        Text(Growth.stageName(member.xp)).font(.system(size: 10)).foregroundStyle(.secondary)
                                    }
                                    Spacer(minLength: 0)
                                    Text("\(member.points) 分").font(.system(size: 16, weight: .semibold)).foregroundStyle(Palette.green)
                                    Button { Task { await model.cheer(member) } } label: {
                                        Image(systemName: "hands.clap").font(.system(size: 15))
                                    }.accessibilityLabel("鼓励\(member.name)")
                                }
                            }
                        }.softPanel()
                    }
                    if !model.state.squadCode.isEmpty && !model.demo {
                        HStack {
                            Text("小队 · \(model.state.squadCode)").font(.caption.monospaced())
                            Spacer()
                            ShareLink(item: "来栖灵一起养精灵吧！在好友广场输入小队邀请码：\(model.state.squadCode)") {
                                Label("邀请好友", systemImage: "person.badge.plus").font(.caption)
                            }
                        }.padding(12).background(Palette.lime.opacity(0.15), in: RoundedRectangle(cornerRadius: 14))
                    }
                }.padding(.horizontal, 17).padding(.bottom, 20)
            }
            .background(Palette.background).toolbar(.hidden, for: .navigationBar)
            .task { await model.refreshSquad() }
            .refreshable { await model.sync(); await model.refreshSquad() }
            .sheet(item: $detail) { DetailSheet(content: $0) }
            .sheet(isPresented: $inviting) {
                NavigationStack {
                    ScrollView { joinPanel.padding(24) }
                        .navigationTitle("邀请朋友一起长大").navigationBarTitleDisplayMode(.inline)
                        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { inviting = false } } }
                }.presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
            }
            .alert("搜索小队成员", isPresented: $searching) {
                TextField("输入昵称", text: $search)
                Button("查看") { section = 1 }
                Button("清除筛选") { search = "" }
                Button("取消", role: .cancel) { }
            }
        }
    }

    private func rank(_ member: SquadMember) -> Int { 1 + model.members.filter { $0.points > member.points }.count }

    private var podium: some View {
        let first = Array(model.members.prefix(3))
        let ordered = first.count > 1 ? [first[1], first[0]] + Array(first.dropFirst(2)) : first
        return HStack(alignment: .bottom, spacing: 0) {
            ForEach(ordered) { member in
                let winner = member.id == first.first?.id
                VStack(spacing: 2) {
                    Text(winner ? "👑" : (rank(member) == 2 ? "🥈" : "🥉")).font(.system(size: winner ? 30 : 23))
                    PetView(stage: Growth.stage(member.xp)).frame(height: winner ? 158 : 115)
                    VStack(spacing: 4) {
                        Text(member.name).font(.system(size: 12, weight: .medium)).lineLimit(1)
                        Text("Lv.\(1 + member.xp / 100)").font(.system(size: 11)).foregroundStyle(Palette.green)
                    }.frame(maxWidth: .infinity).padding(.vertical, 7)
                        .background(.thinMaterial, in: Capsule())
                }.frame(maxWidth: .infinity)
            }
        }
        .padding(10).frame(height: 255, alignment: .bottom)
        .background { RoomBackdrop().overlay(.white.opacity(0.40)) }
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    private var joinPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            if model.demo {
                Text("当前是演示小队").font(.headline)
                Text("在“我的”退出演示并连接真实 iCloud 小队后，就能分享邀请码给朋友。")
                    .font(.subheadline).foregroundStyle(.secondary)
            } else if !model.state.squadCode.isEmpty {
                Text("一起养成好习惯").font(.headline)
                Text("邀请码：\(model.state.squadCode)").font(.title3.monospaced())
                ShareLink(item: "来栖灵一起养精灵吧！小队邀请码：\(model.state.squadCode)") {
                    Label("分享邀请码", systemImage: "square.and.arrow.up")
                }.buttonStyle(.borderedProminent)
            } else {
                Text("邀请熟悉的人，一起坚持").font(.headline)
                TextField("你的昵称", text: $model.state.name).textFieldStyle(.roundedBorder)
                    .onChange(of: model.state.name) { _, _ in model.save() }
                Toggle("共享昵称、精灵经验和本周积分", isOn: $model.state.sharing)
                    .font(.subheadline).onChange(of: model.state.sharing) { _, _ in model.save() }
                Text("邀请测试版使用 iCloud 公共摘要。邀请码不提供成员级隐私隔离，不上传原始健康记录。")
                    .font(.caption).foregroundStyle(.secondary)
                Button("创建我的小队") { Task { await model.connectSquad(code: nil) } }
                    .buttonStyle(.borderedProminent).disabled(!model.state.sharing || model.socialBusy)
                Divider()
                TextField("输入 10 位邀请码", text: $invitation).textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.characters).autocorrectionDisabled()
                Button("加入好友小队") { Task { await model.connectSquad(code: invitation) } }
                    .disabled(!model.state.sharing || invitation.isEmpty || model.socialBusy)
                if model.socialBusy { ProgressView("正在连接 iCloud…") }
            }
        }.softPanel()
    }

    private func summaryCard(_ member: SquadMember) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 10) {
                Text(String(member.name.prefix(1))).font(.system(size: 14, weight: .semibold))
                    .frame(width: 38, height: 38).background(Palette.lime.opacity(0.35), in: Circle())
                VStack(alignment: .leading, spacing: 4) {
                    Text(member.name).font(.system(size: 15, weight: .semibold))
                    Text(model.demo ? "示例成长摘要" : member.updated.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 10)).foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    detail = DetailContent(title: "成长摘要", text: "根据伙伴主动共享的等级和周积分展示。不公开睡眠时间等健康明细。每位朋友每周可鼓励一次。")
                } label: { Image(systemName: "ellipsis").foregroundStyle(.secondary) }.accessibilityLabel("成长摘要说明")
            }
            Text("本周积累了 \(member.points) 能量，伙伴又成长了一点！🌱").font(.system(size: 14))
            Text("\(Growth.stageName(member.xp)) · Lv.\(1 + member.xp / 100)")
                .font(.system(size: 12)).foregroundStyle(.secondary)
            ZStack(alignment: .bottom) {
                RoomBackdrop().overlay(.white.opacity(0.30))
                PetView(stage: Growth.stage(member.xp)).frame(height: 165)
            }.frame(height: 175).clipShape(RoundedRectangle(cornerRadius: 17))
            HStack {
                Button { Task { await model.cheer(member) } } label: {
                    Label("\(member.cheers)", systemImage: "heart.fill").foregroundStyle(.pink)
                }.accessibilityLabel("鼓励\(member.name)，已有\(member.cheers)次鼓励")
                Spacer()
                Text("一起坚持，一起长大").font(.system(size: 11)).foregroundStyle(.secondary)
                Spacer()
                ShareLink(item: "\(member.name)的精灵已经 Lv.\(1 + member.xp / 100)，本周积累 \(member.points) 能量。来栖灵一起长大！") {
                    Image(systemName: "square.and.arrow.up").foregroundStyle(.secondary)
                }.accessibilityLabel("分享成长摘要")
            }.font(.system(size: 13))
        }.softPanel()
    }
}
