import Foundation
import Combine
import SwiftUI

#if canImport(UIKit)

// MARK: - 代码折叠块模型
// 识别函数体 / 类体 / 结构体体，支持折叠展开

public struct FoldableBlock: Identifiable, Equatable {
    public let id: Int              // 起始行号（0-based）
    public let startLine: Int
    public let endLine: Int
    public let signature: String    // 折叠时显示的摘要
    public let body: [String]
    public var isFolded: Bool = false
    
    public init(startLine: Int, endLine: Int, signature: String, body: [String]) {
        self.id = startLine
        self.startLine = startLine
        self.endLine = endLine
        self.signature = signature
        self.body = body
    }
    
    public static func == (lhs: FoldableBlock, rhs: FoldableBlock) -> Bool {
        lhs.id == rhs.id
    }
    
    public var lineCount: Int {
        endLine - startLine + 1
    }
}

// MARK: - 折叠解析器
// 简易花括号匹配：识别 func/class/struct/enum 开头的代码块

public enum CodeFolder {
    public static func parse(_ lines: [String]) -> [FoldableBlock] {
        var blocks: [FoldableBlock] = []
        var i = 0
        
        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // 识别块开始
            let isBlockStart =
                trimmed.hasPrefix("func ") || trimmed.hasPrefix("class ") ||
                trimmed.hasPrefix("struct ") || trimmed.hasPrefix("enum ") ||
                trimmed.hasPrefix("extension ") || trimmed.hasPrefix("init(")
            
            if isBlockStart, let openIdx = line.firstIndex(of: "{") {
                // 找匹配的 }
                var depth = 1
                var j = i
                var bodyLines: [String] = []
                
                while j < lines.count && depth > 0 {
                    let l = lines[j]
                    if j > i {
                        bodyLines.append(l)
                    }
                    for ch in l {
                        if ch == "{" { depth += 1 }
                        else if ch == "}" { depth -= 1 }
                    }
                    if depth == 0 { break }
                    j += 1
                }
                
                // 块体超过 3 行才值得折叠
                if j > i + 3 {
                    let signature = String(line[...openIdx])
                    blocks.append(FoldableBlock(
                        startLine: i,
                        endLine: j,
                        signature: trimmed.count > 40 ? String(trimmed.prefix(40)) + "..." : trimmed,
                        body: bodyLines
                    ))
                }
                
                i = j + 1
            } else {
                i += 1
            }
        }
        
        return blocks
    }
}

// MARK: - 折叠视图

public struct CodeFoldingView: View {
    let file: FileItem
    @State private var content: String = ""
    @State private var lines: [String] = []
    @State private var blocks: [FoldableBlock] = []
    
    public var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(Array(renderedLines.enumerated()), id: \.offset) { idx, line in
                    HStack(spacing: 8) {
                        Text("\(lineNumber(at: idx))")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.secondary)
                            .frame(minWidth: 30, alignment: .trailing)
                        
                        if line.isFoldable {
                            Button(action: { toggleFold(line) }) {
                                Image(systemName: line.isFolded ? "chevron.right" : "chevron.down")
                                    .font(.system(size: 10))
                                    .foregroundColor(.blue)
                            }
                        } else {
                            Text("")
                                .frame(width: 10)
                        }
                        
                        Text(line.text)
                            .font(.system(size: 13, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 1)
                }
            }
            .padding(8)
        }
        .navigationTitle("折叠视图")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: load)
    }
    
    // MARK: - 渲染状态
    
    private struct RenderLine {
        let text: String
        let lineNumber: Int      // 原文件行号（1-based）
        let isFoldable: Bool     // 是否是可折叠块的起始行
        let isFolded: Bool
    }
    
    private func load() {
        content = FileSystemService.shared.readFile(at: file.path) ?? ""
        lines = content.components(separatedBy: "\n")
        blocks = CodeFolder.parse(lines)
    }
    
    private func toggleFold(_ line: RenderLine) {
        if let idx = blocks.firstIndex(where: { $0.startLine == line.lineNumber - 1 }) {
            blocks[idx].isFolded.toggle()
        }
    }
    
    private func lineNumber(at idx: Int) -> Int {
        // 简化：折叠后行号跳变，这里用顺序计数
        renderedLineNumbers[safe: idx] ?? idx + 1
    }
    
    private var renderedLineNumbers: [Int] {
        var numbers: [Int] = []
        var current = 1
        var blockMap = Dictionary(uniqueKeysWithValues: blocks.map { ($0.startLine, $0) })
        var i = 0
        
        while i < lines.count {
            numbers.append(current)
            current += 1
            
            if let block = blockMap[i] {
                if block.isFolded {
                    // 折叠：跳过块内行
                    i = block.endLine + 1
                    continue
                }
            }
            i += 1
        }
        
        return numbers
    }
    
    private var renderedLines: [RenderLine] {
        var result: [RenderLine] = []
        var blockMap = Dictionary(uniqueKeysWithValues: blocks.map { ($0.startLine, $0) })
        var i = 0
        
        while i < lines.count {
            if let block = blockMap[i] {
                // 可折叠块
                result.append(RenderLine(
                    text: block.isFolded
                        ? "{ ... }  // \(block.lineCount - 1) 行已折叠"
                        : lines[i],
                    lineNumber: i + 1,
                    isFoldable: true,
                    isFolded: block.isFolded
                ))
                
                if block.isFolded {
                    i = block.endLine + 1
                    continue
                }
            } else {
                result.append(RenderLine(
                    text: lines[i],
                    lineNumber: i + 1,
                    isFoldable: false,
                    isFolded: false
                ))
            }
            i += 1
        }
        
        return result
    }
}

// MARK: - 数组安全下标

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

#endif
