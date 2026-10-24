import Foundation
import Combine
import SwiftUI

#if canImport(UIKit)

// MARK: - 文件系统服务
// 真实文件管理：读取本地 Documents 目录 + 项目文件列表

public final class FileSystemService: ObservableObject {
    public static let shared = FileSystemService()
    
    @Published public var files: [FileItem] = []
    @Published public var isLoading = false
    @Published public var lastError: String?
    
    private let fileManager = FileManager.default
    
    private init() {}
    
    // 项目根目录（沙盒 Documents）
    public var documentsURL: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    
    // MARK: - 列出目录内容
    
    public func listFiles(at path: String? = nil) {
        Task { @MainActor in
            isLoading = true
            lastError = nil
            
            let targetURL = path != nil
                ? documentsURL.appendingPathComponent(path!)
                : documentsURL
            
            do {
                let contents = try fileManager.contentsOfDirectory(
                    at: targetURL,
                    includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey, .fileSizeKey],
                    options: [.skipsHiddenFiles]
                )
                
                let items: [FileItem] = contents.map { url in
                    var isDirectory = false
                    _ = try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory.map { isDirectory = $0 }
                    
                    let date = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date()
                    let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                    
                    return FileItem(
                        name: url.lastPathComponent,
                        path: url.path,
                        isDirectory: isDirectory,
                        modifiedDate: date,
                        size: Int64(size)
                    )
                }
                .sorted { ($0.isDirectory ? 0 : 1, $0.name) < ($1.isDirectory ? 0 : 1, $1.name) }
                
                files = items
                
            } catch {
                lastError = error.localizedDescription
                files = []
            }
            
            isLoading = false
        }
    }
    
    // MARK: - 读取文件内容
    
    public func readFile(at path: String) -> String? {
        do {
            return try String(contentsOfFile: path, encoding: .utf8)
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }
    
    // MARK: - 写入文件
    
    public func writeFile(_ content: String, to path: String) -> Bool {
        do {
            try content.write(toFile: path, atomically: true, encoding: .utf8)
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }
    
    // MARK: - 创建目录
    
    public func createDirectory(named name: String, at path: String? = nil) -> Bool {
        let parentURL = path != nil ? documentsURL.appendingPathComponent(path!) : documentsURL
        let newURL = parentURL.appendingPathComponent(name)
        do {
            try fileManager.createDirectory(at: newURL, withIntermediateDirectories: true)
            listFiles(at: path)
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }
    
    // MARK: - 删除
    
    public func delete(_ item: FileItem) {
        do {
            try fileManager.removeItem(atPath: item.path)
            listFiles()
        } catch {
            lastError = error.localizedDescription
        }
    }
    
    // MARK: - 创建示例文件
    
    public func createSampleProject() {
        let sampleDir = documentsURL.appendingPathComponent("MyProject")
        try? fileManager.createDirectory(at: sampleDir, withIntermediateDirectories: true)
        
        let sampleSwift = """
        import SwiftUI
        
        struct SampleApp: View {
            var body: some View {
                Text("Hello from Code iOS!")
                    .font(.largeTitle)
            }
        }
        """
        
        let samplePath = sampleDir.appendingPathComponent("SampleApp.swift")
        if !fileManager.fileExists(atPath: samplePath.path) {
            try? sampleSwift.write(to: samplePath, atomically: true, encoding: .utf8)
        }
        
        listFiles()
    }
}

// MARK: - 文件项模型

public struct FileItem: Identifiable, Equatable {
    public let id: UUID
    public let name: String
    public let path: String
    public let isDirectory: Bool
    public let modifiedDate: Date
    public let size: Int64
    
    public init(name: String, path: String, isDirectory: Bool, modifiedDate: Date, size: Int64) {
        self.id = UUID()
        self.name = name
        self.path = path
        self.isDirectory = isDirectory
        self.modifiedDate = modifiedDate
        self.size = size
    }
    
    public static func == (lhs: FileItem, rhs: FileItem) -> Bool {
        lhs.path == rhs.path
    }
    
    var sizeDescription: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
    
    var icon: String {
        if isDirectory { return "folder.fill" }
        switch (name as NSString).pathExtension.lowercased() {
        case "swift": return "swift"
        case "md", "txt": return "doc.text"
        case "json", "plist": return "curlybraces"
        case "yml", "yaml": return "gearshape.2"
        default: return "doc"
        }
    }
}

// MARK: - 文件浏览器视图

public struct FileBrowserView: View {
    @StateObject private var fs = FileSystemService.shared
    @State private var currentPath: String? = nil
    
    public init() {}
    
    public var body: some View {
        List {
            if let error = fs.lastError {
                Section {
                    Text("错误：\(error)")
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
            
            Section(
                header: Text(currentPath ?? "Documents"),
                footer: Text("长按文件可删除")
            ) {
                if fs.isLoading {
                    HStack {
                        ProgressView()
                        Text("加载中...")
                            .foregroundColor(.secondary)
                    }
                } else if fs.files.isEmpty {
                    Button(action: {
                        fs.createSampleProject()
                    }) {
                        Label("创建示例项目", systemImage: "plus.circle")
                            .foregroundColor(.blue)
                    }
                } else {
                    ForEach(fs.files) { file in
                        NavigationLink(destination: file.isDirectory ?
                            AnyView(FileBrowserView(currentPath: relativePath(of: file))) :
                            AnyView(swiftFileView(file))
                        ) {
                            HStack(spacing: 12) {
                                Image(systemName: file.icon)
                                    .foregroundColor(file.isDirectory ? .blue : .gray)
                                    .frame(width: 24)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(file.name)
                                        .font(.body)
                                    Text("\(file.sizeDescription) · \(file.modifiedDate.formatted(.dateTime.hour().minute()))")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .contextMenu {
                            Button(role: .destructive, action: {
                                fs.delete(file)
                            }) {
                                Label("删除", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("文件")
        .onAppear {
            fs.listFiles(at: currentPath)
        }
    }
    
    init(currentPath: String) {
        self._currentPath = State(initialValue: currentPath)
    }
    
    private func relativePath(of file: FileItem) -> String {
        let docPath = fs.documentsURL.path
        let fullPath = file.path
        if fullPath.hasPrefix(docPath) {
            let rel = String(fullPath.dropFirst(docPath.count + 1))
            return rel
        }
        return file.name
    }
}

// MARK: - 文件预览（简单版 - 后续换成真正的编辑器）

public struct FilePreviewView: View {
    let file: FileItem
    @State private var content: String = ""
    
    public var body: some View {
        ScrollView {
            Text(content.isEmpty ? "（空文件）" : content)
                .font(.system(.caption, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
        }
        .navigationTitle(file.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            content = FileSystemService.shared.readFile(at: file.path) ?? ""
        }
    }
}

#endif
