//
//  ProjectStore.swift
//  Code
//

import Foundation
import Combine

@MainActor
class ProjectStore: ObservableObject {
    @Published var projects: [Project] = []
    @Published var currentProject: Project?
    @Published var files: [EditorFile] = []
    @Published var recentProjects: [String] = []
    
    private let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    private let projectsDir = URL(fileURLWithPath: "Projects")
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupNotifications()
        loadRecentProjects()
    }
    
    // MARK: - Public Methods
    
    func createProject(name: String, path: String) async throws {
        let project = Project(
            name: name,
            path: path,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        projects.append(project)
        currentProject = project
        
        try await saveProject(project)
        await loadProjectFiles(project)
    }
    
    func openProject(at path: String) async throws {
        let project = try await loadProject(from: path)
        currentProject = project
        try await loadProjectFiles(project)
        addToRecentProjects(path)
    }
    
    func loadProjectFiles(_ project: Project) async throws {
        let url = URL(fileURLWithPath: project.path)
        let contents = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
        
        files = contents
            .filter { $0.pathExtension != "xcassets" && $0.pathExtension != "xcodeproj" }
            .map { path in
                EditorFile(
                    name: path.lastPathComponent,
                    path: path.path,
                    size: (try? FileManager.default.attributesOfItem(atPath: path.path)[.size] as? Int) ?? 0,
                    modifiedDate: (try? FileManager.default.attributesOfItem(atPath: path.path)[.modificationDate] as? Date) ?? Date()
                )
            }
            .sorted { $0.name < $1.name }
    }
    
    func deleteProject(_ project: Project) async throws {
        try? FileManager.default.removeItem(at: URL(fileURLWithPath: project.path))
        projects.removeAll { $0.id == project.id }
        if currentProject?.id == project.id {
            currentProject = nil
            files.removeAll()
        }
    }
    
    // MARK: - Private Methods
    
    private func saveProject(_ project: Project) async throws {
        let data = try JSONEncoder().encode(project)
        let url = documentsURL.appendingPathComponent("projects.json")
        try data.write(to: url)
    }
    
    private func loadProject(from path: String) async throws -> Project {
        let url = URL(fileURLWithPath: path)
        let project = Project(
            name: url.lastPathComponent,
            path: path,
            createdAt: (try? FileManager.default.attributesOfItem(atPath: path)[.creationDate] as? Date) ?? Date(),
            updatedAt: Date()
        )
        return project
    }
    
    private func loadRecentProjects() {
        if let data = UserDefaults.standard.data(forKey: "recentProjects"),
           let paths = try? JSONDecoder().decode([String].self, from: data) {
            recentProjects = paths
        }
    }
    
    private func addToRecentProjects(_ path: String) {
        recentProjects.removeAll { $0 == path }
        recentProjects.insert(path, at: 0)
        recentProjects = Array(recentProjects.prefix(10))
        
        if let data = try? JSONEncoder().encode(recentProjects) {
            UserDefaults.standard.set(data, forKey: "recentProjects")
        }
    }
    
    private func setupNotifications() {
        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.saveCurrentState()
            }
            .store(in: &cancellables)
    }
    
    private func saveCurrentState() {
        // Save current project state
        if let project = currentProject {
            var p = project
            p.updatedAt = Date()
            currentProject = p
        }
    }
}

// MARK: - Models

struct Project: Identifiable, Codable {
    let id: UUID
    let name: String
    let path: String
    let createdAt: Date
    let updatedAt: Date
    
    init(name: String, path: String, createdAt: Date, updatedAt: Date) {
        self.id = UUID()
        self.name = name
        self.path = path
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct EditorFile: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let path: String
    let size: Int
    let modifiedDate: Date
    
    static func == (lhs: EditorFile, rhs: EditorFile) -> Bool {
        lhs.id == rhs.id
    }
}
