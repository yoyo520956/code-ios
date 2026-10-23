//
//  BuildStore.swift
//  Code
//

import Foundation
import Combine

@MainActor
class BuildStore: ObservableObject {
    @Published var buildStatus: BuildStatus = .idle
    @Published var buildProgress: Double = 0.0
    @Published var buildLogs: [BuildLogEntry] = []
    @Published var artifacts: [Artifact] = []
    @Published var currentTaskId: String?
    
    private var cancellables = Set<AnyCancellable>()
    private var buildTask: URLSessionDataTask?
    
    // MARK: - Public Methods
    
    func startBuild() async {
        guard buildStatus == .idle || buildStatus == .failed else { return }
        
        buildStatus = .running
        buildProgress = 0.0
        buildLogs.removeAll()
        
        // TODO: Implement actual build task
        // This will connect to cloud build server
        
        await simulateBuildProgress()
    }
    
    func cancelBuild() {
        buildTask?.cancel()
        buildStatus = .cancelled
    }
    
    func downloadArtifact(_ artifact: Artifact) async {
        // TODO: Download from cloud storage
    }
    
    // MARK: - Private Methods
    
    private func simulateBuildProgress() async {
        // Simulate build progress for POC
        for progress in stride(from: 0, to: 100, by: 5) {
            await MainActor.run {
                self.buildProgress = Double(progress) / 100.0
                self.addLog(.info("Building... \(progress)%"))
            }
            try? await Task.sleep(nanoseconds: 200_000_000) // 200ms
        }
        
        await MainActor.run {
            self.buildStatus = .success
            self.addLog(.success("Build completed successfully!"))
        }
    }
    
    private func addLog(_ entry: BuildLogEntry) {
        buildLogs.append(entry)
    }
}

// MARK: - Models

enum BuildStatus: String {
    case idle
    case running
    case success
    case failed
    case cancelled
    
    var icon: String {
        switch self {
        case .idle: return "play.circle"
        case .running: return "spinner"
        case .success: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        case .cancelled: return "stop.circle"
        }
    }
    
    var color: Color {
        switch self {
        case .idle: return .gray
        case .running: return .blue
        case .success: return .green
        case .failed: return .red
        case .cancelled: return .orange
        }
    }
}

struct BuildLogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let type: LogType
    let message: String
    
    enum LogType {
        case info, warning, error, success
        
        var icon: String {
            switch self {
            case .info: return "info.circle"
            case .warning: return "exclamation.triangle"
            case .error: return "xmark.circle"
            case .success: return "checkmark.circle"
            }
        }
        
        var color: Color {
            switch self {
            case .info: return .blue
            case .warning: return .orange
            case .error: return .red
            case .success: return .green
            }
        }
    }
}

struct Artifact: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    let size: Int
    let createdDate: Date
}

extension BuildLogEntry {
    static func info(_ message: String) -> BuildLogEntry {
        BuildLogEntry(timestamp: Date(), type: .info, message: message)
    }
    
    static func warning(_ message: String) -> BuildLogEntry {
        BuildLogEntry(timestamp: Date(), type: .warning, message: message)
    }
    
    static func error(_ message: String) -> BuildLogEntry {
        BuildLogEntry(timestamp: Date(), type: .error, message: message)
    }
    
    static func success(_ message: String) -> BuildLogEntry {
        BuildLogEntry(timestamp: Date(), type: .success, message: message)
    }
}
