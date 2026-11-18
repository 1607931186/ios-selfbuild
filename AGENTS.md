# AGENTS.md — 接手说明（给任何机器上的 Agent 读）

> 这个文件是为了让**换一台机器、换一个 Agent 会话**也能无缝接手。先读完它，再去读 `README.md`。

## 这是什么项目

一个人的自用 iOS App：**没有 Mac 开发机、没有 Apple 开发者账号**，走「第三方证书 + 设备端签名」。
仓库的作用是：**GitHub Actions 每次编译出未签名 IPA**，用户在 iPhone 上用签名工具（轻松签 / Esign 类）签名安装。

## 已经验证的事实（2026-11-18）

- 仓库：<https://github.com/1607931186/ios-selfbuild>（公开，macOS runner 免费）
- 最新可安装包：<https://github.com/1607931186/ios-selfbuild/releases/tag/v0.1.0>
- 构建耗时：**41 秒**（`macos-15` runner，Xcode 由 workflow 动态选择最新稳定版）
- 产物校验通过：`Payload/SelfApp.app`，arm64 真机二进制，`CFBundleIdentifier=com.yinuoma.selfapp`，
  `CFBundleDisplayName=自用工具`，**未签名**（`code object is not signed at all`，这是预期状态）
- 当前 App 内容：占位骨架（版本信息 + 日志查看/导出），**未实现任何真实功能**
- `preview` job（模拟器截图）在 macOS runner 上会长时间排队，属于可选项，失败不影响 IPA

## 硬约定（不要改）

1. **CI 只产未签名包**。不要在 CI 里配置签名、证书、`ExportOptions`、`altool` 上传。
   签名和安装永远在用户的 iPhone 上完成。
2. **`.xcodeproj` 不入库**。工程由 CI 里 `xcodegen generate` 现生成（`project.yml` 是唯一事实来源）。
3. **`Sources/Info.plist` 手工维护**，并在 `project.yml` 的 `sources` 里 `excludes` 掉，防止被当资源重复打包。
4. **发版靠 tag**：`git tag vX.Y.Z && git push origin vX.Y.Z`，workflow 会把 IPA 挂到对应 Release。
   用户在手机上从 Release 页面下载（artifact 需要登录，Release 不需要）。
5. **改 bundle id 只改一处**：`project.yml` 的 `PRODUCT_BUNDLE_IDENTIFIER`，同时改 `.github/workflows/build.yml` 的
   `env.BUNDLE_ID`（模拟器启动用）。必须和用户证书的描述文件匹配：企业通配证书（`TEAMID.*`）随便填，
   明确的 App ID 必须完全一致。

## 待确认（用户尚未回答）

- **用户证书**：p12 + mobileprovision 是否已就绪、是哪类证书（企业通配 / 明确 App ID）、用的什么签名工具
- **设备 iOS 版本**：决定能否用 TrollStore（可省掉签名与续签）
- **真实功能需求**：目前是空骨架，需要用户说明要做什么

## 在 Linux 机器上工作时（没有 macOS 工具）

| 本机不需要做 | 说明 |
|---|---|
| `xcodebuild` / `xcrun simctl` | 一直不存在（原 Mac 也只有 CLT），编译与截图都在 CI 的 macOS runner 上 |
| `xcodegen` 本地验证 | 不必；CI 生成。想验证时可从 GitHub Releases 下载 Linux 版 xcodegen 到 `.tools/` |
| `plutil` / `sips` / `ditto` | Linux 没有。改用 `python3 -c "import plistlib..."`、Pillow；打包用 `zip` |

本机需要的只有：`git`、`gh`（Linux 版，从 cli/cli releases 下载 `linux_arm64` 或 `linux_amd64` 包）、`python3`。

## 接手步骤（新机器）

```bash
# 1. 装 gh（示例：linux arm64）
mkdir -p .tools && cd .tools
URL=$(curl -sL https://api.github.com/repos/cli/cli/releases/latest \
  | grep -o '"browser_download_url": *"[^"]*linux_arm64.tar.gz"' | head -1 | sed 's/.*"\(https[^"]*\)"/\1/')
curl -sL -o gh.tar.gz "$URL" && tar xzf gh.tar.gz

# 2. 授权（浏览器输入一次性码，约 1 分钟）
./gh_*/bin/gh auth login --hostname github.com --git-protocol https --web --scopes repo,workflow

# 3. 克隆
git clone https://github.com/1607931186/ios-selfbuild.git

# 4. 确认当前状态
./gh_*/bin/gh run list --limit 3
./gh_*/bin/gh release list
```

## 常用操作

```bash
gh run list --limit 5                     # 看构建记录
gh run watch <run-id> --exit-status       # 等构建（非 TTY 时输出会缓冲，建议直接轮询 gh run view）
gh run view <run-id> --json jobs -q '.jobs[] | .name + ": " + .status'
gh run download <run-id> -n SelfApp-unsigned-ipa -D dist   # 下载 IPA
gh release view v0.1.0 --json assets      # 看 Release 资产
```

## 构建失败时先看这三处

1. `Select newest stable Xcode` 步骤的日志（`Using /Applications/Xcode_*.app`）—— 选不到 Xcode 就会 `No such module 'SwiftUI'`
2. `Generate Xcode project` —— `project.yml` 语法错或 `INFOPLIST_FILE` 路径错
3. `Build for device` 里的第一条 error —— 通常是 Swift 代码问题，`CODE_SIGNING_ALLOWED=NO` 已排除签名原因
