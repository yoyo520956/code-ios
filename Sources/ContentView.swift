import SwiftUI

// MARK: - 项目模型
public struct ProjectItem: Identifiable, Codable, Equatable {
    public let id: UUID
    public var name: String
    public var path: String
    public var lastModified: Date
    public var isRemote: Bool
    
    public init(name: String, path: String, isRemote: Bool = false) {
        self.id = UUID()
        self.name = name
        self.path = path
        self.lastModified = Date()
        self.isRemote = isRemote
    }
}

// MARK: - 构建状态
public enum BuildStatus: String, Codable {
    case idle = "Idle"
    case building = "Building"
    case success = "Success"
    case failure = "Failure"
    case cancelled = "Cancelled"
}

// MARK: - 云端连接配置
public struct CloudConfig: Codable {
    public var repository: String
    public var branch: String
    public var runnerOS: String
    public var buildStatus: BuildStatus
    
    public init(repository: String, branch: String = "main", runnerOS: String = "macos-14") {
        self.repository = repository
        self.branch = branch
        self.runnerOS = runnerOS
        self.buildStatus = .idle
    }
}

// MARK: - SwiftUI 视图（条件编译，仅 iOS）
#if canImport(UIKit)
import UIKit

public struct ContentView: View {
    @State private var projects: [ProjectItem] = [
        ProjectItem(name: "Code iOS", path: "/var/minis/workspace/xcode-mobile")
    ]
    @State private var config = CloudConfig(repository: "yoyo520956/code-ios")
    @State private var logText: String = ""
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            List {
                Section(header: Text("云端构建")) {
                    HStack {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 10, height: 10)
                        Text(config.repository)
                            .font(.headline)
                        Spacer()
                        Text(config.branch)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Runner:")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(config.runnerOS)
                    }
                    
                    HStack {
                        Text("Status:")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(config.buildStatus.rawValue)
                            .foregroundColor(statusColor)
                    }
                }
                
                Section(header: Text("项目")) {
                    ForEach(projects) { project in
                        HStack {
                            Image(systemName: "folder.fill")
                                .foregroundColor(.blue)
                            VStack(alignment: .leading) {
                                Text(project.name)
                                Text(project.path)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                Section(header: Text("构建日志")) {
                    ScrollView {
                        Text(logText.isEmpty ? "等待构建输出..." : logText)
                            .font(.system(.caption, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 120)
                }
            }
            .navigationTitle("Code iOS")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { triggerBuild() }) {
                        Image(systemName: "hammer.fill")
                    }
                    .disabled(config.buildStatus == .building)
                }
            }
        }
    }
    
    private var statusColor: Color {
        switch config.buildStatus {
        case .idle: return .gray
        case .building: return .orange
        case .success: return .green
        case .failure: return .red
        case .cancelled: return .yellow
        }
    }
    
    private func triggerBuild() {
        config.buildStatus = .building
        logText += "[\(Date())] 触发 GitHub Actions 构建...\n"
        logText += "[\(Date())] 请到构建页查看实时状态\n"
        config.buildStatus = .success
    }
}

#endif

// MARK: - 公共业务逻辑（跨平台）
public final class CloudBuildEngine {
    public static let shared = CloudBuildEngine()
    
    private init() {}
    
    public func triggerBuild(repository: String, branch: String, completion: @escaping (Result<String, Error>) -> Void) {
        // 实际实现将通过 GitHub API 触发 workflow
        print("Triggering build for \(repository)@\(branch)")
        completion(.success("build-triggered"))
    }
    
    public func fetchBuildStatus(runId: String, completion: @escaping (Result<BuildStatus, Error>) -> Void) {
        // 实际实现将通过 GitHub API 查询
        completion(.success(.idle))
    }
}
