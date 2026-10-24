import Foundation
import Combine
import SwiftUI

#if canImport(UIKit)

// MARK: - 冲突检测服务
// 多标签编辑同文件 / 编辑期间远端更新的冲突提示

public struct ConflictInfo: Identifiable, Equatable {
    public let id: String            // path
    public let path: String
    public let localModified: Date
    public let remoteModified: Date
    
    public init(path: String, localModified: Date, remoteModified: Date) {
        self.id = path
        self.path = path
        self.localModified = localModified
        self.remoteModified = remoteModified
    }
    
    public static func == (lhs: ConflictInfo, rhs: ConflictInfo) -> Bool {
        lhs.path == rhs.path
    }
}

public final class ConflictService: ObservableObject {
    public static let shared = ConflictService()
    
    @Published public var conflicts: [ConflictInfo] = []
    @Published public var showConflictAlert = false
    @Published public var pendingConflict: ConflictInfo?
    
    // 记录每个文件最后已知的远端修改时间
    private var remoteTimestamps: [String: Date] = [:]
    // 记录每个标签编辑器的脏状态
    private var dirtyEditors: [String: Bool] = [:]
    
    private init() {}
    
    // MARK: - 注册编辑器
    
    public func registerEditor(path: String) {
        if remoteTimestamps[path] == nil {
            remoteTimestamps[path] = Date()
        }
        dirtyEditors[path] = false
    }
    
    public func markDirty(path: String, isDirty: Bool) {
        dirtyEditors[path] = isDirty
    }
    
    // MARK: - 检测冲突（切换标签时调用）
    
    public func checkConflict(path: String, currentFileDate: Date) -> ConflictInfo? {
        guard let remote = remoteTimestamps[path] else {
            remoteTimestamps[path] = currentFileDate
            return nil
        }
        
        // 本地脏 + 远端比本地新 = 冲突
        if dirtyEditors[path] == true && currentFileDate > remote {
            let conflict = ConflictInfo(
                path: path,
                localModified: remote,
                remoteModified: currentFileDate
            )
            return conflict
        }
        
        // 无冲突则更新时间戳
        remoteTimestamps[path] = currentFileDate
        return nil
    }
    
    // MARK: - 解决冲突
    
    public func resolve(path: String, keepLocal: Bool) {
        if keepLocal {
            // 保留本地：更新时间戳为当前
            remoteTimestamps[path] = Date()
        } else {
            // 使用远端：清脏标记
            dirtyEditors[path] = false
            remoteTimestamps[path] = Date()
        }
        
        conflicts.removeAll { $0.path == path }
        pendingConflict = nil
    }
}

// MARK: - 冲突提示视图（alert 内容）

public struct ConflictAlertContent: View {
    let conflict: ConflictInfo
    let onKeepLocal: () -> Void
    let onUseRemote: () -> Void
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("检测到文件冲突")
                    .font(.headline)
            }
            
            Text((conflict.path as NSString).lastPathComponent)
                .font(.subheadline)
                .fontWeight(.medium)
            
            Text("本地编辑时间：\(conflict.localModified.formatted(.dateTime.hour().minute().second()))")
                .font(.caption)
                .foregroundColor(.secondary)
            Text("文件修改时间：\(conflict.remoteModified.formatted(.dateTime.hour().minute().second()))")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(spacing: 12) {
                Button(action: onKeepLocal) {
                    Text("保留我的修改")
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                        .padding(8)
                        .background(Color.blue.opacity(0.15))
                        .foregroundColor(.blue)
                        .cornerRadius(8)
                }
                
                Button(action: onUseRemote) {
                    Text("使用最新文件")
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                        .padding(8)
                        .background(Color.orange.opacity(0.15))
                        .foregroundColor(.orange)
                        .cornerRadius(8)
                }
            }
        }
        .padding()
    }
}

#endif
