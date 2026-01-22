# 关于与更新功能规划（待实现）

## 目标
- 在菜单新增“关于”，显示版本号与构建号。
- 增加“检查更新”入口，并在发现新版本时提示用户。
- 根据安装方式（brew / dmg）选择对应的更新机制。

## 设计概览
### 版本号来源与自动化（完全自动）
- 版本号唯一来源：Git tag（例如 `v1.2.3`）
- 发布流程自动同步到 Xcode：
  - `MARKETING_VERSION` = tag 版本号（去掉 `v`）
  - `CURRENT_PROJECT_VERSION` = CI 构建号或递增数字
- App 运行时只读 `Info.plist` 中的 `CFBundleShortVersionString` / `CFBundleVersion`
  - 由构建流程自动写入，应用内部不做变更

### 菜单结构（状态栏菜单）
- 新增：`关于 FlowWatch`
- 新增：`检查更新…`
- 更新状态：
  - 检查中：菜单项临时置灰或显示“正在检查…”
  - 已是最新：提示“当前已是最新版本”
  - 有新版本：提示“发现新版本 vX.Y.Z”，并提供更新入口

### 版本号显示（当前版本）
- 版本号来源：`Info.plist` 中的 `CFBundleShortVersionString`
- 构建号来源：`Info.plist` 中的 `CFBundleVersion`
- 展示方式：
  - 使用 `NSApplication.shared.orderFrontStandardAboutPanel(options:)`
  - 选项内拼接 `Version x.y.z (build n)`

### 安装方式识别（brew / dmg）
- 识别策略（按优先级）：
  1. `Bundle.main.bundlePath` 是否包含 `/Caskroom/` 或 `/Cellar/`
  2. App 是否为符号链接，且指向 Homebrew 相关路径
  3. 默认判定为 dmg
- 支持调试覆盖：`UserDefaults` 或环境变量（可选）

### 更新机制
#### dmg（Sparkle + GitHub Releases）
- 采用 Sparkle 自动更新
- 更新源：GitHub Releases 生成 appcast（计划使用 `https://github.com/huangxida/FlowWatch/releases/latest/download/appcast.xml`）
- 版本判断：Sparkle 读取 appcast 中的 `version` 与 `shortVersionString` 并对比当前版本
- 支持自动检查与下载

#### brew
- 检查更新：`brew info --json=v2 flowwatch` 获取最新版号并比对
- 版本判断：将 JSON 中的 `stable` 或 `versions` 与当前 `CFBundleShortVersionString` 对比
- 自动更新：`brew upgrade flowwatch`
- 若 brew 不可用：提示用户使用 Homebrew 更新或切换 dmg 版本

### 更新检查时机
- 启动后延迟检查（例如 5 秒）
- 每日或每 24 小时限制一次自动检查
- 菜单“检查更新…”可手动触发

### CI / 发布流程（GitHub Actions）
- 触发条件：推送 Git tag（例如 `v1.2.3`）
- 版本解析：
  - `VERSION` = tag 去掉 `v`
  - `BUILD` = `GITHUB_RUN_NUMBER` 或自定义递增
- 构建时注入版本号（不手改工程文件）：
  - `xcodebuild ... MARKETING_VERSION=$VERSION CURRENT_PROJECT_VERSION=$BUILD`
- 产物与发布：
  - 生成 dmg（并签名/公证，按当前流程）
  - 生成 Sparkle appcast（`generate_appcast`）并上传
  - 创建 GitHub Release 并附上 dmg
  - 发布 appcast（使用 Releases 资源）
- Homebrew（可选）：
  - 更新公式版本与 sha256
  - 触发 brew 更新发布

## 待确认项
- brew 自动更新是否允许直接在 App 内执行，或改为提示用户手动执行

## TODO
- [x] 新增安装方式枚举与识别逻辑（例如 `InstallMethodDetector`）
- [x] 新增更新管理器（例如 `UpdateManager`）
- [x] 增加菜单项：关于 / 检查更新，并接入对应动作
- [x] 版本号拼接与展示（About Panel）
- [ ] 发布流程自动化：从 Git tag 写入 `MARKETING_VERSION` 与 `CURRENT_PROJECT_VERSION`
- [x] 补充 GitHub Actions 工作流：构建 dmg、生成 appcast、发布 Release、（可选）更新 brew 公式
- [x] 新增本地化文案：关于、检查更新、检查中、已是最新、发现新版本、更新失败
- [x] 如果采用 Sparkle：引入依赖并添加必要 Info.plist 配置
- [x] 配置 `SPARKLE_PUBLIC_KEY`（Sparkle 签名验证）
- [x] 保存 Sparkle 私钥到 CI Secret（`SPARKLE_PRIVATE_KEY`）
- [ ] 添加 Homebrew tap 发布密钥（`HOMEBREW_TAP_TOKEN`）与仓库地址（`HOMEBREW_TAP_REPO` 可选）
- [x] brew 更新流程：检测版本、提示更新、执行更新与错误处理
- [ ] 手动验证：
  - dmg 安装路径检测
  - brew 安装路径检测
  - 更新提示与菜单流程
