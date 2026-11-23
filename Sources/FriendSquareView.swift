import SwiftUI

struct FriendSquareView: View {
    @EnvironmentObject private var model: AppModel
    @Binding var tab: AppTab
    @State private var section = 0
    @State private var invitation = ""
    @State private var search = ""
    @State private var searching = false
    @State private var inviting = false
    @State private var detail: DetailContent?
    @State private var joining = false
    @State private var joinAfterDismiss = false
    @FocusState private var invitationFocused: Bool
    private var filtered: [SquadMember] {
        model.members.filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) }
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 13) {
                    FieldCover(art: "BayLoft", title: "小队邮局", caption: "深圳 · 华侨城创意园", height: 194) { EmptyView() }
                    HStack(spacing: 10) {
                        Button { inviting = true } label: {
                            Label(model.demo || !model.state.squadCode.isEmpty ? "小队邀请" : "创建小队", systemImage: "envelope.fill")
                                .frame(maxWidth: .infinity)
                        }.buttonStyle(BayKey(primary: true))
                        if !model.demo {
                            Button { joining = true } label: { Label("加入小队", systemImage: "ticket").frame(maxWidth: .infinity) }
                                .buttonStyle(BayKey())
                        } else {
                            Button("体验接力") { model.switchDemoRelay(true); tab = .journey }.buttonStyle(BayKey())
                        }
                    }
                    NavigationLink { CampusMapView() } label: {
                        HStack { Image(systemName: "map"); Text("深大领地"); Spacer(); Text("今日地图 ↗") }
                            .frame(maxWidth: .infinity)
                    }.buttonStyle(BayKey())
                    if !model.state.squadCode.isEmpty || model.demo { ExpeditionView() }
                    if !model.demo && !model.state.squadCode.isEmpty {
                        Button {
                            Task { await model.setBayRelay(true); tab = .journey }
                        } label: { Label("与小队接力走深圳", systemImage: "figure.walk").frame(maxWidth: .infinity) }
                            .buttonStyle(BayKey())
                    }
                    HStack {
                        SectionHeading(title: "小队来信")
                        RoundAction(symbol: "magnifyingglass", label: "搜索小队成员") { searching = true }
                    }
                    HStack {
                        ForEach(0..<2, id: \.self) { index in
                            Button { section = index } label: { Text(index == 0 ? "近况" : "本周榜").frame(maxWidth: .infinity) }
                                .buttonStyle(BayKey(primary: section == index)).accessibilityAddTraits(section == index ? .isSelected : [])
                        }
                    }
                    if model.demo {
                        Text("演示小队 · 成绩与互动均为示例").font(.system(size: 10)).foregroundStyle(.secondary)
                    }
                    if model.state.squadCode.isEmpty && !model.demo {
                        Text("建一支小队或输入好友的邀请码，这里就会收到同行伙伴的近况。")
                            .font(.subheadline).frame(maxWidth: .infinity, alignment: .leading).softPanel()
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
                                    PetView(stage: Growth.stage(member.xp), xp: member.xp).frame(width: 54, height: 58)
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
            .sheet(isPresented: $joining) {
                NavigationStack {
                    Form {
                        Section("好友的小队邀请码") {
                            TextField("输入 10 位邀请码", text: $invitation)
                                .textInputAutocapitalization(.characters).autocorrectionDisabled()
                                .focused($invitationFocused).submitLabel(.go)
                                .onSubmit { joinSquad() }
                        }
                        Section {
                            TextField("你的昵称", text: $model.state.name)
                            Toggle("共享昵称、精灵经验和本周积分", isOn: $model.state.sharing)
                            Text("不上传原始健康记录。小队使用 iCloud 公共摘要，邀请码不提供成员级隐私隔离。")
                                .font(.caption).foregroundStyle(.secondary)
                            if !model.state.squadCode.isEmpty {
                                Text("加入后将切换到好友的小队，个人成长记录会保留。")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .scrollContentBackground(.hidden).background(BayUI.paper)
                    .safeAreaInset(edge: .bottom) {
                        VStack(spacing: 8) {
                            if !model.state.sharing { Text("请先开启上方共享开关").font(.caption) }
                            Button(action: joinSquad) {
                                Text(model.socialBusy ? "正在加入…" : "加入好友小队")
                                    .frame(maxWidth: .infinity).padding(.vertical, 8)
                            }.buttonStyle(BayKey(primary: true))
                                .disabled(!model.state.sharing || invitation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.socialBusy)
                        }.padding().background(BayUI.paper)
                    }
                    .navigationTitle("加入好友小队").navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .cancellationAction) {
                        Button("关闭") { joining = false }
                    } }
                    .alert("小队连接", isPresented: Binding(get: { model.message != nil }, set: { if !$0 { model.message = nil } })) {
                        Button("知道了") { model.message = nil }
                    } message: { Text(model.message ?? "") }
                }.presentationDetents([.large])
            }
            .sheet(item: $detail) { DetailSheet(content: $0) }
            .sheet(isPresented: $inviting, onDismiss: {
                if joinAfterDismiss { joinAfterDismiss = false; joining = true }
            }) {
                NavigationStack {
                    ScrollView { joinPanel.padding(20) }.background(BayUI.paper)
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

    private func joinSquad() {
        guard model.state.sharing, !model.socialBusy else { return }
        invitationFocused = false
        Task {
            await model.connectSquad(code: invitation)
            if model.state.squadCode == invitation.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(), model.message == nil {
                joining = false
            }
        }
    }

    private func rank(_ member: SquadMember) -> Int { 1 + model.members.filter { $0.points > member.points }.count }

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
                }.buttonStyle(BayKey(primary: true))
            } else {
                Text("邀请熟悉的人，一起坚持").font(.headline)
                TextField("你的昵称", text: $model.state.name).textFieldStyle(.roundedBorder)
                    .onChange(of: model.state.name) { _, _ in model.save() }
                Toggle("共享昵称、精灵经验和本周积分", isOn: $model.state.sharing)
                    .font(.subheadline).onChange(of: model.state.sharing) { _, _ in model.save() }
                Text("邀请测试版使用 iCloud 公共摘要。邀请码不提供成员级隐私隔离，不上传原始健康记录。")
                    .font(.caption).foregroundStyle(.secondary)
                if !model.state.sharing { Text("开启上方共享开关后，即可创建或加入小队。").font(.caption).foregroundStyle(.secondary) }
                Button("创建我的小队") { Task { await model.connectSquad(code: nil) } }
                    .buttonStyle(BayKey(primary: true)).disabled(!model.state.sharing || model.socialBusy)
                Divider()
                Button("输入邀请码，加入好友小队") {
                    if inviting { joinAfterDismiss = true; inviting = false }
                    else { joining = true }
                }
                    .buttonStyle(BayKey(primary: true))
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
            BayPostmarkEdge()
            HStack {
                Button { Task { await model.cheer(member) } } label: {
                    Label("\(member.cheers)", systemImage: "heart.fill").foregroundStyle(.pink)
                }.accessibilityLabel("鼓励\(member.name)，已有\(member.cheers)次鼓励")
                Spacer()

                Spacer()
                ShareLink(item: "\(member.name)的精灵已经 Lv.\(1 + member.xp / 100)，本周积累 \(member.points) 能量。来栖灵一起长大！") {
                    Image(systemName: "square.and.arrow.up").foregroundStyle(.secondary)
                }.accessibilityLabel("分享成长摘要")
            }.font(.system(size: 13))
        }.softPanel()
    }
}
