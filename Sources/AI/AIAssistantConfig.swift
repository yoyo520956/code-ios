import Foundation
import Combine

// MARK: - AI 模型提供商配置
// 主人要求：自由接入任何模型，填密钥+接口，点刷新拉取模型列表

public struct AIProvider: Identifiable, Codable, Equatable {
    public let id: UUID
    public var name: String           // 显示名，如 "Agnes" / "OpenAI" / "Claude"
    public var baseURL: String        // API 地址，如 https://api.agnes-ai.cn
    public var apiKey: String         // 密钥（实际存储走 Keychain，这里仅运行时）
    public var models: [AIModel]      // 刷新后拉取到的模型列表
    public var isEnabled: Bool
    public var lastRefreshed: Date?
    
    public init(name: String, baseURL: String, apiKey: String = "") {
        self.id = UUID()
        self.name = name
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.models = []
        self.isEnabled = true
        self.lastRefreshed = nil
    }
    
    // 归一化 baseURL（去掉尾部斜杠）
    var normalizedBaseURL: String {
        var url = baseURL
        while url.hasSuffix("/") {
            url.removeLast()
        }
        return url
    }
    
    // OpenAI 兼容的 /v1/models 端点
    var modelsEndpoint: String {
        "\(normalizedBaseURL)/models"
    }
}

public struct AIModel: Identifiable, Codable, Equatable, Hashable {
    public let id: String             // 如 "gpt-4o" / "agnes-3.0-flash"
    public var ownedBy: String?       // 提供方
    
    public init(id: String, ownedBy: String? = nil) {
        self.id = id
        self.ownedBy = ownedBy
    }
    
    public static func == (lhs: AIModel, rhs: AIModel) -> Bool {
        lhs.id == rhs.id
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

public enum AIProviderError: Error, LocalizedError {
    case invalidURL
    case unauthorized
    case httpError(Int)
    case decodeError(String)
    case emptyKey
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL: return "接口地址无效"
        case .unauthorized: return "API Key 无效或已过期"
        case .httpError(let code): return "服务器返回 \(code)"
        case .decodeError(let msg): return "解析失败: \(msg)"
        case .emptyKey: return "请先填写 API Key"
        }
    }
}

// MARK: - AI 配置管理
public final class AIAssistantStore: ObservableObject {
    public static let shared = AIAssistantStore()
    
    @Published public var providers: [AIProvider] = []
    @Published public var selectedProviderId: UUID?
    @Published public var selectedModelId: String?
    @Published public var isRefreshing = false
    @Published public var lastError: String?
    
    // 聊天历史持久化
    @Published public var chatHistory: [ChatMessage] = [] {
        didSet {
            saveChatHistory()
        }
    }
    
    private var historyFileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("chat-history.json")
    }
    
    private init() {
        // 预置一个默认 provider（对应历史 Agnes 内置）
        let agnes = AIProvider(
            name: "Agnes",
            baseURL: "https://api.agnes-ai.cn",
            apiKey: ""
        )
        providers.append(agnes)
        selectedProviderId = agnes.id
        
        // 加载历史聊天
        loadChatHistory()
    }
    
    // MARK: - 聊天历史持久化
    
    private func saveChatHistory() {
        // 上限 200 条（内存+磁盘保护）
        let trimmed = Array(chatHistory.suffix(200))
        if let data = try? JSONEncoder().encode(trimmed) {
            try? data.write(to: historyFileURL, options: .atomic)
        }
    }
    
    private func loadChatHistory() {
        guard let data = try? Data(contentsOf: historyFileURL),
              let saved = try? JSONDecoder().decode([ChatMessage].self, from: data) else {
            return
        }
        chatHistory = saved
    }
    
    public func addChatMessage(role: String, content: String) {
        chatHistory.append(ChatMessage(role: role, content: content))
    }
    
    public func clearChatHistory() {
        chatHistory = []
        try? FileManager.default.removeItem(at: historyFileURL)
    }
    
    public var selectedProvider: AIProvider? {
        providers.first { $0.id == selectedProviderId }
    }
    
    // MARK: - 刷新模型列表
    // 点一下"刷新"→ GET {baseURL}/models → 拉取所有可用模型
    
    public func refreshModels(for providerId: UUID) async {
        guard let index = providers.firstIndex(where: { $0.id == providerId }) else { return }
        let provider = providers[index]
        
        guard !provider.apiKey.isEmpty else {
            await MainActor.run {
                lastError = AIProviderError.emptyKey.localizedDescription
            }
            return
        }
        
        await MainActor.run {
            isRefreshing = true
            lastError = nil
        }
        
        defer {
            Task { @MainActor in
                isRefreshing = false
            }
        }
        
        do {
            guard let url = URL(string: provider.modelsEndpoint) else {
                throw AIProviderError.invalidURL
            }
            
            var request = URLRequest(url: url)
            request.setValue("Bearer \(provider.apiKey)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let http = response as? HTTPURLResponse else {
                throw AIProviderError.httpError(0)
            }
            
            switch http.statusCode {
            case 200:
                // OpenAI 兼容格式: { "data": [ { "id": "...", "owned_by": "..." } ] }
                let decoded = try JSONDecoder().decode(OpenAIModelsResponse.self, from: data)
                let models = decoded.data.map { AIModel(id: $0.id, ownedBy: $0.ownedBy) }
                
                await MainActor.run {
                    providers[index].models = models
                    providers[index].lastRefreshed = Date()
                    // 自动选中第一个模型
                    if selectedModelId == nil, let first = models.first {
                        selectedModelId = first.id
                    }
                }
                
            case 401, 403:
                throw AIProviderError.unauthorized
            default:
                throw AIProviderError.httpError(http.statusCode)
            }
            
        } catch let error as AIProviderError {
            await MainActor.run {
                lastError = error.localizedDescription
            }
        } catch {
            await MainActor.run {
                lastError = error.localizedDescription
            }
        }
    }
    
    // MARK: - 增删 provider
    
    public func addProvider(name: String, baseURL: String, apiKey: String) {
        let provider = AIProvider(name: name, baseURL: baseURL, apiKey: apiKey)
        providers.append(provider)
        selectedProviderId = provider.id
    }
    
    public func removeProvider(at offsets: IndexSet) {
        providers.remove(atOffsets: offsets)
    }
    
    public func updateAPIKey(_ key: String, for providerId: UUID) {
        guard let index = providers.firstIndex(where: { $0.id == providerId }) else { return }
        providers[index].apiKey = key
    }

    // MARK: - AI 聊天（OpenAI 兼容流式）
    
    public func sendMessage(
        _ text: String,
        history: [ChatMessage],
        completion: @escaping @Sendable (Result<String, Error>) -> Void
    ) {
        guard let provider = selectedProvider,
              !provider.apiKey.isEmpty,
              let model = selectedModelId else {
            completion(.failure(AIProviderError.emptyKey))
            return
        }
        
        Task {
            do {
                guard let url = URL(string: "\(provider.normalizedBaseURL)/chat/completions") else {
                    throw AIProviderError.invalidURL
                }
                
                var messages: [[String: Any]] = history.map { ["role": $0.role, "content": $0.content] }
                messages.append(["role": "user", "content": text])
                
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("Bearer \(provider.apiKey)", forHTTPHeaderField: "Authorization")
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                let body: [String: Any] = [
                    "model": model,
                    "messages": messages,
                    "stream": false
                ]
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
                
                let (data, response) = try await URLSession.shared.data(for: request)
                
                guard let http = response as? HTTPURLResponse else {
                    throw AIProviderError.httpError(0)
                }
                
                guard http.statusCode == 200 else {
                    throw AIProviderError.httpError(http.statusCode)
                }
                
                guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let choices = json["choices"] as? [[String: Any]],
                      let first = choices.first,
                      let message = first["message"] as? [String: Any],
                      let reply = message["content"] as? String else {
                    throw AIProviderError.decodeError("响应格式异常")
                }
                
                await MainActor.run {
                    completion(.success(reply))
                }
            } catch let error as AIProviderError {
                await MainActor.run {
                    completion(.failure(error))
                }
            } catch {
                await MainActor.run {
                    completion(.failure(error))
                }
            }
        }
    }
}

// MARK: - OpenAI 兼容响应格式
struct OpenAIModelsResponse: Codable {
    let data: [OpenAIModelInfo]
}

struct OpenAIModelInfo: Codable {
    let id: String
    let ownedBy: String?
    let created: Int?
}


// MARK: - 聊天消息模型

public struct ChatMessage: Identifiable, Equatable {
    public let id: UUID
    public let role: String     // user / assistant / system
    public let content: String
    public let timestamp: Date
    
    public init(role: String, content: String) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.timestamp = Date()
    }
    
    public static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        lhs.id == rhs.id
    }
}
