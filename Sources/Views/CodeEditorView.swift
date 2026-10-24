import Foundation
import Combine
import SwiftUI

#if canImport(UIKit)

// MARK: - 代码编辑器
// TextEditor + 行号 + 简易 Swift 语法高亮（AttributedString 关键词着色）

public struct CodeEditorView: View {
    let file: FileItem
    var key: String = ""
    @State private var content: String = ""
    @State private var isEdited = false
    @State private var showSaveAlert = false
    @State private var lineNumbers: String = "1"
    @Environment(\.dismiss) private var dismiss
    
    // Swift 关键词
    private let swiftKeywords: Set<String> = [
        "import", "struct", "class", "enum", "func", "var", "let", "if", "else",
        "for", "while", "return", "switch", "case", "default", "break", "continue",
        "public", "private", "internal", "static", "final", "override", "init",
        "self", "super", "nil", "true", "false", "extension", "protocol",
        "throws", "try", "catch", "defer", "guard", "in", "async", "await",
        "Type", "where", "associatedtype", "typealias", "some", "any"
    ]
    
    public var body: some View {
        VStack(spacing: 0) {
            // 顶部工具栏
            HStack {
                Text(file.name)
                    .font(.subheadline)
                    .lineLimit(1)
                
                if isEdited {
                    Text("•")
                        .foregroundColor(.orange)
                        .font(.title2)
                }
                
                Spacer()
                
                Button(action: save) {
                    Image(systemName: isEdited ? "square.and.arrow.down.fill" : "square.and.arrow.down")
                        .foregroundColor(isEdited ? .blue : .gray)
                }
                .disabled(!isEdited)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            Divider()
            
            // 编辑器 + 行号
            HStack(alignment: .top, spacing: 0) {
                // 行号
                ScrollView {
                    Text(lineNumbers)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(minWidth: 36, alignment: .trailing)
                        .padding(.trailing, 8)
                        .padding(.top, 8)
                }
                .background(Color(.systemGray6))
                .allowsHitTesting(false)
                
                // 代码编辑区
                TextEditor(text: $content)
                    .font(.system(size: 14, design: .monospaced))
                    .onChange(of: content) { newValue in
                        isEdited = true
                        updateLineNumbers(newValue)
                    }
            }
        }
        .navigationTitle(file.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: load)
        .alert("保存成功", isPresented: $showSaveAlert) {
            Button("好的", role: .cancel) {}
        }
    }
    
    private func load() {
        content = FileSystemService.shared.readFile(at: file.path) ?? ""
        updateLineNumbers(content)
        isEdited = false
    }
    
    private func save() {
        let ok = FileSystemService.shared.writeFile(content, to: file.path)
        if ok {
            isEdited = false
            showSaveAlert = true
        }
    }
    
    private func updateLineNumbers(_ text: String) {
        let count = text.components(separatedBy: "\n").count
        lineNumbers = (1...max(count, 1)).map { "\($0)" }.joined(separator: "\n")
    }
}

// MARK: - 简易语法高亮预览（只读模式用 AttributedString）

public struct CodePreviewView: View {
    let file: FileItem
    @State private var content: String = ""
    
    public var body: some View {
        ScrollView {
            Text(highlighted)
                .font(.system(size: 13, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
        }
        .navigationTitle(file.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            content = FileSystemService.shared.readFile(at: file.path) ?? ""
        }
    }
    
    private var highlighted: AttributedString {
        var result = AttributedString(content)
        
        let keywords = ["import", "struct", "class", "func", "var", "let", "if", "else", "return", "public", "private", "static", "true", "false", "nil", "self", "enum", "case", "switch", "for", "while", "guard", "extension"]
        
        for keyword in keywords {
            if let range = result.range(of: keyword) {
                result[range].foregroundColor = .purple
                result[range].font = .system(size: 13, weight: .semibold, design: .monospaced)
            }
        }
        
        return result
    }
}

#endif
