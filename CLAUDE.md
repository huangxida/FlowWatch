# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

FlowWatch 是一个轻量级 macOS 菜单栏网速监控工具，使用 SwiftUI + AppKit 开发，实时显示网络上下行速率，支持自定义采样间隔和色阶提示。

## 构建与运行

使用 Xcode 打开 `FlowWatch.xcodeproj`，选择 `FlowWatch` scheme 运行。目标平台为 macOS 10.15+，建议使用 Xcode 15+。

## 代码架构

```
FlowWatchApp (入口)
    ↓
AppDelegate (设置为 accessory 模式)
    ├── NetworkUsageMonitor (核心监控逻辑)
    │   ├── downloadBps / uploadBps (Published)
    │   ├── totalDownloaded / totalUploaded
    │   └── sampleInterval / isActive
    │
    └── StatusBarController (状态栏管理)
        ├── MenuStatusLabel (菜单速率显示)
        └── ContentView (主控制界面)
```

**核心工作流程：**
1. `NetworkUsageMonitor` 使用 `DispatchSourceTimer` 按 `sampleInterval`（默认1秒）采样
2. 调用 `getifaddrs` 遍历网络接口，累加所有非回环接口的 `ifi_ibytes`（接收）和 `ifi_obytes`（发送）
3. 计算瞬时速率 = 当前总量 - 上次采样总量
4. `StatusBarController` 订阅 Published 属性更新状态栏显示

## 关键文件

| 文件 | 职责 |
|------|------|
| `NetworkUsageMonitor.swift` | 核心网络监控，使用 `getifaddrs` 读取网卡数据 |
| `StatusBarController.swift` | 状态栏菜单管理，包含速率上色逻辑 |
| `FlowWatchApp.swift` | 应用入口，定义显示模式枚举 |

## 技术栈

- Swift 5.x, SwiftUI + AppKit
- `getifaddrs` (BSD socket API) 用于网络数据采集
- `DispatchSourceTimer` 实现定时采样
