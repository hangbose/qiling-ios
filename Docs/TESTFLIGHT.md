# 无 Mac 的 TestFlight 发布路线

## 已准备的云端检查

GitHub Actions 的 `iPhone build and tests` 在云端 macOS 上生成 Xcode 工程、编译原生 App、运行 XCTest，并保存构建日志、测试结果和模拟器截图。这一步不使用 Apple 密钥，也不会上传到 TestFlight。

## 首次配置时使用

1. 开通 Apple Developer Program，并完成 Apple 要求的身份验证和协议。
2. 在开发者后台注册正式 Bundle ID；当前 `com.example.Qiling` 只是编译占位值，不能直接当作发布配置。
3. 为正式 App ID 开通 HealthKit 和 iCloud / CloudKit，创建对应容器；配置项目 README 中列出的 CloudKit 类型、索引和权限。
4. 在 App Store Connect 创建 App 记录，填写测试说明、反馈邮箱与审核联系方式。
5. 为云端签名服务单独创建 App Store Connect API 密钥，将密钥存入服务的凭据管理界面，不发到聊天、不提交 Git。

可使用 Codemagic 的托管 macOS 构建与签名，在不拥有 Mac 的情况下生成已签名 IPA 并上传 App Store Connect。账号未开通、容器未配置、原生测试未通过前，不宣称已发布。

## 已提供的 Codemagic 发布配置

日常发布沿用现有配置。在 Codemagic 选择已验证的提交，启动 **Qiling - signed TestFlight build**。流程读取 Apple 的最新构建号、运行模拟器测试、签名、上传，并为已有的「好友体验测试」和「本人真机测试」组处理分发。测试说明来自仓库根目录的 `release_notes.json`。

1. 将 GitHub 仓库 `hangbose/qiling-ios` 连接到 Codemagic。
2. 已注册正式 App ID `com.hangbose.qiling`，对应 App Store Connect App ID `6827530890`；保留现有标识。
3. 注册对应的 `iCloud.<正式 Bundle ID>` 容器，并为 App ID 启用 HealthKit（含后台交付）与 iCloud / CloudKit；按 README 配置数据库。
4. 在 Codemagic Team integrations 添加 Apple API key，命名为 `qiling-appstore`。将 .p8 直接上传到服务，不提交到仓库或聊天。
5. 在 Code signing identities 生成或上传 Apple Distribution 证书，并获取匹配此 Bundle ID、包含健康与 iCloud capabilities 的 App Store provisioning profile。
6. 已根据会员页面配置 `APPLE_TEAM_ID=2ZPUD5H6P8`。Team ID 不是密码；签名私钥仍只保存在云端凭据管理中。
7. 在 App Store Connect 创建相同 Bundle ID 的 App 记录，完成 Beta 测试信息；手动启动 Codemagic 的 `qiling-testflight`。
8. 上传后等待 Apple 处理。运行 **Qiling - TestFlight distribution status** 核对目标构建号、内外部状态和已关联的组。好友组沿用已有邀请链接。

`Scripts/configure-release.py` 只在云端工作副本里应用正式标识和构建号，不改动本地日常编译占位配置。签名证书与 API 密钥留在服务的凭据管理中。

## 建议的首次测试说明

名称：栖灵

功能：通过 Apple 健康读取睡眠与锻炼记录，自动为一只精灵结算成长。用户主动开启共享后，可在 iCloud 小队展示昵称、成长经验与周积分，并互相鼓励。

测试重点：首次授权与拒绝授权、真实 Apple Watch 记录同步、重复读取不重复加分、长时间未打开后补算、两个真实 iCloud 账号加入同一小队。另有明确标识的本地演示模式。

反馈邮箱和审核联系信息请填写自己的真实信息。隐私政策须覆盖实际数据处理和 CloudKit 公开摘要；目前还没有正式发布的隐私政策 URL。

## 当前待办

- 以对应提交的 iPhone 测试日志和对应构建号的 Apple 分发状态为准。
- 真机验证健康授权、睡眠/运动读取、延迟补同步。
- 两个真实 iCloud 用户验证小队创建、加入和每周鼓励。

## 官方入口

- https://developer.apple.com/programs/enroll/
- https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/
- https://docs.codemagic.io/yaml-code-signing/signing-ios/
- https://docs.codemagic.io/yaml-publishing/app-store-connect/

## 发布检查关卡

Codemagic 在签名归档前执行 XCTest 和模拟器启动，失败即停止后续步骤。测试脚本从编译产物读取 Bundle ID，兼容占位及正式标识。保留测试日志、xcresult 和截图。

Apple 对目标构建返回 `VALID` 表示处理成功。外部状态为 `IN_BETA_TESTING` 且关联「好友体验测试」后，才能确认好友组可测。真机安装和手表数据同步仍需设备验证。

TestFlight 使用 CloudKit Production 环境。须在 CloudKit Console 核对 README 中的三种记录类型、查询索引及权限，并部署 schema；仅创建 iCloud 容器不足以启用社交功能。当前尚未验证生产 schema 和真机社交。

账号出现新版开发者许可协议提示时，先由账户持有人处理协议，再继续发布。协议更新不能通过重复生成签名证书解决。
