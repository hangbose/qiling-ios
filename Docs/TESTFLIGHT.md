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

## 当前待办

- 云端编译和 XCTest 通过。
- 正式 App Icon、Bundle ID、签名与 provisioning profile。
- 真机验证健康授权、睡眠/运动读取、延迟补同步。
- 两个真实 iCloud 用户验证小队创建、加入和每周鼓励。
- 外部 TestFlight 测试需要提交 Beta App Review；通过后再邀请朋友。

## 官方入口

- https://developer.apple.com/programs/enroll/
- https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/
- https://docs.codemagic.io/yaml-code-signing/signing-ios/
- https://docs.codemagic.io/yaml-publishing/app-store-connect/
