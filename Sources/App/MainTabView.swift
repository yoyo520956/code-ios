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
            
            NavigationView {
                VStack(spacing: 0) {
                    NavigationLink(destination: SearchView()) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                            Text("全局搜索")
                                .font(.subheadline)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                    }
                    .buttonStyle(.plain)
                    
                    FileBrowserView()
                }
            }
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
            
            AIChatView()
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

// MARK: - 应用设置（占位 - 后续迭代补齐）

public struct AppSettingsView: View {
    @AppStorage("appMode") private var appMode = "balanced"
    
    public init() {}
    
    public var body: some View {
        List {
            Section(header: Text("AI 助手")) {
                NavigationLink(destination: AISettingsView()) {
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundColor(.purple)
                        Text("AI 模型配置")
                    }
                }
            }
            
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
