import Foundation
import Combine
import SwiftUI

#if canImport(UIKit)

// MARK: - AI 聊天界面
// 流式对话 + 代码解释 + 错误分析

public struct AIChatView: View {
    @ObservedObject private var store = AIAssistantStore.shared
    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var isSending = false
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // 顶部模型信息
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.purple)
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.selectedProvider?.name ?? "未配置")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(store.selectedModelId ?? "未选择模型")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if !messages.isEmpty {
                    Button(action: {
                        messages.removeAll()
                    }) {
                        Image(systemName: "trash")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
            .padding()
            
            Divider()
            
            // 消息列表
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if messages.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "bubble.left.and.bubble.right")
                                    .font(.largeTitle)
                                    .foregroundColor(.secondary)
                                Text("和 AI 助手聊聊代码吧")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                // 快捷指令
                                VStack(spacing: 8) {
                                    QuickPromptButton(text: "解释这段 Swift 代码") {
                                        inputText = "请解释这段 Swift 代码：\n\n"
                                    }
                                    QuickPromptButton(text: "分析编译错误") {
                                        inputText = "我遇到这个编译错误，请帮我分析：\n\n"
                                    }
                                    QuickPromptButton(text: "生成单元测试") {
                                        inputText = "请为以下 Swift 代码生成单元测试：\n\n"
                                    }
                                }
                            }
                            .padding(.top, 40)
                        }
                        
                        ForEach(messages) { msg in
                            ChatBubble(message: msg)
                                .id(msg.id)
                        }
                        
                        if isSending {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("思考中...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .padding(.horizontal)
                            .id("sending")
                        }
                    }
                    .padding()
                }
                .onChange(of: messages.count) {
                    if let last = messages.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
            
            Divider()
            
            // 输入区
            HStack(spacing: 8) {
                TextField("输入问题...", text: $inputText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...4)
                    .onSubmit { send() }
                
                Button(action: send) {
                    Image(systemName: isSending ? "hourglass" : "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(isSending || inputText.isEmpty ? .gray : .blue)
                }
                .disabled(isSending || inputText.isEmpty)
            }
            .padding()
        }
        .navigationTitle("AI 聊天")
    }
    
    private func extractCodeBlocks(from text: String) -> [String] {
        var blocks: [String] = []
        var inBlock = false
        var current: [String] = []
        
        for line in text.components(separatedBy: "\n") {
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                if inBlock {
                    blocks.append(current.joined(separator: "\n"))
                    current = []
                    inBlock = false
                } else {
                    inBlock = true
                }
            } else if inBlock {
                current.append(line)
            }
        }
        
        return blocks
    }
    
    private func send() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isSending else { return }
        
        inputText = ""
        messages.append(ChatMessage(role: "user", content: text))
        store.addChatMessage(role: "user", content: text)
        isSending = true
        
        store.sendMessage(text, history: Array(messages.dropLast())) { result in
            DispatchQueue.main.async {
                isSending = false
                switch result {
                case .success(let reply):
                    messages.append(ChatMessage(role: "assistant", content: reply))
                    store.addChatMessage(role: "assistant", content: reply)
                    
                    // AI 生成的代码块自动保存为文件
                    if reply.contains("```") {
                        for (i, code) in extractCodeBlocks(from: reply).enumerated() where !code.isEmpty {
                            let fileName = "ai-code-\(Int(Date().timeIntervalSince1970))-\(i+1).swift"
                            _ = FileSystemService.shared.writeFile(code, to: FileSystemService.shared.documentsURL.appendingPathComponent(fileName).path)
                        }
                    }
                case .failure(let error):
                    messages.append(ChatMessage(role: "assistant", content: "⚠️ 出错了：\(error.localizedDescription)"))
                }
            }
        }
    }
}

// MARK: - 聊天气泡

struct ChatBubble: View {
    let message: ChatMessage
    
    var isUser: Bool {
        message.role == "user"
    }
    
    var body: some View {
        HStack {
            if isUser { Spacer() }
            
            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.subheadline)
                    .padding(12)
                    .background(isUser ? Color.blue.opacity(0.15) : Color(.systemGray6))
                    .cornerRadius(16)
                
                Text(message.timestamp.formatted(.dateTime.minute()))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            if !isUser { Spacer() }
        }
        .padding(.horizontal)
    }
}

// MARK: - 快捷指令按钮

struct QuickPromptButton: View {
    let text: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.purple.opacity(0.1))
                .foregroundColor(.purple)
                .cornerRadius(12)
        }
    }
}

#endif
