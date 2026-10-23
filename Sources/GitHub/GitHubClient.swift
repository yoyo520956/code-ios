import Foundation

// MARK: - GitHub Actions API Client
// 用于触发构建、查询状态、获取日志、下载产物

public struct WorkflowRun: Codable, Identifiable {
    public let id: Int
    public let name: String
    public let status: String
    public let conclusion: String?
    public let headBranch: String
    public let htmlUrl: String
    public let createdAt: Date
    public let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id, name, status, conclusion
        case headBranch = "head_branch"
        case htmlUrl = "html_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

public struct WorkflowRunsResponse: Codable {
    public let totalCount: Int
    public let workflowRuns: [WorkflowRun]
    
    enum CodingKeys: String, CodingKey {
        case totalCount = "total_count"
        case workflowRuns = "workflow_runs"
    }
}

public struct Artifact: Codable, Identifiable {
    public let id: Int
    public let name: String
    public let sizeInBytes: Int
    public let expired: Bool
    
    enum CodingKeys: String, CodingKey {
        case id, name, expired
        case sizeInBytes = "size_in_bytes"
    }
}

public enum GitHubError: Error, LocalizedError {
    case invalidURL
    case httpError(Int, String)
    case decodeError(Error)
    case unauthorized
    case rateLimited
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的 URL"
        case .httpError(let code, let msg):
            return "HTTP \(code): \(msg)"
        case .decodeError(let err):
            return "解析失败: \(err.localizedDescription)"
        case .unauthorized:
            return "未授权：请检查 GitHub Token"
        case .rateLimited:
            return "API 限流，请稍后重试"
        }
    }
}

public final class GitHubClient {
    public static let shared = GitHubClient()
    
    private let baseURL = "https://api.github.com"
    private var token: String = ""
    
    private init() {}
    
    // MARK: - 配置
    
    public func setToken(_ token: String) {
        self.token = token
    }
    
    private func makeRequest(_ path: String, method: String = "GET", body: [String: Any]? = nil) throws -> URLRequest {
        guard let url = URL(string: baseURL + path) else {
            throw GitHubError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let body = body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        
        return request
    }
    
    // MARK: - Workflow Runs
    
    public func fetchLatestRun(owner: String, repo: String, workflow: String = "build.yml") async throws -> WorkflowRun? {
        let request = try makeRequest("/repos/\(owner)/\(repo)/actions/workflows/\(workflow)/runs?per_page=1")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let http = response as? HTTPURLResponse else {
            throw GitHubError.httpError(0, "无效响应")
        }
        
        switch http.statusCode {
        case 200:
            let decoded = try JSONDecoder().decode(WorkflowRunsResponse.self, from: data)
            return decoded.workflowRuns.first
        case 401:
            throw GitHubError.unauthorized
        case 403:
            throw GitHubError.rateLimited
        default:
            throw GitHubError.httpError(http.statusCode, "请求失败")
        }
    }
    
    public func triggerWorkflow(owner: String, repo: String, workflow: String = "build.yml", ref: String = "main") async throws {
        let body: [String: Any] = ["ref": ref]
        let request = try makeRequest(
            "/repos/\(owner)/\(repo)/actions/workflows/\(workflow)/dispatches",
            method: "POST",
            body: body
        )
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let http = response as? HTTPURLResponse else {
            throw GitHubError.httpError(0, "无效响应")
        }
        
        guard http.statusCode == 204 else {
            throw GitHubError.httpError(http.statusCode, "触发失败")
        }
    }
    
    public func fetchRunStatus(owner: String, repo: String, runId: Int) async throws -> WorkflowRun {
        let request = try makeRequest("/repos/\(owner)/\(repo)/actions/runs/\(runId)")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw GitHubError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0, "查询失败")
        }
        
        return try JSONDecoder().decode(WorkflowRun.self, from: data)
    }
    
    // MARK: - Logs & Artifacts
    
    public func downloadLogs(owner: String, repo: String, runId: Int) async throws -> String {
        let request = try makeRequest("/repos/\(owner)/\(repo)/actions/runs/\(runId)/logs")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw GitHubError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0, "日志下载失败")
        }
        
        return String(data: data, encoding: .utf8) ?? ""
    }
    
    public func listArtifacts(owner: String, repo: String, runId: Int) async throws -> [Artifact] {
        let request = try makeRequest("/repos/\(owner)/\(repo)/actions/runs/\(runId)/artifacts")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw GitHubError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0, "产物查询失败")
        }
        
        let decoded = try JSONDecoder().decode([String: [Artifact]].self, from: data)
        return decoded["artifacts"] ?? []
    }

    // MARK: - Commits（Git 历史 + 提交）
    
    public struct CommitInfo: Codable {
        public let sha: String
        public let commit: CommitDetail
    }
    
    public struct CommitDetail: Codable {
        public let message: String
        public let author: CommitAuthor
    }
    
    public struct CommitAuthor: Codable {
        public let name: String
        public let date: Date
    }
    
    public func fetchCommits(owner: String, repo: String, branch: String) async throws -> [CommitInfo] {
        let request = try makeRequest("/repos/\(owner)/\(repo)/commits?sha=\(branch)&per_page=20")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw GitHubError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0, "提交历史查询失败")
        }
        
        return try JSONDecoder().decode([CommitInfo].self, from: data)
    }
    
    // Data API 提交：blob → tree → commit → PATCH ref
    public func commitFiles(owner: String, repo: String, branch: String, message: String, files: [(path: String, content: String)]) async throws -> String {
        // 1. 获取当前 ref
        let refRequest = try makeRequest("/repos/\(owner)/\(repo)/git/ref/heads/\(branch)")
        let (refData, _) = try await URLSession.shared.data(for: refRequest)
        let ref = try JSONDecoder().decode([String: [String: Any]].self, from: refData)
        
        // 简化处理：直接用 URL 构造
        guard let refURL = URL(string: "\(baseURL)/repos/\(owner)/\(repo)/git/ref/heads/\(branch)") else {
            throw GitHubError.invalidURL
        }
        var req = URLRequest(url: refURL)
        req.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (refBytes, _) = try await URLSession.shared.data(for: req)
        guard let refJSON = try? JSONSerialization.jsonObject(with: refBytes) as? [String: Any],
              let obj = refJSON["object"] as? [String: Any],
              let baseCommitSha = obj["sha"] as? String else {
            throw GitHubError.decodeError("ref 解析失败")
        }
        
        // 2. 获取 base tree
        guard let commitURL = URL(string: "\(baseURL)/repos/\(owner)/\(repo)/git/commits/\(baseCommitSha)") else {
            throw GitHubError.invalidURL
        }
        var req2 = URLRequest(url: commitURL)
        req2.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        req2.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (commitBytes, _) = try await URLSession.shared.data(for: req2)
        guard let commitJSON = try? JSONSerialization.jsonObject(with: commitBytes) as? [String: Any],
              let baseTreeSha = commitJSON["tree"] as? [String: Any],
              let treeSha = commitJSON["sha"] as? String else {
            throw GitHubError.decodeError("commit 解析失败")
        }
        _ = treeSha
        
        // 3. 创建 blobs
        var treeEntries: [[String: Any]] = []
        for file in files {
            guard let blobURL = URL(string: "\(baseURL)/repos/\(owner)/\(repo)/git/blobs") else {
                throw GitHubError.invalidURL
            }
            var blobReq = URLRequest(url: blobURL)
            blobReq.httpMethod = "POST"
            blobReq.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
            blobReq.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            blobReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let blobBody: [String: Any] = ["content": file.content, "encoding": "utf-8"]
            blobReq.httpBody = try JSONSerialization.data(withJSONObject: blobBody)
            let (blobBytes, _) = try await URLSession.shared.data(for: blobReq)
            guard let blobJSON = try? JSONSerialization.jsonObject(with: blobBytes) as? [String: Any],
                  let blobSha = blobJSON["sha"] as? String else {
                throw GitHubError.decodeError("blob 失败")
            }
            
            treeEntries.append([
                "path": file.path,
                "mode": "100644",
                "type": "blob",
                "sha": blobSha
            ])
        }
        
        // 4. 创建 tree
        guard let treeURL = URL(string: "\(baseURL)/repos/\(owner)/\(repo)/git/trees") else {
            throw GitHubError.invalidURL
        }
        var treeReq = URLRequest(url: treeURL)
        treeReq.httpMethod = "POST"
        treeReq.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        treeReq.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        treeReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let treeBody: [String: Any] = ["base_tree": baseTreeSha, "tree": treeEntries]
        treeReq.httpBody = try JSONSerialization.data(withJSONObject: treeBody)
        let (treeBytes, _) = try await URLSession.shared.data(for: treeReq)
        guard let treeJSON = try? JSONSerialization.jsonObject(with: treeBytes) as? [String: Any],
              let newTreeSha = treeJSON["sha"] as? String else {
            throw GitHubError.decodeError("tree 失败")
        }
        
        // 5. 创建 commit
        guard let newCommitURL = URL(string: "\(baseURL)/repos/\(owner)/\(repo)/git/commits") else {
            throw GitHubError.invalidURL
        }
        var newCommitReq = URLRequest(url: newCommitURL)
        newCommitReq.httpMethod = "POST"
        newCommitReq.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        newCommitReq.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        newCommitReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let newCommitBody: [String: Any] = ["message": message, "tree": newTreeSha, "parents": [baseCommitSha]]
        newCommitReq.httpBody = try JSONSerialization.data(withJSONObject: newCommitBody)
        let (newCommitBytes, _) = try await URLSession.shared.data(for: newCommitReq)
        guard let newCommitJSON = try? JSONSerialization.jsonObject(with: newCommitBytes) as? [String: Any],
              let newCommitSha = newCommitJSON["sha"] as? String else {
            throw GitHubError.decodeError("commit 失败")
        }
        
        // 6. PATCH ref
        guard let patchURL = URL(string: "\(baseURL)/repos/\(owner)/\(repo)/git/refs/heads/\(branch)") else {
            throw GitHubError.invalidURL
        }
        var patchReq = URLRequest(url: patchURL)
        patchReq.httpMethod = "PATCH"
        patchReq.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        patchReq.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        patchReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let patchBody: [String: Any] = ["sha": newCommitSha, "force": false]
        patchReq.httpBody = try JSONSerialization.data(withJSONObject: patchBody)
        let (_, patchResponse) = try await URLSession.shared.data(for: patchReq)
        
        guard let patchHTTP = patchResponse as? HTTPURLResponse, patchHTTP.statusCode == 200 else {
            throw GitHubError.httpError((patchResponse as? HTTPURLResponse)?.statusCode ?? 0, "ref 更新失败")
        }
        
        return newCommitSha
    }
}