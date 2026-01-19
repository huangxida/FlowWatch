# FlowWatch 代理指南

> 默认使用简体中文进行回复。

## 项目概览
- macOS 菜单栏应用，基于 SwiftUI + AppKit。
- 核心数据来自 `getifaddrs`，通过 `DispatchSourceTimer` 采样。
- 主入口：`FlowWatch/FlowWatchApp.swift`。
- 状态栏 UI 由 `FlowWatch/StatusBarController.swift` 管理。

## 运行要求
- macOS 13+（`DailyTrafficView` 使用 Charts）。
- Xcode 15+（包含 Swift 工具链）。
- Accessory app 形态：默认不显示 Dock 图标。

## 构建与运行（Xcode）
- 用 Xcode 15+ 打开 `FlowWatch.xcodeproj`。
- 选择 `FlowWatch` scheme。
- `Cmd + R` 运行（Accessory app；在菜单栏查看）。

## 构建（CLI）
- 列出 schemes：
  - `xcodebuild -list -project FlowWatch.xcodeproj`
- Debug 构建：
  - `xcodebuild -project FlowWatch.xcodeproj -scheme FlowWatch -configuration Debug -destination 'platform=macOS' build`
- 清理并构建：
  - `xcodebuild -project FlowWatch.xcodeproj -scheme FlowWatch -configuration Debug -destination 'platform=macOS' clean build`

## 测试
- 目前仓库未提交自动化测试。
- 若后续添加测试，可用 Xcode 或 CLI：
  - 全量测试：
    - `xcodebuild -project FlowWatch.xcodeproj -scheme FlowWatch -destination 'platform=macOS' test`
  - 单个测试（模板）：
    - `xcodebuild -project FlowWatch.xcodeproj -scheme FlowWatch -destination 'platform=macOS' -only-testing:FlowWatchTests/SomeTestCase/testExample test`
  - 查看测试目标名：
    - `xcodebuild -project FlowWatch.xcodeproj -scheme FlowWatch -showBuildSettings | rg -n "TEST_TARGET_NAME"`

## Lint 与格式化
- 当前未配置 SwiftLint/SwiftFormat。
- 使用 Xcode 内置格式化（`Editor > Structure > Re-Indent`）。
- 如引入格式化工具，保持可选并对齐 Xcode 默认风格。

## 架构说明
- 状态栏渲染位于 `StatusBarController`（AppKit 视图）。
- SwiftUI 视图主要在 `ContentView` 与 `DailyTrafficView`。
- 每日流量持久化由 `DailyTrafficStorage` 管理。
- 监控核心集中在 `NetworkUsageMonitor`（`ObservableObject`）。

## 代码风格规范
### Imports
- 最小化引用，并按平台层分组：
  - SwiftUI / AppKit / Combine / Foundation / Darwin。
- 同一层内尽量按字母顺序排列。
- 避免未使用的 import（Xcode 会警告）。

### 格式
- 使用 4 空格缩进。
- 左大括号不换行。
- 行宽保持可读，必要时拆分长表达式/字符串。
- 优先使用 trailing closures。

### 命名
- 类型：`UpperCamelCase`（如 `NetworkUsageMonitor`）。
- 属性/函数：`lowerCamelCase`（如 `downloadBps`、`updateInterval`）。
- 常量使用 `let` 且语义清晰。
- 布尔值以谓词形式命名（`isActive`、`isUp`、`isLoopback`）。
- 避免一字母变量名（短闭包除外）。

### 类型
- SwiftUI 视图使用 `struct`。
- 控制器/监控器使用 `final class`。
- 显示模式等偏好使用 `enum` + `String` raw value。
- `@Published` 仅用于 UI 关注的状态。

### 访问控制
- 默认 `private` 用于内部助手与子视图。
- 仅暴露 UI 或模块需要的 API。
- 只读状态用 `private(set)`。

### 状态与可观察性
- `ObservableObject` 变更留在模型层。
- 需要只读时优先 `@Published private(set)`。
- 用户驱动的值需要 debounce 或 clamp 后再落盘。

### SwiftUI 模式
- 视图拆分为 `private var` 组合块。
- `var body` 尽量简洁，复杂布局下沉为助手。
- 注入模型用 `@ObservedObject`，局部状态用 `@State`。
- `@AppStorage` 可用于偏好设置。

### 布局与 UI
- 统一 spacing/padding 的尺度。
- 结构化布局优先使用 `Grid` / `VStack` / `HStack`。
- 需要稳定对齐的数字使用 `monospacedDigit()`。

### AppKit 集成
- 使用 `@NSApplicationDelegateAdaptor` 连接 AppDelegate。
- `NSStatusItem` 更新必须在主线程。
- `@objc` selector 保持简短，必要时下沉到 helper。
- 菜单中 SwiftUI 内容使用 `NSHostingView`。

### Combine 与并发
- UI 更新切回 `DispatchQueue.main`。
- 异步闭包使用 `[weak self]`。
- Combine 订阅存放在 `Set<AnyCancellable>`。

### 错误处理
- 优先用 `guard` 早退出降低嵌套。
- 非致命失败使用安全默认值或静默处理。
- 生产路径避免 `fatalError`。

### 数据与持久化
- `UserDefaults` key 作为私有常量集中定义。
- 持久化逻辑集中在 `DailyTrafficStorage`。
- 读取持久化数据时提供安全默认值。

### 时间与单位
- 字节计数视为无符号，防止负增量。
- 单位换算保持一致（B/KB/MB/GB、秒）。
- 优先使用统一的格式化 helper。

### 性能与安全
- 对用户可调参数做 clamp（如 `sampleInterval`、`maxColorRateMbps`）。
- 避免在主线程做重计算。
- 计算增量时防止计数回绕。

### 字符串与本地化
- UI 字符串当前使用简体中文。
- 新增文案保持语气与语言一致。
- 若引入本地化，抽离到 `.strings` 文件。

### 文件组织
- 一个文件只放一个主类型。
- 使用 `// MARK: -` 分隔主要章节。
- 文件头保持简洁，不新增版权声明。

### 预览与可用性
- `#Preview` 保持轻量、依赖少。
- macOS 专用 helper 用 `#if os(macOS)` 保护。
- Charts 相关 API 注意 macOS 13+ 可用性。

## 仓库说明
- 包含 `CLAUDE.md` 与 `GEMINI.md` 作为项目背景。
- 未发现 Cursor 或 Copilot 规则文件。
- 源码位于 `FlowWatch/`。

## 快速索引
- 入口：`FlowWatch/FlowWatchApp.swift`。
- 监控核心：`FlowWatch/NetworkUsageMonitor.swift`。
- 状态栏：`FlowWatch/StatusBarController.swift`。
- 设置界面：`FlowWatch/ContentView.swift`。
