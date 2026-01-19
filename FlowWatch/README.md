# FlowWatch

轻量级 macOS 菜单栏网速监控工具。实时展示上下行速率，支持自定义采样间隔和色阶提示。

## 功能特点
- 菜单栏常驻，显示「上行/下行」速率，可在图标与精简速率两种模式间切换。
- 速率以 B/KB/MB/GB 每秒显示，按照速率区间动态渐变配色，便于快速分辨流量高低。
- 主界面可一键暂停/恢复监控，并通过滑杆调整采样间隔（1–10 秒）。
- 退出入口在菜单栏「完全退出」或主界面按钮。

## 工作原理
1. **定时采样**：`NetworkUsageMonitor` 使用 `DispatchSourceTimer` 以 `sampleInterval`（默认 1s）周期采样。
2. **读取网卡字节数**：调用 `getifaddrs` 遍历所有网络接口，过滤掉回环接口，将活跃接口的 `if_data.ifi_ibytes` 与 `if_data.ifi_obytes` 累加得到当前总接收/发送字节数。
3. **速率计算**：将本次总量与上次采样总量做差，得到区间增量（即瞬时速率，单位 B/s），更新 `downloadBps` / `uploadBps`。
4. **UI 更新**：`StatusBarController` 和 `MenuStatusLabel` 订阅上述 Published 属性，生成彩色文本/图标；`ContentView` 展示主界面并提供控制项。

## 目录速览
- `FlowWatchApp.swift`：应用入口，设为 accessory 模式并创建全局监控器与状态栏控制器。
- `NetworkUsageMonitor.swift`：核心采样与速率计算逻辑，支持暂停与采样间隔更新。
- `StatusBarController.swift`：托管状态栏菜单项与图标渲染，速率越高颜色越偏红。
- `MenuStatusLabel.swift`：菜单中的速率小组件，依据存储的显示模式切换样式。
- `ContentView.swift`：主界面，包含采样间隔调整、监控开关与退出按钮。

## 构建与运行
1. 环境：macOS（Apple Silicon/Intel 均可），建议使用 Xcode 15+。
2. 打开项目：用 Xcode 打开本目录（或导入上述源文件到同名 SwiftUI macOS App 工程）。
3. Scheme 选择 `FlowWatch`，目标运行在本机。
4. 运行后应用常驻菜单栏，点击图标可唤起界面/菜单，调整采样或退出。

## 发布与打包
- 见 `../docs/RELEASING.md`

## 限制与注意
- 当前速率为所有非回环接口的总和，未按接口或进程拆分。
- 数据基于系统网卡累计字节，不做历史持久化；切换采样间隔会重启计时器但不清零累积。
- 速率阈值与配色为内置经验值，如需自定义可在对应 Swift 文件内调整。
