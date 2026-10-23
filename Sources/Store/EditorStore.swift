//
//  EditorStore.swift
//  Code
//

import Foundation
import Combine
import CodeEditSourceEditor

@MainActor
class EditorStore: ObservableObject {
    @Published var activeFile: EditorFile?
    @Published var diagnostics: [Diagnostic] = []
    @Published var cursorPosition: Position = .init(line: 0, column: 0)
    @Published var selection: Range<Int>?
    
    private var openFiles: [EditorFile: EditorModel] = [:]
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Public Methods
    
    func openFile(_ file: EditorFile) {
        activeFile = file
        
        if let model = openFiles[file] {
            // Reuse existing model
            return
        }
        
        let model = EditorModel(filePath: file.path)
        openFiles[file] = model
        
        // Load file content
        Task {
            await model.loadContent()
        }
    }
    
    func closeFile(_ file: EditorFile) {
        openFiles.removeValue(forKey: file)
        if activeFile?.id == file.id {
            activeFile = openFiles.keys.first
        }
    }
    
    func saveFile() async {
        guard let file = activeFile,
              let model = openFiles[file] else { return }
        
        await model.saveContent()
    }
    
    func getDiagnostics(for file: EditorFile) async {
        // Parse compiler output for diagnostics
        // This would be implemented with real Swift compiler integration
        diagnostics = []
    }
    
    // MARK: - Private Methods
    
    private func setupNotifications() {
        // Listen for file changes
    }
}

// MARK: - Editor Model

class EditorModel: ObservableObject {
    @Published var content: String = ""
    @Published var diagnostics: [Diagnostic] = []
    @Published var searchText: String = ""
    @Published var replaceText: String = ""
    
    private let filePath: String
    private var fileHandle: FileHandle?
    
    init(filePath: String) {
        self.filePath = filePath
    }
    
    func loadContent() async {
        do {
            let url = URL(fileURLWithPath: filePath)
            if let data = try? Data(contentsOf: url) {
                content = String(decoding: data, as: UTF8.self)
            }
        } catch {
            print("Failed to load file: \(error)")
        }
    }
    
    func saveContent() async {
        do {
            let url = URL(fileURLWithPath: filePath)
            try content.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            print("Failed to save file: \(error)")
        }
    }
    
    // MARK: - Find & Replace
    
    func findNext() {
        guard !searchText.isEmpty else { return }
        // Implementation needed
    }
    
    func findPrevious() {
        guard !searchText.isEmpty else { return }
        // Implementation needed
    }
    
    func replace() {
        // Implementation needed
    }
    
    func replaceAll() {
        guard !searchText.isEmpty else { return }
        content = content.replacingOccurrences(of: searchText, with: replaceText)
    }
}

// MARK: - Diagnostic Model

struct Diagnostic: Identifiable {
    let id = UUID()
    let severity: Severity
    let message: String
    let line: Int
    let column: Int
    let filePath: String
    
    enum Severity: String, CaseIterable {
        case error, warning, info, hint
        
        var color: Color {
            switch self {
            case .error: return .red
            case .warning: return .orange
            case .info: return .blue
            case .hint: return .gray
            }
        }
        
        var icon: String {
            switch self {
            case .error: return "xmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .info: return "info.circle.fill"
            case .hint: return "lightbulb.fill"
            }
        }
    }
}

// MARK: - Position Model

struct Position: Equatable {
    var line: Int
    var column: Int
    
    static func == (lhs: Position, rhs: Position) -> Bool {
        lhs.line == rhs.line && lhs.column == rhs.column
    }
}
