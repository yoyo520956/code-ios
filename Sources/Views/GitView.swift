import Foundation
import Combine
import SwiftUI

#if canImport(UIKit)

// MARK: - Git 服务
// 基于 git 命令行的版本管理（Process 不可用，改用纯文件系统 + 远端 API）
// 实际策略：本地查看状态 + 提交走 GitHub Data API

public struct GitCommit: Identifiable, Equatable {
    public let id: String        // sha
    public let message: String
    public let author: String
    public let date: Date
    
    public init(id: String, message: String, author: String, date: Date) {
        self.id = id
        self.message = message
        self.author = author
        self.date = date
    }
    
    public static func == (lhs: GitCommit, rhs: GitCommit) -> Bool {
        lhs.id == rhs.id
    }
}

public struct GitFileChange: Identifiable, Equatable {
    public let id: String        // path
    public let path: String
    public let status: String    // added / modified / removed
    
    public init(path: String, status: String) {
        self.id = path
        self.path = path
        self.status = status
    }
    
    public static func == (lhs: GitFileChange, rhs: GitFileChange) -> Bool {
        lhs.path == rhs.path
    }
}

public final class GitService: ObservableObject {
    public static let shared = GitService()
    
    @Published public var commits: [GitCommit] = []
    @Published public var changes: [GitFileChange] = []
    @Published public var currentBranch: String = "main"
    @Published public var isLoading = false
    @Published public var lastError: String?
    @Published public var commitMessage = ""
    
    private let client = GitHubClient.shared
    private let owner = "yoyo520956"
    private let repo = "code-ios"
    
    private init() {}
    
    public func setToken(_ token: String) {
        client.setToken(token)
    }
    
    // MARK: - 拉取提交历史
    
    public func fetchCommits() async {
        await MainActor.run {
            isLoading = true
            lastError = nil
        }
        
        do {
            let commits = try await client.fetchCommits(owner: owner, repo: repo, branch: currentBranch)
            await MainActor.run {
                self.commits = commits
                isLoading = false
            }
        } catch {
            await MainActor.run {
                lastError = error.localizedDescription
                isLoading = false
            }
        }
    }
    
    // MARK: - 提交（走 GitHub Data API）
    
    public func commitFiles(_ files: [(path: String, content: String)], message: String) async {
        guard !message.isEmpty else {
            await MainActor.run { lastError = "请填写提交信息" }
            return
        }
        
        await MainActor.run {
            isLoading = true
            lastError = nil
        }
        
        do {
            let newSha = try await client.commitFiles(
                owner: owner,
                repo: repo,
                branch: currentBranch,
                message: message,
                files: files
            )
            
            await MainActor.run {
                isLoading = false
                commitMessage = ""
                // 提交成功后刷新历史
                Task {
                    await fetchCommits()
                }
            }
        } catch {
            await MainActor.run {
                lastError = error.localizedDescription
                isLoading = false
            }
        }
    }
}

// MARK: - Git 视图

public struct GitView: View {
    @ObservedObject private var git = GitService.shared
    @AppStorage("githubToken") private var githubToken = ""
    
    public init() {}
    
    public var body: some View {
        List {
            // 分支信息
            Section(header: Text("仓库")) {
                HStack {
                    Image(systemName: "arrow.triangle.branch")
                        .foregroundColor(.orange)
                    Text("yoyo520956/code-ios")
                        .font(.subheadline)
                    Spacer()
                    Text(git.currentBranch)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.2))
                        .cornerRadius(8)
                }
            }
            
            // 提交信息
            Section(header: Text("快速提交"), footer: Text("提交将写入本地更改到远端仓库")) {
                TextField("提交信息", text: $git.commitMessage)
                    .textFieldStyle(.roundedBorder)
                
                Button(action: {
                    Task { await quickCommit() }
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("提交当前更改")
                    }
                    .foregroundColor(git.isLoading ? .gray : .blue)
                }
                .disabled(git.isLoading || git.commitMessage.isEmpty)
            }
            
            // 提交历史
            Section(header: Text("提交历史")) {
                if git.isLoading {
                    HStack {
                        ProgressView()
                        Text("加载中...")
                            .foregroundColor(.secondary)
                    }
                } else if let error = git.lastError {
                    Text("错误：\(error)")
                        .font(.caption)
                        .foregroundColor(.red)
                } else if git.commits.isEmpty {
                    Text("暂无提交")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(git.commits) { commit in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(commit.message)
                                .font(.subheadline)
                                .lineLimit(2)
                            HStack {
                                Text(commit.author)
                                    .font(.caption2)
                                    .foregroundColor(.blue)
                                Text(commit.date.formatted(.dateTime.hour().minute()))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(String(commit.id.prefix(7)))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Git")
        .onAppear {
            git.setToken(githubToken)
            Task { await git.fetchCommits() }
        }
        .refreshable {
            await git.fetchCommits()
        }
    }
    
    private func quickCommit() async {
        // 收集本地所有文件的更改并提交
        let fs = FileSystemService.shared
        var files: [(path: String, content: String)] = []
        
        // 递归收集 Sources/ 下的 swift 文件
        if let enumerator = FileManager.default.enumerator(at: fs.documentsURL, includingPropertiesForKeys: nil) {
            for case let url as URL in enumerator {
                if url.pathExtension == "swift" {
                    if let content = try? String(contentsOf: url, encoding: .utf8) {
                        files.append((url.lastPathComponent, content))
                    }
                }
            }
        }
        
        guard !files.isEmpty else {
            await MainActor.run {
                git.lastError = "本地没有可提交的 Swift 文件"
            }
            return
        }
        
        await git.commitFiles(files, message: git.commitMessage)
    }
}

#endif
