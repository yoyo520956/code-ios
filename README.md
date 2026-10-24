# Code iOS

**iPhone 原生云端开发工作站** — 在 iPhone SE3 上完成「写代码 → 提交 → 云端构建 → 下载 IPA」的完整开发闭环。

> ⚠️ 本项目为个人学习性质的第三方开发工具，与 Apple Xcode 无关。

## 功能清单

| 模块 | 功能 |
|------|------|
| 📁 文件 | 浏览 / 新建 / 删除 / 重命名 / 移动 / 示例项目 |
| ✏️ 编辑器 | 多文件标签（5 上限）/ 行号 / 保存 / 代码折叠 / 只读高亮 |
| 🔍 搜索 | 全局文件内容搜索（1MB 内存保护 / 100 结果封顶） |
| 🔨 构建 | GitHub Actions 触发 / 状态轮询 / 日志拉取 / 实时流（3s 增量） |
| 🤖 AI | 多提供商 / 模型列表刷新 / 聊天 / 历史持久化 / 代码块自动保存 |
| 🔀 Git | 提交历史 / 快速提交（Data API）/ 提交差异查看 |
| 📦 IPA | Release 列表（含体积）/ 下载到沙盒 / ShareLink 分享 |
| 🛡️ 可靠性 | Keychain 加密存储 / 冲突检测 / WebSocket + 断线重连 |
| ⚙️ 设置 | 性能模式 / 动态版本信息 / AI 模型配置 |

## 安装

1. 下载最新 [Release IPA](https://github.com/yoyo520956/code-ios/releases)
2. 用 [Feather](https://github.com/khcrysalis/Feather) 等侧载工具签名安装（免费 Apple ID，7 天有效）

## 构建

- CI 全自动：push → `swift build` 验证 → `xcodegen` + `xcodebuild` 打 IPA → 自动挂 Release
- Runner：macos-15 / Xcode 16.4 / iOS SDK 18.5
- 本地开发：XcodeGen（`xcodegen generate`）生成工程

## 技术栈

SwiftUI · Swift 5.9 · URLSession async/await · Network.framework (NWConnection/WebSocket) · Keychain · SPM library target（iOS 17+ / macOS 14+ 双平台 CI 验证）

## 架构

```
Sources/
├── App/          # App 入口 + 主 Tab 框架
├── Views/        # 全部 SwiftUI 视图（12 个）
├── AI/           # AI 助手（多模型配置 / 聊天 / 持久化）
├── GitHub/       # GitHub API 客户端（Actions + Commits）
├── Network/      # WebSocket 原生客户端（断线重连）
└── Store/        # Keychain 安全存储
```

## 已知限制

- iOS 真机需签名侧载（无 App Store 发布计划）
- 构建依赖 GitHub Actions 免费额度（公开仓库无限）
- AI 聊天为非流式响应（未来可接 WebSocket 流式）

## 版本

当前 **v1.2.0**（内部版本号 1.1.6 build 20261024.06）— 20+ 版迭代，CI 持续绿灯。
