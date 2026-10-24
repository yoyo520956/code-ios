import Foundation
import Network
import Combine

#if canImport(UIKit)

// MARK: - WebSocket 客户端（NWConnection 原生实现）
// 用于实时构建日志推送（比 HTTP 轮询快、省电）

public final class WebSocketClient: NSObject, ObservableObject {
    public static let shared = WebSocketClient()
    
    @Published public var isConnected = false
    @Published public var lastMessage: String?
    @Published public var messages: [String] = []
    @Published public var lastError: String?
    
    private var connection: NWConnection?
    private let queue = DispatchQueue(label: "com.code.websocket")
    
    // 断线重连
    private var reconnectAttempts = 0
    private var shouldReconnect = false
    private var lastURL: String = ""
    
    private override init() {
        super.init()
    }
    
    public func enableAutoReconnect() {
        shouldReconnect = true
    }
    
    public func disableAutoReconnect() {
        shouldReconnect = false
        reconnectAttempts = 0
    }
    
    private func scheduleReconnect() {
        guard shouldReconnect, !lastURL.isEmpty else { return }
        // 指数退避：1s → 2s → 4s → ... 上限 60s
        let delay = min(pow(2.0, Double(reconnectAttempts)), 60.0)
        reconnectAttempts += 1
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self, self.shouldReconnect, !self.isConnected else { return }
            self.lastError = "重连中（第 \(self.reconnectAttempts) 次）..."
            self.connect(to: self.lastURL)
        }
    }
    
    // MARK: - 连接
    
    public func connect(to urlString: String) {
        lastURL = urlString
        
        guard let url = URL(string: urlString),
              let host = url.host else {
            lastError = "无效的 WebSocket 地址"
            return
        }
        
        let port = NWEndpoint.Port(rawValue: UInt16(url.port ?? (url.scheme == "wss" ? 443 : 80))) ?? NWEndpoint.Port(rawValue: 80)!
        
        let params: NWParameters
        if url.scheme == "wss" {
            params = NWParameters.tls
        } else {
            params = NWParameters.tcp
        }
        
        let endpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host(host),
            port: port
        )
        
        let conn = NWConnection(to: endpoint, using: params)
        connection = conn
        
        stateUpdateHandler(conn)
        
        conn.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                switch state {
                case .ready:
                    self?.isConnected = true
                    self?.lastError = nil
                    self?.reconnectAttempts = 0
                case .failed(let error):
                    self?.isConnected = false
                    self?.lastError = error.localizedDescription
                    self?.scheduleReconnect()
                case .cancelled:
                    self?.isConnected = false
                default:
                    break
                }
            }
        }
        
        conn.start(queue: queue)
        receiveLoop(on: conn)
    }
    
    public func disconnect() {
        shouldReconnect = false
        connection?.cancel()
        connection = nil
        isConnected = false
    }
    
    private func stateUpdateHandler(_ conn: NWConnection) {
        // state handler set in connect
    }
    
    // MARK: - 接收循环
    
    private func receiveLoop(on conn: NWConnection) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            if let data = data, !data.isEmpty {
                let text = String(data: data, encoding: .utf8) ?? ""
                DispatchQueue.main.async {
                    self?.lastMessage = text
                    self?.messages.append(text)
                    // 上限 200 条
                    if self?.messages.count ?? 0 > 200 {
                        self?.messages.removeFirst(self!.messages.count - 200)
                    }
                }
            }
            
            if isComplete {
                DispatchQueue.main.async {
                    self?.isConnected = false
                }
                return
            }
            
            if let error = error {
                DispatchQueue.main.async {
                    self?.lastError = error.localizedDescription
                    self?.isConnected = false
                }
                return
            }
            
            // 继续接收
            self?.receiveLoop(on: conn)
        }
    }
    
    // MARK: - 发送
    
    public func send(_ text: String) {
        guard let conn = connection, isConnected else {
            lastError = "WebSocket 未连接"
            return
        }
        
        conn.send(content: text.data(using: .utf8), completion: .contentProcessed { error in
            if let error = error {
                DispatchQueue.main.async {
                    self.lastError = error.localizedDescription
                }
            }
        })
    }
    
    public func clearMessages() {
        messages.removeAll()
    }
}

#endif
