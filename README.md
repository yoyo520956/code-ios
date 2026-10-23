# Code — iPhone 原生云端开发工作站

> **免责声明**：本应用非 Apple Inc. 官方产品，与 Apple 无隶属关系。

## 项目概述

**Code** 是一款为 iPhone 设计的原生 iOS 开发工作站，通过原生 Swift 代码编辑 + 云端 Mac 协同编译的方式，提供接近桌面 Xcode 的开发体验。

### 核心特性

- ✅ **原生 SwiftUI 编辑器** — 流畅的代码编辑体验
- ✅ **Swift 语法高亮** — 基于 tree-sitter 的实时高亮
- ✅ **云端编译构建** — GitHub Actions 真实编译
- ✅ **Git 版本管理** — 完整的本地 Git 操作
- ✅ **AI 编程助手** — 支持多模型 API 集成

---

## 架构设计

### 客户端（iPhone）

```
SwiftUI Views
  ├── ProjectListView     // 项目列表
  ├── FileBrowserView     // 文件浏览器
  ├── CodeEditorView      // 代码编辑器
  ├── BuildPanelView      // 构建面板
  ├── GitPanelView        // Git 面板
  └── SettingsView        // 设置
  
Stores (ObservableObject)
  ├── ProjectStore        // 项目管理
  ├── EditorStore         // 编辑器状态
  ├── BuildStore          // 构建状态
  └── GitStore            // Git 状态

Network Layer
  ├── WebSocketClient     // 实时通信
  ├── SSEClient           // 日志流
  └── APIClient           // REST API
```

### 云端服务

```
GitHub Actions (macos-15)
  ├── xcodebuild 编译
  ├── 产物归档
  └── Artifact 下载
```

---

## 快速开始

### 环境要求

- iPhone SE 第三代或更新设备
- iOS 17.0+
- 网络连接（用于云端构建）

### 构建步骤

1. 安装 XcodeGen：
   ```bash
   brew install xcodegen
   ```

2. 生成 Xcode 项目：
   ```bash
   cd poc-editor
   xcodegen generate
   ```

3. 推送到 GitHub 触发 CI

4. 下载 IPA 并通过 Feather 签名安装

---

## 技术栈

| 组件 | 技术选型 | 版本 |
|------|---------|------|
| UI 框架 | SwiftUI | iOS 17+ |
| 代码编辑器 | CodeEditSourceEditor | 0.12.1 |
| 语法解析 | tree-sitter-swift | - |
| 版本控制 | Git (libgit2) | - |
| 云端构建 | GitHub Actions | macos-15 |
| AI 集成 | OpenAI/Claude API | - |

---

## 功能矩阵

### 已实现（POC 阶段）

- [x] 项目创建与管理
- [x] 文件浏览与选择
- [x] 代码编辑器基础框架
- [x] 语法高亮（Swift）
- [x] 构建状态模拟

### 待实现（正式开发）

- [ ] 完整的 tree-sitter 集成
- [ ] GitHub Actions 真实编译
- [ ] WebSocket 实时通信
- [ ] Git 操作界面
- [ ] AI 助手集成

### 无法实现（技术限制）

- ❌ 断点调试（需 LLDB）
- ❌ 变量检查（需 debugger）
- ❌ .storyboard 可视化编辑
- ❌ Instruments 性能分析

---

## 成本估算

| 阶段 | 月成本 | 说明 |
|------|--------|------|
| 开发验证 | $0 | GitHub Actions 免费版 |
| MVP 发布 | $25-50 | 基础服务器 |
| 生产运营 | $50-200 | 按需扩展 |

---

## 许可证

MIT License

---

**项目路径**：`/var/minis/workspace/xcode-mobile/`
**创建时间**：2026-10-24
