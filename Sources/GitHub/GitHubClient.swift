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
}
