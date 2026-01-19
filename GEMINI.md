# FlowWatch

**注意：除非明确指定其他语言，否则默认使用简体中文进行回复。**

FlowWatch 是一个轻量级的 macOS 菜单栏应用程序，旨在实时监控网络流量（上传/下载速度）并跟踪每日使用统计数据。它结合了底层网络监控逻辑与现代 SwiftUI 界面。

## 项目概览

- **类型:** 原生 macOS 应用程序 (菜单栏 / Accessory 模式)
- **语言:** Swift
- **框架:** SwiftUI, AppKit, Combine, Charts (macOS 13+)
- **核心机制:** 使用 `getifaddrs` (BSD socket API) 读取网络接口的字节计数，并通过 `DispatchSourceTimer` 计算速率。

## 架构与关键组件

该应用程序遵循标准的 Swift 架构，混合使用了 SwiftUI 视图和 AppKit 控制器以进行系统集成。

### 入口点 (Entry Point)
- **`FlowWatchApp.swift`**: 应用程序入口点 (`@main`)。配置应用代理并定义显示模式枚举 (`MenuDisplayMode`, `StatusBarDisplayMode`)。

### 核心逻辑 (Core Logic)
- **`NetworkUsageMonitor.swift`**: 应用程序的引擎。
    - 使用 `getifaddrs` 遍历网络接口。
    - 计算瞬时速度 (B/s) 并累加每日总量。
    - 发布 `downloadBps` 和 `uploadBps` 供 UI 订阅者使用。
- **`DailyTrafficStorage.swift`**: 使用 JSON/UserDefaults 处理每日流量记录的持久化存储。

### UI 与展示 (UI & Presentation)
- **`StatusBarController.swift`**: 管理 `NSStatusItem` (菜单栏图标/文本)。根据实时数据更新状态栏外观。
- **`MenuStatusLabel.swift`**: 菜单中使用的 SwiftUI 视图，用于显示当前速度。
- **`ContentView.swift`**: 主偏好设置/控制面板（弹窗或窗口），用于调整刷新率等设置。
- **`DailyTrafficView.swift`**: 使用 Swift Charts 可视化历史数据（需要 macOS 13.0+）。

## 构建与运行

### 前提条件
- macOS (Apple Silicon 或 Intel)
- Xcode 15+ (推荐)
- 目标系统: macOS 13.0+ (由于使用了 Charts 框架)

### 构建步骤
1. 在 Xcode 中打开 `FlowWatch.xcodeproj`。
2. 选择 `FlowWatch` scheme。
3. 构建并运行 (`Cmd + R`)。

*注意：该应用作为 Accessory app 运行（不会出现在 Dock栏中）。启动后请在菜单栏中查找图标/文本。*

## 开发惯例

- **网络监控:** 网络统计数据源自系统级接口数据 (`if_data`)，而非通过 Hook 特定请求。
- **并发处理:** 使用 `DispatchQueue` 和 `Combine` 发布者进行线程安全的 UI 更新。
- **状态管理:**
    - 使用 `ObservableObject` / `@Published` 属性进行响应式数据流。
    - 共享资源使用 `Singleton` (单例) 模式 (`NetworkUsageMonitor.shared`, `DailyTrafficStorage.shared`)。
- **UI 风格:**
    - 基于速度阈值的动态着色（例如，速度越高颜色越偏向红色/暖色调）。
    - 自定义的字节单位格式化器 (B, KB, MB, GB)。

## 目录结构

```
FlowWatch/
├── FlowWatchApp.swift       # 入口点
├── AppDelegate.swift        # AppKit 代理集成
├── NetworkUsageMonitor.swift# 核心监控逻辑
├── StatusBarController.swift# 菜单栏项目管理
├── DailyTrafficStorage.swift# 数据持久化
├── DailyTrafficView.swift   # 历史数据图表
├── ContentView.swift        # 主设置视图
└── Assets.xcassets/         # 图标和颜色资源
```