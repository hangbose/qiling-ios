# 栖灵 · iPhone 邀请测试版

一只主宠陪伴成长。Apple 健康自动记录睡眠与锻炼，完成目标自动获得经验，和朋友参加每周小队赛。

## 当前实现

- iOS 17+ SwiftUI 原生界面：伙伴、好友广场、成长记录、我的四页；大幅居家主宠场景、睡眠/运动双卡片、薄荷绿状态和轻玻璃底部导航。
- 原创星光系精灵「星澜」，三个独立立绘阶段、浮动动画、减少动态效果支持。图片由内置 image_gen 生成，提示词见 Art/PROMPTS.md；网页和 iOS 共用透明 PNG。
- HealthKit 只读睡眠和锻炼；观察后台变更，前台自动补读，从领养日起追溯。
- 重叠时间合并、排除明确标记为手动录入的记录、每日双目标各 50 经验、持久化去重账本。
- CloudKit 邀请码创建/加入小队、共享周积分与经验、一人对每位成员每周一次鼓励。
- 独立演示模式，可不授权健康数据浏览；不影响真实账本、不上传模拟成绩。

**本项目在 Windows 编写，未在 Xcode 编译，未完成真机验证。** XCTest 已提供但尚未运行。健康读取与 CloudKit 需要下述配置才能测试；不是可以直接安装的 IPA。

## 先体验交互预览

直接用浏览器打开 `Preview/index.html`，无需安装依赖。页面中的按钮模拟手表同步，仅演示交互，不连接健康或 iCloud。已通过浏览器交互检查：睡眠/运动奖励、重复同步去重、跨日保留成长、目标次日生效、1000 经验进化、小队鼓励防重复。这些检查不能代替原生测试。

## 参考图 UI 改版

按用户提供的三屏图实现布局与视觉层次，保留原创精灵「星澜」。参考图里的“领取能量”改为自动到账状态，不增加日常打卡操作。

- 伙伴：居家场景、大幅宠物、侧边等级、睡眠与运动双卡片，支持详情与改名。
- 广场：三人领奖台、动态/周榜切换。网页演示支持点赞、本地留言、鼓励、昵称搜索、复制分享文案；这些不是已上线的社交后端功能。iPhone 使用现有 CloudKit 成长摘要和每周鼓励，并保留创建/加入小队。
- 成长：进化历程、周一开始的七日成长图表、睡眠/运动成就和历史记录。iPhone 数值来自本地账本；网页使用明确标识的示例记录。
- 我的：档案、目标、健康连接与共享设置。预览仅持久化昵称和目标偏好，不读取健康数据。
- 背景素材使用内置 image_gen 生成，提示词见 Art/ROOM-PROMPT.md。源码中的轻玻璃使用 iOS 17 材质，无第三方 UI 依赖。

预览现在由 `index.html`、`styles.css` 和 `app.js` 组成，目录结构需一起保留。可以运行 `python -m http.server 58322 --bind 127.0.0.1 --directory Preview` 后访问本机预览。

验证：`node --test Tests/preview.test.cjs` 的四项业务回归测试已通过；浏览器检查了四页导航、睡眠详情、点赞、本地留言与周榜切换。新增原生成长汇总 XCTest 尚需在 Mac 运行；没有把网页验证当作原生编译通过。

## 在 Mac 上运行

1. 安装 Xcode 与 XcodeGen（例如通过 Homebrew 安装 `xcodegen`）。
2. 修改 `project.yml` 中的 Bundle ID 和 iCloud 容器 ID 为开发团队可用的标识，两者保持对应。
3. 在项目根目录运行 `xcodegen generate`，打开生成的 `Qiling.xcodeproj`。
4. 在 Signing & Capabilities 选择开发团队，启用 HealthKit（含 Background Delivery）及 iCloud / CloudKit，并关联容器。健康数据仅请求读取。
5. 选 iPhone 真机运行。初次领养默认目标为睡眠 8 小时、锻炼 30 分钟，可在设置中调整，新目标次日生效。
6. 未配置 CloudKit 时仍可单独测试本地健康养成。模拟器可从首页进入演示，也可在 Scheme Launch Arguments 加入 `--demo`。

## CloudKit 开发环境配置

使用 Public Database，创建以下 Record Types。代码中的字段名需一致：

| 类型 | 字段 |
| --- | --- |
| `Squad` | `code: String` |
| `MemberWeek` | `squad: String`, `week: String`, `nickname: String`, `points: Int64`, `xp: Int64`, `updated: Date/Time` |
| `Cheer` | `squad: String`, `week: String`, `target: String` |

为 `MemberWeek` 和 `Cheer` 的 `squad`、`week` 添加 QUERYABLE 索引。权限：Authenticated 可 Create / Read；Creator 可 Write；不要赋予所有已认证用户 Write。先使用开发环境验证，再按需部署 schema 到生产环境。

仅上传昵称、周积分、经验和时间。公开库的代码过滤不是成员级隐私隔离，不上传原始健康数据。当前适用于知情同意的小规模邀请测试；正式发布前应改为有成员鉴权的服务或 CloudKit sharing，并提供删除、退出、举报和反作弊机制。客户端提交积分尚无服务端校验，不适用于奖励有现金价值的赛事。

## 规则与边界

- 每天睡眠达标 +50，锻炼达标 +50；超过目标不额外加分。周一开新周，按设备日历计算周归属。
- 睡眠按前一天 12:00 至当天 12:00 的睡眠时间并集计算。清醒和卧床时间不计入。锻炼按当天时间窗裁剪并合并；首版采用锻炼起止跨度，不扣除训练中暂停时间。
- 读取所有获授权的自动健康记录，不声称所有数据都来自 Apple Watch；排除明确手动标记，仍不构成防作弊保证。
- 初次领养只从当天起计分。以后即使多日没打开也可补算。长时间使用后应以持久化增量游标替代全量回读。
- 同一天用字典键更新，不累加重复奖励。已经计入的健康时长只增不减，源记录删除或读取权限撤销不会扣回经验；这是陪伴养成的明确取舍，比赛严谨审计尚未实现。
- 修改目标次日生效，已有日期保留目标快照。跨时区旅行和手动改系统日期的竞争公平性未做防护。
- HealthKit 完成授权流程不代表用户授予了读取权限；没有返回记录时显示“暂未获取数据”，不谎称授权成功或目标失败。
- 后台通知不保证实时。App 打开时补同步；CloudKit 摘要在进入前台/小队页或下拉刷新时更新，不承诺后台实时更新好友榜。
- 自动共享需主动开启，关闭后停止新上传但不删除历史公开摘要。测试版未提供账号删除或迁移；卸载 App 会丢失本地成长账本。
- 不支持华为接入、宠物对战、付费、推送催打卡。没有以遗漏打卡为由的生病或成长惩罚。

## 测试

Mac 上生成工程后，在 Xcode 执行 Product → Test，或使用可用模拟器：

```sh
xcodebuild -project Qiling.xcodeproj -scheme Qiling -showdestinations
xcodebuild -project Qiling.xcodeproj -scheme Qiling -destination 'platform=iOS Simulator,id=实际模拟器ID' test
```

单元测试：重叠睡眠、跨夜归属、每日封顶、重复回放、空数据、跨午夜锻炼、周一切换、进化边界。

真机验收：

1. 只授权睡眠或拒绝全部读取，页面保持诚实，不出现虚构完成情况。
2. 健康 App 有记录时读取并结算；连续刷新和重启后积分不重复。
3. 后台新增/延迟记录，回到 App 后补齐；锁屏不可读时保留原进度。
4. 演示模式切换期间发起同步，模拟记录不进入真实账本和云端。
5. 两个不同 iCloud 账号创建/加入同一小队；只见摘要，重复鼓励只计一次。
6. 关闭共享后刷新不上传新积分；网络失败显示错误而非虚构榜单。
7. 真机检查大字体、VoiceOver、小屏设备以及减少动态效果。

## 参考

- [HealthKit Observer Queries](https://developer.apple.com/documentation/healthkit/executing-observer-queries)
- [HealthKit Sleep Analysis](https://developer.apple.com/documentation/healthkit/hkcategoryvaluesleepanalysis)
