# 贡献指南

感谢你愿意为 FlowWatch 做贡献！

## 反馈与讨论
- Bug/建议：请优先通过 GitHub Issues 提交，附上 macOS 版本、设备架构（arm64/x86_64）、复现步骤与截图/录屏（如有）。

## 开发环境
- macOS 13+
- Xcode 15+

## 本地运行
1. 打开 `FlowWatch.xcodeproj`
2. 选择 scheme：`FlowWatch`
3. `Cmd + R`

## 提交 PR
1. Fork 本仓库并创建分支：`feat/<topic>` 或 `fix/<topic>`
2. 保持改动聚焦：一个 PR 解决一个问题
3. 确保 Xcode 构建通过（Debug/Release 至少其一）
4. 在 PR 描述里说明：
   - 背景与动机
   - 变更点
   - 如何验证（截图/录屏/步骤）

## 代码风格
- 尽量保持与现有代码一致的命名与组织方式
- 新增 UI 改动建议附截图或录屏
