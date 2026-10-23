import Foundation
import Combine
import SwiftUI

// MARK: - AI 助手配置界面
// 主人要求：填密钥和接口 → 点击刷新 → 拉取模型列表 → 选择模型 → 简单易用

public struct AISettingsView: View {
    @StateObject private var store = AIAssistantStore.shared
    @State private var newProviderName = ""
    @State private var newProviderURL = ""
    @State private var newProviderKey = ""
    @State private var showAddProvider = false
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            List {
                // 选中模型展示
                Section(header: Text("当前选中")) {
                    if let provider = store.selectedProvider {
                        HStack {
                            Image(systemName: "sparkles")
                                .foregroundColor(.purple)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(provider.name)
                                    .font(.headline)
                                Text(store.selectedModelId ?? "未选择模型")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                    } else {
                        Text("尚未配置 AI 助手")
                            .foregroundColor(.secondary)
                    }
                }
                
                // 提供商列表
                Section(
                    header: Text("AI 提供商"),
                    footer: Text("填入 API 地址 + 密钥 → 点击刷新 → 选择模型")
                ) {
                    ForEach(store.providers) { provider in
                        ProviderRow(provider: provider, store: store)
                    }
                    .onDelete(perform: { offsets in
                        store.removeProvider(at: offsets)
                    })
                    
                    Button(action: {
                        showAddProvider = true
                    }) {
                        Label("添加提供商", systemImage: "plus.circle")
                            .foregroundColor(.blue)
                    }
                }
                
                // 错误信息
                if let error = store.lastError {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .navigationTitle("AI 助手")
            .sheet(isPresented: $showAddProvider) {
                AddProviderSheet(
                    name: $newProviderName,
                    url: $newProviderURL,
                    key: $newProviderKey,
                    onAdd: { name, url, key in
                        store.addProvider(name: name, baseURL: url, apiKey: key)
                        showAddProvider = false
                        newProviderName = ""
                        newProviderURL = ""
                        newProviderKey = ""
                    },
                    onCancel: {
                        showAddProvider = false
                    }
                )
            }
        }
    }
}

// MARK: - 单个提供商行

struct ProviderRow: View {
    let provider: AIProvider
    @ObservedObject var store: AIAssistantStore
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(provider.name)
                        .font(.headline)
                    Text(provider.baseURL)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                
                // 刷新按钮
                Button(action: {
                    Task {
                        await store.refreshModels(for: provider.id)
                    }
                }) {
                    Image(systemName: store.isRefreshing ? "arrow.clockwise.circle.fill" : "arrow.clockwise.circle")
                        .foregroundColor(.blue)
                        .font(.title3)
                }
                .disabled(store.isRefreshing || provider.apiKey.isEmpty)
            }
            
            // API Key 输入
            SecureField("API Key", text: Binding(
                get: { provider.apiKey },
                set: { newValue in
                    store.updateAPIKey(newValue, for: provider.id)
                }
            ))
            .textFieldStyle(.roundedBorder)
            .font(.caption)
            
            // 模型列表
            if !provider.models.isEmpty {
                Picker("模型", selection: Binding(
                    get: { store.selectedModelId ?? "" },
                    set: { store.selectedModelId = $0 }
                )) {
                    ForEach(provider.models) { model in
                        Text(model.id).tag(model.id)
                    }
                }
                .pickerStyle(.menu)
            }
            
            if let refreshed = provider.lastRefreshed {
                Text("刷新于 \(refreshed.formatted(.dateTime.minute()))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 添加提供商表单

struct AddProviderSheet: View {
    @Binding var name: String
    @Binding var url: String
    @Binding var key: String
    let onAdd: (String, String, String) -> Void
    let onCancel: () -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("基本信息")) {
                    TextField("名称（如 OpenAI）", text: $name)
                    TextField("API 地址", text: $url)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                    SecureField("API Key", text: $key)
                        .autocapitalization(.none)
                }
                
                Section(footer: Text("示例：https://api.agnes-ai.cn 或 https://api.openai.com")) {
                    Button("添加") {
                        guard !name.isEmpty, !url.isEmpty, !key.isEmpty else { return }
                        onAdd(name, url, key)
                    }
                    .disabled(name.isEmpty || url.isEmpty || key.isEmpty)
                    
                    Button("取消", role: .cancel) {
                        onCancel()
                    }
                }
            }
            .navigationTitle("新提供商")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
