import Foundation
import Combine
import SwiftUI

#if canImport(UIKit)

// MARK: - 编辑器标签页管理（多文件同时打开）

public final class EditorTabsStore: ObservableObject {
    public static let shared = EditorTabsStore()
    
    @Published public var tabs: [FileItem] = []
    @Published public var activeIndex: Int = 0
    
    private init() {}
    
    public var activeTab: FileItem? {
        guard activeIndex >= 0, activeIndex < tabs.count else { return nil }
        return tabs[activeIndex]
    }
    
    public func open(_ file: FileItem) {
        // 已打开则激活
        if let idx = tabs.firstIndex(where: { $0.path == file.path }) {
            activeIndex = idx
        } else {
            // 标签上限 5 个（内存保护）
            if tabs.count >= 5 {
                tabs.removeFirst()
                activeIndex = tabs.count - 1
            }
            tabs.append(file)
            activeIndex = tabs.count - 1
        }
    }
    
    public func close(at index: Int) {
        guard index >= 0, index < tabs.count else { return }
        tabs.remove(at: index)
        if activeIndex >= tabs.count {
            activeIndex = max(tabs.count - 1, 0)
        }
    }
    
    public func closeAll() {
        tabs.removeAll()
        activeIndex = 0
    }
}

// MARK: - 标签页编辑器视图

public struct EditorTabsView: View {
    @StateObject private var store = EditorTabsStore.shared
    @State private var editingFile: FileItem?
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // 标签栏（横向滚动）
            if !store.tabs.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Array(store.tabs.enumerated()), id: \.element.id) { idx, tab in
                            TabChip(
                                title: tab.name,
                                isActive: idx == store.activeIndex,
                                onClose: {
                                    store.close(at: idx)
                                }
                            )
                            .onTapGesture {
                                store.activeIndex = idx
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                }
                .background(Color(.systemGray6))
                
                Divider()
            }
            
            // 内容区
            if let active = store.activeTab {
                CodeEditorView(file: active, key: active.path)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "doc.badge.plus")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("从「文件」页打开代码文件\n最多同时 5 个标签")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("编辑器")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - 标签 Chip

struct TabChip: View {
    let title: String
    let isActive: Bool
    let onClose: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .lineLimit(1)
            
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 8))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(isActive ? Color.blue.opacity(0.2) : Color(.systemBackground))
        .foregroundColor(isActive ? .blue : .primary)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isActive ? Color.blue.opacity(0.4) : Color(.systemGray4), lineWidth: 1)
        )
    }
}

// MARK: - CodeEditorView 加 key 支持（标签切换重载）

struct CodeEditorKeyed: ViewModifier {
    let key: String
    
    func body(content: Content) -> some View {
        content.id(key)
    }
}

extension CodeEditorView {
    func withKey(_ key: String) -> some View {
        self.id(key)
    }
}

#endif
