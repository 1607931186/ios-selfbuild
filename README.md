# 无 Mac + GitHub Actions 构建 iOS App（B 路线：设备端签名）

一套「只有 GitHub 账号、没有 Mac、没有开发者账号」也能跑通的自用 App 流程。

**设计前提：CI 只产出未签名 IPA。** 签名和安装全部在 iPhone 上用自己的证书完成。
这样证书换了、被苹果吊销了、想临时换成免费 Apple ID 侧载，都不用改仓库里的任何一行。

```
push / 手动触发
      │
      ▼
GitHub Actions · macos-15 runner
      ├─ xcodegen generate        ← 没有 Mac 也能生成 Xcode 工程
      ├─ xcodebuild（关闭签名）    → SelfApp.app
      ├─ 打包 Payload/            → SelfApp-unsigned.ipa
      ├─ artifact 上传 / tag 时发 Release
      └─ 另一个 job：模拟器安装 + 截图（给你看 UI）
      │
      ▼
iPhone Safari 下载 IPA → 轻松签 / AltStore / TrollStore 签名安装 → 信任描述文件
```

---

## 一、一次性准备

1. **建仓库**并推上去。
   - **公开仓库**：macOS runner 完全免费，推荐。
   - **私有仓库**：Free 计划 2000 分钟/月，但 macOS 按 **10 倍**折算 ≈ 200 分钟，够用但省着点。
2. **获取证书**：`.p12`（含私钥，需要密码）+ `.mobileprovision` 描述文件。
   - 企业证书（In-House）通常是**通配 App ID**（`TEAMID.*`），**不限设备、不用登记 UDID**，这也是签名平台主要用的类型。
3. **手机装一个签名工具**：轻松签 / ES 签名 / 牛蛙助手 之类（设备端签），或电脑端 Sideloadly / AltStore。

## 二、开工前只需要改这几个值

| 文件 | 位置 | 说明 |
|---|---|---|
| `project.yml` | `PRODUCT_BUNDLE_IDENTIFIER` | 你的 App 的唯一标识，**必须和证书描述文件匹配**（见下） |
| `project.yml` | `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` | 版本号 / 构建号，每次发版 bump 一下 |
| `Sources/Info.plist` | `CFBundleDisplayName` | 桌面上显示的名字 |
| `.github/workflows/build.yml` | `env.BUNDLE_ID` | 模拟器启动时用，必须和上面一致 |

**bundle id 怎么定？**

- 证书是**企业证书 / 通配 App ID**（`TEAMID.*`）→ 任意 `com.xxx.yyy` 都能签，直接用 `com.yinuoma.selfapp` 即可。
- 证书是**个人/公司证书 + 明确的 App ID**（如 `com.yinuoma.selfapp` 已注册）→ 必须完全一致，或使用签名工具里的「修改 Bundle ID」功能。
- 拿不准就先构建一版，签名工具报错信息会明确告诉你 bundle id 不匹配。

## 三、构建

Actions → **Build unsigned IPA** → *Run workflow*。也可以直接 `git push` 到 `main`。

产物：

- `SelfApp-unsigned-ipa` artifact：`SelfApp-unsigned.ipa`（30 天保留）
- `simulator-preview` artifact：`screenshot.png` + `app.log`（模拟器截图，用来「看」你的界面）

**发版用 tag**，这样手机上不用登录 GitHub 也能下载：

```bash
git tag v1.0.0 && git push origin v1.0.0
```

→ 自动挂到 Release 页面，iPhone 的 Safari 直接点开就能下。

首次构建约 5–8 分钟；之后有 Homebrew 缓存会快一些。

## 四、签名与安装（B 路线）

### 标准四步

1. iPhone 上打开 IPA 下载链接（Release 页面或 AirDrop 传过去）
2. 在签名工具里导入 `.p12`（输密码）+ `.mobileprovision`
3. 选择 IPA → 签名 → 安装
4. **设置 → 通用 → VPN与设备管理 → 信任** 对应的描述文件

### 三条可选路线

| 方式 | 前提 | 有效期 |
|---|---|---|
| 第三方证书 + 设备端签名 | 有 p12 + profile | 证书存活期内（数周～数月） |
| AltStore / Sideloadly + 自己的免费 Apple ID | 一台能开机的 Windows/电脑 | **7 天**，需定期重签 |
| TrollStore | 设备 iOS 版本在支持范围内 | 永久，直接装未签名包 |

### 签名失败最常见的原因

| 报错/现象 | 原因 | 处理 |
|---|---|---|
| `Bundle ID 不匹配` | 证书的 App ID 不是通配 | 改 `PRODUCT_BUNDLE_IDENTIFIER` 或让工具改 bundle id |
| `描述文件已过期` | profile 过期 | 换新 profile |
| 装完立刻闪退 | **证书被苹果吊销**（第三方证书日常操作） | 换证书重签，IPA 还在仓库里，不用重新编译 |
| 安装按钮灰色 / 装不上 | 描述文件未信任，或设备 iOS 版本过高 | 先信任描述文件 |
| `无法验证 App` | 签名不完整 / IPA 结构坏了 | 重新下载 IPA，确认解压后是 `Payload/SelfApp.app` |

## 五、没有 Mac 的日常开发循环

这是流程里最需要适应的部分：

1. **改代码** → push → 等 CI（5–8 分钟）。
2. **看界面**：用 `simulator-preview` 的截图 artifact，这是你唯一的「预览」手段。
   想做多状态截图，可以加 UI 测试或 snapshot 测试，输出 PNG 到 artifact。
3. **调试**：没有 Xcode Console，所以 App 内置了日志页（`Sources/DebugLog.swift`），
   写文件到 `Documents/app.log`，界面上「导出 app.log」可以 AirDrop 出来。
   建议养成关键路径 `DebugLog.write(...)` 的习惯。
4. **不要在循环里微调一个像素**——一次提交攒几个改动再构建。
5. 本地能做的是语法级检查（如 `swiftc -parse Sources/*.swift`），跑不了 iOS 编译。

## 六、排错

| 现象 | 处理 |
|---|---|
| `xcodegen: command not found` | workflow 里应该已经 `brew install`，本地跑需自己装 |
| `No such module 'SwiftUI'` | Xcode 没选对，看日志里 `Using /Applications/Xcode_*.app` |
| `Code signing is required for product type 'Application'` | `CODE_SIGNING_ALLOWED=NO` 没传到，检查 project.yml 与命令行 |
| `Build input file cannot be found: Info.plist` | `INFOPLIST_FILE` 路径错，或 `excludes` 写错 |
| Artifact 下载是空的 | 看构建最后一步有没有生成 `SelfApp-unsigned.ipa` |
| `macos-15` 镜像不可用 | 把 `runs-on` 改成 `macos-26` 或 `macos-latest` |
| 模拟器 job 失败但 IPA 成功 | 正常，`continue-on-error: true`，不影响安装包 |

## 七、换成 Flutter / React Native

`xcodebuild` 那两步换成框架自带命令，其余（打包 IPA、artifact、Release、签名流程）不变：

```bash
# Flutter：注意是 --no-codesign
flutter build ios --release --no-codesign
# 产物：build/ios/iphoneos/Runner.app
```

```bash
# React Native / Expo（prebuild 后）
npx expo prebuild --platform ios
xcodebuild -workspace ios/*.xcworkspace -scheme App -configuration Release \
  -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
```

Flutter 的好处是**本地能跑 Android 端验证 UI**，不用靠截图猜。

## 八、边界与风险

- 企业证书按协议只能给「内部员工」使用，拿来自用属于违约行为，**苹果会批量吊销**。
  → 只自用、不外发、不收费、不要在上面跑银行/支付/重要账号登录。
- 第三方签名一般拿不到 **推送、iCloud、App Groups、Sign in with Apple、Widget 扩展** 等 entitlement，做功能时避开。
- 没有 TestFlight，也没有 App Store，**升级只能重新装同一 bundle id 的包**（会覆盖，数据保留在沙盒里）。
- 免费 Apple ID 签名 7 天到期 → App 打不开，需要重新签一次（IPA 不用重编）。
- 公开仓库意味着代码公开；如有隐私信息请改私有，并注意 macOS 分钟消耗。
