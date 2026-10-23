//
//  CodeEditorView.swift
//  Code
//

import SwiftUI
import CodeEditSourceEditor
import CodeEditLanguages

struct CodeEditorView: View {
    let file: EditorFile
    @StateObject private var editorModel: EditorModel
    @State private var showFindPanel = false
    
    init(file: EditorFile) {
        self.file = file
        _editorModel = StateObject(wrappedValue: EditorModel(filePath: file.path))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 编辑器主体
            CodeEditSourceEditorView(
                model: editorModel,
                theme: .xcodeDark,
                language: .swift
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // 底部状态栏
            StatusBarView(file: file, diagnostics: editorModel.diagnostics)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button(action: {
                    showFindPanel.toggle()
                }) {
                    Image(systemName: "magnifyingglass")
                }
            }
            
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    Task {
                        await editorModel.saveFile()
                    }
                }) {
                    Image(systemName: "square.and.arrow.down")
                }
            }
        }
        .sheet(isPresented: $showFindPanel) {
            FindPanelView(model: editorModel)
        }
    }
}

struct StatusBarView: View {
    let file: EditorFile
    let diagnostics: [Diagnostic]
    
    var body: some View {
        HStack {
            Text(file.name)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            if diagnostics.isEmpty {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.caption)
            } else {
                Text("\(diagnostics.count) 错误")
                    .foregroundColor(.red)
                    .font(.caption)
            }
            
            Text("Swift")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(nsColor: .secondaryLabelColor))
    }
}

struct FindPanelView: View {
    @ObservedObject var model: EditorModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("查找和替换")
                    .font(.headline)
                Spacer()
                Button("关闭") { dismiss() }
            }
            
            TextField("查找", text: $model.searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            TextField("替换", text: $model.replaceText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            HStack {
                Button("查找上一个") { model.findPrevious() }
                Button("查找下一个") { model.findNext() }
                Button("替换") { model.replace() }
                Button("全部替换") { model.replaceAll() }
            }
        }
        .padding()
    }
}
