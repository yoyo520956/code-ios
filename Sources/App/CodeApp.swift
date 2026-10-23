//
//  CodeApp.swift
//  Code
//
//  iPhone 原生云端开发工作站
//

import SwiftUI
import CodeEditSourceEditor

@main
struct CodeApp: App {
    @StateObject private var projectStore = ProjectStore()
    @StateObject private var editorStore = EditorStore()
    @StateObject private var buildStore = BuildStore()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(projectStore)
                .environmentObject(editorStore)
                .environmentObject(buildStore)
        }
    }
}
