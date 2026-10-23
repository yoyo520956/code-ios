import Foundation
import Combine
import SwiftUI

#if canImport(UIKit)

// MARK: - 构建服务
// 真实接 GitHub Actions API：触发构建 + 轮询状态 + 拉取日志

public final class BuildService: ObservableObject {
    public static let shared = BuildService()
    
    @Published public var runs: [WorkflowRun] = []
    @Published public var logText: String = ""
    @Published public var isBuilding: Bool = false
    @Published public var lastError: String?
    @Published public var latestRun: WorkflowRun?
    
    private let client = GitHubClient.shared
    private let owner = "yoyo520956"
    private let repo = "code-ios"
    
    private var pollingTask: Task<Void, Never>?
    private init() {}
    
    public func setToken(_ token: String) {
        client.setToken(token)
    }
    
    // MARK: - 触发构建
    
    public func triggerBuild() async {
        await MainActor.run {
            isBuilding = true
            lastError = nil
            logText += "[\(Date())] 🚀 触发 GitHub Actions 构建...\n"
        }
        
        do {
            try await client.triggerWorkflow(owner: owner, repo: repo)
            await MainActor.run {
                logText += "[\(Date())] ✅ Workflow dispatch 已发出\n"
            }
            await pollLatestRun()
        } catch {
            await MainActor.run {
                lastError = error.localizedDescription
                logText += "[\(Date())] ❌ 触发失败: \(error.localizedDescription)\n"
                isBuilding = false
            }
        }
    }
    
    // MARK: - 轮询最新构建状态
    
    public func pollLatestRun() async {
        // 等 workflow 启动
        try? await Task.sleep(nanoseconds: 5_000_000_000)
        
        var attempts = 0
        while attempts < 30 {
            do {
                if let run = try await client.fetchLatestRun(owner: owner, repo: repo) {
                    await MainActor.run {
                        latestRun = run
                        if !runs.contains(where: { $0.id == run.id }) {
                            runs.insert(run, at: 0)
                        }
                        
                        logText += "[\(Date())] 构建状态: \(run.status) \(run.conclusion.map { "→ \($0)" } ?? "")\n"
                    }
                    
                    // 完成态判断
                    if run.status == "completed" {
                        await MainActor.run {
                            isBuilding = false
                            if run.conclusion == "success" {
                                logText += "[\(Date())] ✅ 构建成功！\n"
                            } else {
                                logText += "[\(Date())] ❌ 构建失败（\(run.conclusion ?? "未知")）\n"
                            }
                        }
                        
                        // 拉取日志
                        if let conclusion = run.conclusion, conclusion == "success" || conclusion == "failure" {
                            await fetchLogs(runId: run.id)
                        }
                        return
                    }
                }
            } catch {
                await MainActor.run {
                    logText += "[\(Date())] ⚠️ 轮询错误: \(error.localizedDescription)\n"
                }
            }
            
            attempts += 1
            try? await Task.sleep(nanoseconds: 10_000_000_000) // 10s 轮询间隔
        }
        
        await MainActor.run {
            isBuilding = false
            logText += "[\(Date())] ⏱️ 轮询超时\n"
        }
    }
    
    // MARK: - 拉取日志
    
    private func fetchLogs(runId: Int) async {
        do {
            let logs = try await client.downloadLogs(owner: owner, repo: repo, runId: runId)
            let truncated = logs.count > 10_000 ? String(logs.suffix(10_000)) : logs
            await MainActor.run {
                logText += "\n===== 构建日志（最后部分）=====\n\(truncated)\n"
            }
        } catch {
            await MainActor.run {
                logText += "[\(Date())] ⚠️ 日志拉取失败: \(error.localizedDescription)\n"
            }
        }
    }
    
    // MARK: - 刷新历史
    
    public func refreshHistory() async {
        do {
            if let run = try await client.fetchLatestRun(owner: owner, repo: repo) {
                await MainActor.run {
                    latestRun = run
                    if !runs.contains(where: { $0.id == run.id }) {
                        runs.insert(run, at: 0)
                    }
                }
            }
        } catch {
            await MainActor.run {
                lastError = error.localizedDescription
            }
        }
    }
}

// MARK: - 构建日志视图（真实版）

public struct BuildLogView: View {
    @ObservedObject private var service = BuildService.shared
    @AppStorage("githubToken") private var githubToken = ""
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // 工具栏
            HStack {
                Text("构建")
                    .font(.headline)
                
                if let run = service.latestRun {
                    StatusBadge(status: run.status, conclusion: run.conclusion)
                }
                
                Spacer()
                
                Button(action: {
                    Task { await service.triggerBuild() }
                }) {
                    Image(systemName: service.isBuilding ? "hourglass" : "play.fill")
                        .foregroundColor(service.isBuilding ? .orange : .blue)
                }
                .disabled(service.isBuilding || githubToken.isEmpty)
                
                Button(action: {
                    Task { await service.refreshHistory() }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.gray)
                }
            }
            .padding()
            
            Divider()
            
            if githubToken.isEmpty {
                // 未配置 token
                VStack(spacing: 12) {
                    Image(systemName: "key")
                        .font(.title)
                        .foregroundColor(.secondary)
                    Text("请先在设置中填入 GitHub Token")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // 构建历史
                if !service.runs.isEmpty {
                    List {
                        ForEach(service.runs.prefix(5)) { run in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(run.name)
                                        .font(.caption)
                                    Text(run.createdAt.formatted(.dateTime.hour().minute()))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                StatusBadge(status: run.status, conclusion: run.conclusion)
                            }
                        }
                    }
                    .frame(height: 180)
                    .listStyle(.plain)
                }
                
                // 日志流
                ScrollViewReader { proxy in
                    ScrollView {
                        Text(service.logText.isEmpty ? "点击 ▶️ 触发构建" : service.logText)
                            .font(.system(.caption2, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                            .id("log-bottom")
                    }
                    .background(Color(.systemGray6))
                    .onChange(of: service.logText) {
                        proxy.scrollTo("log-bottom", anchor: .bottom)
                    }
                }
            }
        }
        .onChange(of: githubToken) {
            service.setToken(githubToken)
        }
        .onAppear {
            service.setToken(githubToken)
        }
    }
}

// MARK: - 状态徽章

struct StatusBadge: View {
    let status: String
    let conclusion: String?
    
    var color: Color {
        if status != "completed" { return .orange }
        switch conclusion {
        case "success": return .green
        case "failure": return .red
        case "cancelled": return .yellow
        default: return .gray
        }
    }
    
    var text: String {
        if status != "completed" { return "运行中" }
        switch conclusion {
        case "success": return "成功"
        case "failure": return "失败"
        case "cancelled": return "已取消"
        default: return conclusion ?? "未知"
        }
    }
    
    var body: some View {
        Text(text)
            .font(.caption2)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .cornerRadius(8)
    }
}

#endif
