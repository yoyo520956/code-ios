import Foundation
import Combine
import SwiftUI

#if canImport(UIKit)

// MARK: - 全局文件搜索服务
// 递归扫描沙盒 Documents + 内容匹配

public struct SearchResult: Identifiable, Equatable {
    public let id: String
    public let path: String
    public let fileName: String
    public let lineNumber: Int
    public let lineContent: String
    
    public init(path: String, fileName: String, lineNumber: Int, lineContent: String) {
        self.id = "\(path):\(lineNumber)"
        self.path = path
        self.fileName = fileName
        self.lineNumber = lineNumber
        self.lineContent = lineContent
    }
    
    public static func == (lhs: SearchResult, rhs: SearchResult) -> Bool {
        lhs.id == rhs.id
    }
}

public final class SearchService: ObservableObject {
    public static let shared = SearchService()
    
    @Published public var results: [SearchResult] = []
    @Published public var isSearching = false
    @Published public var searchedFiles = 0
    
    private init() {}
    
    // MARK: - 全局搜索
    
    public func search(query: String) {
        guard !query.isEmpty else {
            results = []
            return
        }
        
        Task { @MainActor in
            isSearching = true
            results = []
            searchedFiles = 0
        }
        
        let docURL = FileSystemService.shared.documentsURL
        let lowered = query.lowercased()
        var found: [SearchResult] = []
        var count = 0
        
        if let enumerator = FileManager.default.enumerator(
            at: docURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) {
            for case let url as URL in enumerator {
                guard (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else { continue }
                count += 1
                
                // 只搜文本类文件（防大文件卡顿）
                let ext = url.pathExtension.lowercased()
                guard ["swift", "md", "txt", "json", "yml", "yaml", "plist", "xml", "html", "css", "js", "py"].contains(ext) else { continue }
                
                // 单文件 1MB 上限（内存保护，SE3 4GB）
                if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
                   let size = attrs[.size] as? Int64, size > 1_000_000 {
                    continue
                }
                
                guard let content = try? String(contentsOf: url, encoding: .utf8) else { continue }
                
                for (idx, line) in content.components(separatedBy: "\n").enumerated() {
                    if line.lowercased().contains(lowered) {
                        let trimmed = String(line.prefix(120))
                        found.append(SearchResult(
                            path: url.path,
                            fileName: url.lastPathComponent,
                            lineNumber: idx + 1,
                            lineContent: trimmed
                        ))
                        // 结果上限 100 条
                        if found.count >= 100 { break }
                    }
                }
                
                if found.count >= 100 { break }
            }
        }
        
        Task { @MainActor in
            results = found
            searchedFiles = count
            isSearching = false
        }
    }
}

// MARK: - 搜索视图

public struct SearchView: View {
    @StateObject private var service = SearchService.shared
    @State private var query = ""
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // 搜索框
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("搜索文件和内容...", text: $query)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                    .onSubmit {
                        service.search(query: query)
                    }
                if !query.isEmpty {
                    Button(action: {
                        query = ""
                        service.search(query: "")
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(10)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            .padding(.horizontal)
            .padding(.top, 8)
            
            Divider().padding(.top, 8)
            
            // 结果
            if service.isSearching {
                VStack(spacing: 8) {
                    ProgressView()
                    Text("搜索中...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if service.results.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text(query.isEmpty ? "输入关键词开始搜索" : "没有找到匹配结果")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // 结果统计
                HStack {
                    Text("找到 \(service.results.count) 条结果（扫描 \(service.searchedFiles) 个文件）")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 4)
                
                // 结果列表
                List(service.results) { result in
                    NavigationLink(destination: CodeEditorView(file: FileItem(
                        name: result.fileName,
                        path: result.path,
                        isDirectory: false,
                        modifiedDate: Date(),
                        size: 0
                    ))) {
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Image(systemName: "doc.text")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                Text(result.fileName)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                Text(":\(result.lineNumber)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Text(result.lineContent)
                                .font(.system(size: 12, design: .monospaced))
                                .lineLimit(1)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("搜索")
    }
}

#endif
