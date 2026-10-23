//
//  ContentView.swift
//  Code
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var projectStore: ProjectStore
    @EnvironmentObject var editorStore: EditorStore
    
    var body: some View {
        NavigationSplitView {
            // 侧边栏：项目文件树
            FileListView()
                .navigationTitle("项目")
        } detail: {
            // 主区域：代码编辑器
            if let activeFile = editorStore.activeFile {
                CodeEditorView(file: activeFile)
            } else {
                EmptyStateView()
                    .navigationTitle("Code")
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Code")
                    .font(.headline)
            }
            ToolbarItem(placement: .primaryAction) {
                BuildButton()
            }
        }
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "chevron.left.angle")
                .font(.system(size: 56))
                .foregroundColor(.secondary)
            
            Text("选择文件开始编辑")
                .font(.title2)
                .foregroundColor(.secondary)
            
            Text("从左侧文件树中选择 Swift 文件")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

struct BuildButton: View {
    @EnvironmentObject var buildStore: BuildStore
    
    var body: some View {
        Button(action: {
            Task {
                await buildStore.startBuild()
            }
        }) {
            if buildStore.buildStatus == .running {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            } else {
                Image(systemName: "play.fill")
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
    }
}
