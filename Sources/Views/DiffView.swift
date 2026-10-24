import Foundation
import Combine
import SwiftUI

#if canImport(UIKit)

// MARK: - 差异查看服务
// 从 GitHub API 获取提交 diff

public struct DiffFile: Identifiable, Equatable {
    public let id: String       // filename
    public let filename: String
    public let status: String   // added / modified / removed
    public let additions: Int
    public let deletions: Int
    public let patch: String?
    
    public init(filename: String, status: String, additions: Int, deletions: Int, patch: String?) {
        self.id = filename
        self.filename = filename
        self.status = status
        self.additions = additions
        self.deletions = deletions
        self.patch = patch
    }
    
    public static func == (lhs: DiffFile, rhs: DiffFile) -> Bool {
        lhs.filename == rhs.filename
    }
}

public final class DiffService: ObservableObject {
    public static let shared = DiffService()
    
    @Published public var files: [DiffFile] = []
    @Published public var isLoading = false
    @Published public var lastError: String?
    
    private let owner = "yoyo520956"
    private let repo = "code-ios"
    
    private init() {}
    
    public func fetchDiff(sha: String) async {
        await MainActor.run {
            isLoading = true
            lastError = nil
            files = []
        }
        
        do {
            guard let url = URL(string: "https://api.github.com/repos/\(owner)/\(repo)/commits/\(sha)") else {
                throw GitHubError.invalidURL
            }
            
            var request = URLRequest(url: url)
            request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
            
            let (data, _) = try await URLSession.shared.data(for: request)
            
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let commitData = json["files"] as? [[String: Any]] else {
                throw GitHubError.decodeError("diff 解析失败")
            }
            
            let diffs: [DiffFile] = commitData.compactMap { file in
                guard let filename = file["filename"] as? String,
                      let status = file["status"] as? String else { return nil }
                return DiffFile(
                    filename: filename,
                    status: status,
                    additions: file["additions"] as? Int ?? 0,
                    deletions: file["deletions"] as? Int ?? 0,
                    patch: file["patch"] as? String
                )
            }
            
            await MainActor.run {
                files = diffs
                isLoading = false
            }
        } catch {
            await MainActor.run {
                lastError = error.localizedDescription
                isLoading = false
            }
        }
    }
}

// MARK: - 差异视图

public struct DiffView: View {
    let sha: String
    let message: String
    @StateObject private var service = DiffService.shared
    
    public init(sha: String, message: String) {
        self.sha = sha
        self.message = message
    }
    
    public var body: some View {
        List {
            // 提交信息
            Section(header: Text("提交")) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(message)
                        .font(.subheadline)
                    Text(String(sha.prefix(7)))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // 变更文件列表
            Section(header: Text("变更文件（\(service.files.count)）")) {
                if service.isLoading {
                    HStack {
                        ProgressView()
                        Text("加载 diff...")
                            .foregroundColor(.secondary)
                    }
                } else if let error = service.lastError {
                    Text("错误：\(error)")
                        .font(.caption)
                        .foregroundColor(.red)
                } else {
                    ForEach(service.files) { file in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                statusIcon(file.status)
                                Text((file.filename as NSString).lastPathComponent)
                                    .font(.caption)
                                    .lineLimit(1)
                                Spacer()
                                Text("+\(file.additions)")
                                    .font(.caption2)
                                    .foregroundColor(.green)
                                Text("-\(file.deletions)")
                                    .font(.caption2)
                                    .foregroundColor(.red)
                            }
                            
                            // patch 内容
                            if let patch = file.patch {
                                Text(patch)
                                    .font(.system(size: 10, design: .monospaced))
                                    .lineLimit(20)
                                    .padding(6)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(6)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("差异")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            Task { await service.fetchDiff(sha: sha) }
        }
    }
    
    private func statusIcon(_ status: String) -> some View {
        let config: (String, Color) = {
            switch status {
            case "added": return ("plus.circle.fill", .green)
            case "removed": return ("minus.circle.fill", .red)
            default: return ("pencil.circle.fill", .orange)
            }
        }()
        return Image(systemName: config.0)
            .foregroundColor(config.1)
            .font(.caption)
    }
}

#endif
