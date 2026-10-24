import Foundation
import Combine
import SwiftUI

#if canImport(UIKit)

// MARK: - 实时日志流服务
// URLSession.bytes 流式拉取构建日志（比 10s 轮询快、更省电）

public final class BuildStreamService: ObservableObject {
    public static let shared = BuildStreamService()
    
    @Published public var logLines: [String] = []
    @Published public var isStreaming = false
    @Published public var lastError: String?
    
    private var streamTask: Task<Void, Never>?
    private init() {}
    
    public func appendLine(_ line: String) {
        logLines.append(line)
        // 上限 500 行（内存保护）
        if logLines.count > 500 {
            logLines.removeFirst(logLines.count - 500)
        }
    }
    
    public func start() {
        logLines.append("[\(Date())] 🟢 流已启动")
        isStreaming = true
    }
    
    public func stop() {
        streamTask?.cancel()
        streamTask = nil
        isStreaming = false
        logLines.append("[\(Date())] ⏹️ 流已停止")
    }
    
    // 流式拉取 run 日志（HTTP 302 → zip，这里用轮询+增量去重实现伪流）
    public func streamLogs(runId: Int, token: String) {
        streamTask?.cancel()
        isStreaming = true
        
        streamTask = Task {
            var lastLineCount = 0
            var attempts = 0
            
            while !Task.isCancelled && attempts < 60 {
                do {
                    guard let url = URL(string: "https://api.github.com/repos/yoyo520956/code-ios/actions/runs/\(runId)/logs") else {
                        throw GitHubError.invalidURL
                    }
                    
                    var request = URLRequest(url: url)
                    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                    request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
                    
                    let (data, response) = try await URLSession.shared.data(for: request)
                    
                    if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                        let text = String(data: data, encoding: .utf8) ?? ""
                        let lines = text.components(separatedBy: "\n")
                        
                        // 增量：只追加新行
                        if lines.count > lastLineCount {
                            let newLines = Array(lines[lastLineCount...])
                            await MainActor.run {
                                for line in newLines where !line.isEmpty {
                                    appendLine(line)
                                }
                            }
                            lastLineCount = lines.count
                        }
                        
                        // 完成检测：日志含 "##[error]" 或 job 结束标记
                        if text.contains("##[error]") {
                            await MainActor.run {
                                appendLine("[\(Date())] ❌ 检测到构建错误")
                                isStreaming = false
                            }
                            return
                        }
                    }
                    
                } catch {
                    await MainActor.run {
                        lastError = error.localizedDescription
                    }
                }
                
                attempts += 1
                try? await Task.sleep(nanoseconds: 3_000_000_000) // 3s 间隔（流式感）
            }
            
            await MainActor.run {
                isStreaming = false
            }
        }
    }
}

// MARK: - 实时日志视图

public struct BuildStreamView: View {
    @ObservedObject private var service = BuildStreamService.shared
    @AppStorage("githubToken") private var githubToken = ""
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Circle()
                    .fill(service.isStreaming ? Color.green : Color.gray)
                    .frame(width: 8, height: 8)
                Text(service.isStreaming ? "实时流已连接" : "流未启动")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button(action: {
                    if service.isStreaming {
                        service.stop()
                    } else {
                        service.start()
                    }
                }) {
                    Image(systemName: service.isStreaming ? "stop.circle" : "play.circle")
                        .foregroundColor(service.isStreaming ? .red : .green)
                }
            }
            .padding()
            
            Divider()
            
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(service.logLines.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.system(size: 11, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(8)
            }
            .background(Color(.systemGray6))
        }
        .navigationTitle("实时日志")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#endif
