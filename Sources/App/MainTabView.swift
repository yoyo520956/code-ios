import Foundation
import Combine
import SwiftUI

#if canImport(UIKit)
// MARK: - 主 Tab 导航
// 5 个核心 tab：项目 / 文件 / 构建 / AI / 设置

public struct MainTabView: View {
    @State private var selectedTab = 0
    
    public init() {}
    
    public var body: some View {
        TabView(selection: $selectedTab) {
            ContentView()
                .tabItem {
                    Image(systemName: "folder")
                    Text("项目")
                }
                .tag(0)
            
            FileBrowserView()
                .tabItem {
                    Image(systemName: "doc.text")
                    Text("文件")
                }
                .tag(1)
            
            BuildLogView()
                .tabItem {
                    Image(systemName: "hammer")
                    Text("构建")
                }
                .tag(2)
            
            AISettingsView()
                .tabItem {
                    Image(systemName: "sparkles")
                    Text("AI")
                }
                .tag(3)
            
            AppSettingsView()
                .tabItem {
                    Image(systemName: "gearshape")
                    Text("设置")
                }
                .tag(4)
        }
    }
}

// MARK: - 构建日志（占位 - 后续迭代补齐）

public struct BuildLogView: View {
    @State private var logText = ""
    @State private var isBuilding = false
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // 工具栏
            HStack {
                Text("构建日志")
                    .font(.headline)
                Spacer()
                Button(action: {
                    Task { await triggerBuild() }
                }) {
                    Image(systemName: isBuilding ? "hourglass" : "play.fill")
                        .foregroundColor(isBuilding ? .orange : .blue)
                }
                .disabled(isBuilding)
            }
            .padding()
            
            Divider()
            
            // 日志内容
            ScrollView {
                Text(logText.isEmpty ? "等待构建..." : logText)
                    .font(.system(.caption, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
            }
            .background(Color(.systemGray6))
        }
    }
    
    private func triggerBuild() async {
        isBuilding = true
        logText += "[\(Date())] 触发 GitHub Actions 构建...\n"
        
        // TODO: 接 GitHubClient
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        logText += "[\(Date())] 构建完成 ✅\n"
        isBuilding = false
    }
}

// MARK: - 应用设置（占位 - 后续迭代补齐）

public struct AppSettingsView: View {
    @AppStorage("appMode") private var appMode = "balanced"
    
    public init() {}
    
    public var body: some View {
        List {
            Section(header: Text("性能模式")) {
                Picker("模式", selection: $appMode) {
                    Text("低性能").tag("low")
                    Text("平衡").tag("balanced")
                    Text("高性能").tag("high")
                }
                .pickerStyle(.segmented)
            }
            
            Section(header: Text("关于")) {
                HStack {
                    Text("版本")
                    Spacer()
                    Text("1.0.0 (20261024.01)")
                        .foregroundColor(.secondary)
                }
                HStack {
                    Text("项目")
                    Spacer()
                    Text("Code iOS")
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("设置")
    }
}

#endif
