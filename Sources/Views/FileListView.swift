//
//  FileListView.swift
//  Code
//

import SwiftUI

struct FileListView: View {
    @EnvironmentObject var projectStore: ProjectStore
    @EnvironmentObject var editorStore: EditorStore
    
    var body: some View {
        List(projectStore.files, id: \.path) { file in
            FileRowView(file: file)
                .onTapGesture {
                    editorStore.openFile(file)
                }
        }
        .listStyle(.sidebar)
        .toolbar {
            ToolbarItem {
                Button(action: {
                    // TODO: 添加新文件
                }) {
                    Image(systemName: "plus")
                }
            }
        }
    }
}

struct FileRowView: View {
    let file: EditorFile
    
    var body: some View {
        HStack {
            Image(systemName: file.iconName)
                .foregroundColor(file.color)
            Text(file.name)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension EditorFile {
    var iconName: String {
        switch fileType {
        case .swift: return "swift.fill"
        case .json: return "doc.fill"
        case .plist: return "gearshape.fill"
        case .image: return "photo.fill"
        case .directory: return "folder.fill"
        default: return "doc.text.fill"
        }
    }
    
    var color: Color {
        switch fileType {
        case .swift: return .orange
        case .json: return .yellow
        case .plist: return .blue
        case .image: return .purple
        case .directory: return .blue
        default: return .gray
        }
    }
    
    enum FileType {
        case swift
        case json
        case plist
        case image
        case directory
        case other
    }
    
    var fileType: FileType {
        switch extension {
        case "swift": return .swift
        case "json": return .json
        case "plist", "xml": return .plist
        case "png", "jpg", "jpeg", "heic", "svg": return .image
        case "": return .directory
        default: return .other
        }
    }
}
