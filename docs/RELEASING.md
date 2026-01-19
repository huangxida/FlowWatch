# 发布与打包（DMG / GitHub Releases）

本文档描述如何把 FlowWatch 打包成可在其他 Mac 上正常运行的安装包（DMG/ZIP），并发布到 GitHub Releases。核心目标是通过 **Developer ID 签名 + Apple 公证（Notarization）**，让 Gatekeeper 不拦截。

## 你需要准备什么

### 1) Apple 侧账号与证书
- Apple Developer Program（付费开发者账号）。
- Developer ID Application 证书（用于“非 App Store 分发”签名）。
- 建议使用 `notarytool` 做公证：
  - 方式 A（推荐）：App Store Connect API Key（Key ID、Issuer ID、.p8 私钥）。
  - 方式 B：Apple ID + App-Specific Password（需要在 Apple ID 里创建）。

## 没有付费开发者账号还能做吗

可以“做出 DMG/ZIP 并发布”，但很难做到“让大多数用户无阻力安装运行”：
- 没有 Apple Developer Program 就拿不到 **Developer ID Application** 证书，无法做正规签名。
- 没有 Developer ID 签名就无法走 **Notarization（公证）**，Gatekeeper 体验会明显变差。

现实可行的选择：
- **开源/给开发者用户**：发布源码，让用户自己用 Xcode 构建运行。
- **小范围分发（不追求一键安装）**：发布未签名的 `FlowWatch.zip`/`FlowWatch.dmg`，并在 Release 里写清楚绕过 Gatekeeper 的方式：
  - Finder 里对 App “右键 -> 打开”；
  - 或 System Settings -> Privacy & Security 里允许打开；
  - 或（高级用户）解 quarantine：`xattr -dr com.apple.quarantine /Applications/FlowWatch.app`。
- **借用/加入开发者账号**：加入朋友/公司的 Apple Developer Team（不一定要你个人付费），用他们的 Developer ID 证书签名与公证。

如果目标是“面向普通用户下载即用”，基本离不开 Developer ID 签名 + 公证。

### 2) 工程侧关键设置
- Release 构建必须启用 Hardened Runtime（公证要求）。
- Signing & Capabilities 中使用你的 Team，并确保 Release 配置能成功签名产物。
- Bundle Identifier 必须是你团队下唯一可用的标识（当前工程是 `com.hxd.FlowWatch`，如与你团队冲突请改成你自己的前缀）。
- 版本号：`MARKETING_VERSION`（用户看到的版本）与 `CURRENT_PROJECT_VERSION`（build number）要随发布递增。

## 本地发布流程（推荐先跑通）

### 1) 归档与导出 .app
建议用 Xcode：Product -> Archive，然后 Distribute App -> Developer ID -> Export。

也可以用命令行脚本（见 `scripts/release_build.sh`），它会：
- xcodebuild archive（Release）
- 导出 .app 到 `dist/`

如果你没有付费开发者账号（无法签名/导出 Developer ID），可以使用未签名构建脚本：
- `scripts/release_build_unsigned.sh`
  - 使用 `xcodebuild build` 直接从 DerivedData 拿到 `.app`
  - 生成 `dist/FlowWatch.dmg` 与 `dist/FlowWatch.zip`
  - 注意：这不等价于可公证的正式分发包，用户仍需手动放行 Gatekeeper

### 2) 校验签名是否正确
在导出后的 `.app` 上执行：
- `codesign --verify --deep --strict --verbose=2 FlowWatch.app`
- `codesign -dv --verbose=4 FlowWatch.app`（确认 Authority 是 Developer ID Application）

### 3) 生成 DMG（或 ZIP）
脚本 `scripts/release_build.sh` 会额外生成：
- `dist/FlowWatch.dmg`
- `dist/FlowWatch.zip`（便于某些场景直接下载）

### 4) 公证（Notarize）并 stapling
对 DMG/ZIP 做公证（DMG 更常见）。公证流程：
- 上传公证：`xcrun notarytool submit <file> --wait ...`
- 通过后 stapling：`xcrun stapler staple <file>`

脚本示例见 `scripts/notarize.sh`，支持用环境变量注入凭据（不要把凭据写进仓库）。

### 5) 终端用户体验自测
- 把 DMG 拷贝到一台“未装 Xcode/未信任开发者”的 Mac 上（或新建 macOS 用户）。
- 直接下载并打开，确认不触发“已损坏/无法打开”的拦截。
- 若你的功能涉及开机自启（Login Item），务必确认从 `/Applications` 运行后可以正常启用。

## GitHub Releases 发布建议

### 最小手动流程
- 给仓库打 tag（例如 `v1.0.0`）。
- 在 GitHub Releases 创建新 Release，上传 `FlowWatch.dmg` 和/或 `FlowWatch.zip`。
- Release Notes 写清楚：系统要求（macOS 13+）、变更点、安装方式（拖到 Applications）。

### 自动化（GitHub Actions）
仓库提供了一个工作流模板（见 `.github/workflows/release.yml`），目标是：
- push tag 后在 macOS runner 上构建、导出 app、打包 dmg/zip
-（可选）导入证书、公证、staple
- 创建 GitHub Release 并上传产物

你需要在 GitHub Secrets 里配置证书与公证相关变量，避免泄露。建议至少准备：
- `MACOS_CERTIFICATE_P12_BASE64`：Developer ID Application 证书导出的 p12 做 base64
- `MACOS_CERTIFICATE_PASSWORD`：p12 密码
- `KEYCHAIN_PASSWORD`：CI 临时 keychain 密码（任意强密码即可）
- `APPLE_TEAM_ID`：Team ID（导出与公证会用到）

公证二选一：
- App Store Connect API Key：
  - `NOTARYTOOL_KEY_ID`
  - `NOTARYTOOL_ISSUER_ID`
  - `NOTARYTOOL_KEY_P8_BASE64`（.p8 私钥做 base64，工作流会写入文件后公证）
- Apple ID：
  - `APPLE_ID`
  - `APPLE_APP_PASSWORD`

#### 如何触发工作流
该工作流监听 `v*` 形式的 tag push。最简单做法：
- 本地创建并推送 tag：`git tag v1.0.0 && git push origin v1.0.0`
- 或推送所有 tag：`git push --tags`

## 常见问题排查

### 1) “App 已损坏，无法打开”
通常是：
- 未签名、签名不完整、或下载链路破坏了签名（例如某些网盘二次压缩）。
- 未公证，且用户的 Gatekeeper 策略更严格。

建议优先使用：Developer ID 签名 + Notarization + stapling + DMG/ZIP 直传 GitHub。

## GitHub Release 文案模板（无付费账号 / 未签名分发）

> 适用于你使用 `scripts/release_build_unsigned.sh` 生成的 DMG/ZIP。

### 系统要求
- macOS 13+

### 安装
1. 下载 `FlowWatch.dmg`（或 `FlowWatch.zip`）。
2. 打开 DMG，把 `FlowWatch.app` 拖到 `/Applications`。
3. 第一次打开：
   - Finder 中对 `FlowWatch.app` **右键 -> 打开**（然后再次确认打开）
   - 或到“系统设置 -> 隐私与安全性”中允许打开

### 为什么要多一步“允许打开”
该版本为个人开发/未签名分发版本，未进行 Developer ID 签名与 Apple 公证，因此 macOS 会提示风险。这是系统的安全策略，不代表一定存在恶意行为。

### 可选（高级用户）
如果你清楚自己在做什么，可以在安装后移除下载隔离标记（quarantine）：
- `xattr -dr com.apple.quarantine /Applications/FlowWatch.app`

### 2) Login Item / 开机自启无法启用
macOS 对开机自启有更严格要求，通常需要：
- App 已签名且正确安装在 `/Applications`
- 公证通过且 stapled

### 3) Bundle ID / Team 冲突
把 `PRODUCT_BUNDLE_IDENTIFIER` 改成你自己团队名下的唯一标识，例如 `com.yourname.flowwatch`，并确保签名 Team 正确。
