# Code iOS — POC 开发笔记

## 2026-10-24 初始创建

### 已完成
1. ✅ 创建项目目录结构
2. ✅ 克隆参考项目（CodeEditSourceEditor, Runestone）
3. ✅ 编写核心代码文件：
   - App 入口（CodeApp.swift）
   - 主界面（ContentView.swift）
   - 文件列表（FileListView.swift）
   - 代码编辑器（CodeEditorView.swift）
   - 项目状态管理（ProjectStore.swift）
   - 编辑器状态管理（EditorStore.swift）
   - 构建状态管理（BuildStore.swift）
4. ✅ 创建 GitHub Actions 工作流
5. ✅ 创建 README 和项目文档

### 待完成
- [ ] 初始化 Git 仓库并推送到 GitHub
- [ ] 验证 GitHub Actions 构建流程
- [ ] 集成真实的 CodeEditSourceEditor
- [ ] 实现 WebSocket 通信
- [ ] 添加 AI 助手功能

### 技术要点
- 使用 CodeEditSourceEditor (723⭐) 作为编辑器核心
- 依赖 tree-sitter-swift 进行语法高亮
- 通过 GitHub Actions 实现云端编译
- 采用 SwiftUI + ObservableObject 架构

### 已知限制
- iSH 环境无 Swift 编译器，需在 CI 构建
- tree-sitter iOS 版本需验证兼容性
- 免费 Apple ID 签名有效期 7 天
