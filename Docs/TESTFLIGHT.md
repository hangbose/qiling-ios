# 无 Mac 的 TestFlight 发布路线

## 已准备的云端检查

GitHub Actions 的 `iPhone build and tests` 在云端 macOS 上生成 Xcode 工程、编译原生 App、运行 XCTest，并保存构建日志、测试结果和模拟器截图。这一步不使用 Apple 密钥，也不会上传到 TestFlight。

## 签名发布前需要本人完成

1. 开通 Apple Developer Program，并完成 Apple 要求的身份验证和协议。
2. 在开发者后台注册正式 Bundle ID；当前 `com.example.Qiling` 只是编译占位值，不能直接当作发布配置。
3. 为正式 App ID 开通 HealthKit 和 iCloud / CloudKit，创建对应容器；配置项目 README 中列出的 CloudKit 类型、索引和权限。
4. 在 App Store Connect 创建 App 记录，填写测试说明、反馈邮箱与审核联系方式。
5. 为云端签名服务单独创建 App Store Connect API 密钥，将密钥存入服务的凭据管理界面，不发到聊天、不提交 Git。

可使用 Codemagic 的托管 macOS 构建与签名，在不拥有 Mac 的情况下生成已签名 IPA 并上传 App Store Connect。账号未开通、容器未配置、原生测试未通过前，不宣称已发布。

## 已提供的 Codemagic 发布配置

仓库根目录的 `codemagic.yaml` 提供手动启动的 `qiling-testflight` 流程。它只向 TestFlight 提交，不提交正式 App Store 审核。没有自动触发器，连接服务后需手动运行。

1. 用你的 GitHub 登录 Codemagic，仅授权私有仓库 `hangbose/qiling-ios`。授权和协议由本人确认。
2. 注册正式 App ID。配置中的候选值为 `com.hangbose.qiling`，尚未向 Apple 注册；若不可用，修改 YAML 内两个 Bundle ID 值。
3. 注册对应的 `iCloud.<正式 Bundle ID>` 容器，并为 App ID 启用 HealthKit（含后台交付）与 iCloud / CloudKit；按 README 配置数据库。
4. 在 Codemagic Team integrations 添加 Apple API key，命名为 `qiling-appstore`。将 .p8 直接上传到服务，不提交到仓库或聊天。
5. 在 Code signing identities 生成或上传 Apple Distribution 证书，并获取匹配此 Bundle ID、包含健康与 iCloud capabilities 的 App Store provisioning profile。
6. 已根据会员页面配置 `APPLE_TEAM_ID=2ZPUD5H6P8`。Team ID 不是密码；签名私钥仍只保存在云端凭据管理中。
7. 在 App Store Connect 创建相同 Bundle ID 的 App 记录，完成 Beta 测试信息；手动启动 Codemagic 的 `qiling-testflight`。
8. 上传成功后还需等待 Apple 处理；外部好友测试需通过 Beta App Review，再创建邀请链接。

`Scripts/configure-release.py` 只在云端工作副本里应用正式标识和构建号，不改动本地日常编译占位配置。签名证书与 API 密钥留在服务的凭据管理中。

## 建议的首次测试说明

名称：栖灵

功能：通过 Apple 健康读取睡眠与锻炼记录，自动为一只精灵结算成长。用户主动开启共享后，可在 iCloud 小队展示昵称、成长经验与周积分，并互相鼓励。

测试重点：首次授权与拒绝授权、真实 Apple Watch 记录同步、重复读取不重复加分、长时间未打开后补算、两个真实 iCloud 账号加入同一小队。另有明确标识的本地演示模式。

反馈邮箱和审核联系信息请填写自己的真实信息。隐私政策须覆盖实际数据处理和 CloudKit 公开摘要；目前还没有正式发布的隐私政策 URL。

## 当前待办

- 已完成：云端编译和 10 项 XCTest 通过。
- 正式 App Icon、Bundle ID、签名与 provisioning profile。
- 真机验证健康授权、睡眠/运动读取、延迟补同步。
- 两个真实 iCloud 用户验证小队创建、加入和每周鼓励。
- 外部 TestFlight 测试需要提交 Beta App Review；通过后再邀请朋友。

## 官方入口

- https://developer.apple.com/programs/enroll/
- https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/
- https://docs.codemagic.io/yaml-code-signing/signing-ios/
- https://docs.codemagic.io/yaml-publishing/app-store-connect/
