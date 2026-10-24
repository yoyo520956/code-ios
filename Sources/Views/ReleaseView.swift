import Foundation
import Combine
import SwiftUI

#if canImport(UIKit)

// MARK: - IPA 下载服务
// 从 GitHub Release 下载最新 IPA 到本地（供分享/安装）

public struct ReleaseInfo: Identifiable, Equatable {
    public let id: Int
    public let tagName: String
    public let name: String
    public let publishedAt: Date
    public let ipaURL: String?
    public let ipaSize: Int64
    
    public init(id: Int, tagName: String, name: String, publishedAt: Date, ipaURL: String?, ipaSize: Int64) {
        self.id = id
        self.tagName = tagName
        self.name = name
        self.publishedAt = publishedAt
        self.ipaURL = ipaURL
        self.ipaSize = ipaSize
    }
    
    public static func == (lhs: ReleaseInfo, rhs: ReleaseInfo) -> Bool {
        lhs.id == rhs.id
    }
    
    var sizeDescription: String {
        ByteCountFormatter.string(fromByteCount: ipaSize, countStyle: .file)
    }
}

public final class ReleaseService: ObservableObject {
    public static let shared = ReleaseService()
    
    @Published public var releases: [ReleaseInfo] = []
    @Published public var isLoading = false
    @Published public var isDownloading = false
    @Published public var downloadProgress: Double = 0
    @Published public var lastError: String?
    @Published public var downloadedFilePath: String?
    
    private let client = GitHubClient.shared
    private let owner = "yoyo520956"
    private let repo = "code-ios"
    
    private init() {}
    
    public func setToken(_ token: String) {
        client.setToken(token)
    }
    
    // MARK: - 拉取 Release 列表
    
    public func fetchReleases() async {
        await MainActor.run {
            isLoading = true
            lastError = nil
        }
        
        do {
            guard let url = URL(string: "https://api.github.com/repos/\(owner)/\(repo)/releases?per_page=10") else {
                throw GitHubError.invalidURL
            }
            var request = URLRequest(url: url)
            request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
            
            let (data, _) = try await URLSession.shared.data(for: request)
            let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] ?? []
            
            let items: [ReleaseInfo] = json.compactMap { rel in
                guard let id = rel["id"] as? Int,
                      let tag = rel["tag_name"] as? String else { return nil }
                let name = rel["name"] as? String ?? tag
                let published = ISO8601DateFormatter().date(from: rel["published_at"] as? String ?? "") ?? Date()
                
                // 找 ipa asset
                let assets = rel["assets"] as? [[String: Any]] ?? []
                let ipa = assets.first { ($0["name"] as? String)?.hasSuffix(".ipa") == true }
                
                return ReleaseInfo(
                    id: id,
                    tagName: tag,
                    name: name,
                    publishedAt: published,
                    ipaURL: ipa?["browser_download_url"] as? String,
                    ipaSize: ipa?["size"] as? Int64 ?? 0
                )
            }
            
            await MainActor.run {
                releases = items
                isLoading = false
            }
        } catch {
            await MainActor.run {
                lastError = error.localizedDescription
                isLoading = false
            }
        }
    }
    
    // MARK: - 下载 IPA
    
    public func downloadIPA(_ release: ReleaseInfo) async {
        guard let urlString = release.ipaURL, let url = URL(string: urlString) else {
            await MainActor.run { lastError = "该 Release 没有 IPA 附件" }
            return
        }
        
        await MainActor.run {
            isDownloading = true
            downloadProgress = 0
            lastError = nil
        }
        
        do {
            let (tempURL, response) = try await URLSession.shared.download(from: url)
            
            // 保存到 Documents
            let fileName = "Code-\(release.tagName).ipa"
            let destURL = FileSystemService.shared.documentsURL.appendingPathComponent(fileName)
            
            // 删除旧文件
            try? FileManager.default.removeItem(at: destURL)
            try FileManager.default.moveItem(at: tempURL, to: destURL)
            
            await MainActor.run {
                isDownloading = false
                downloadProgress = 1.0
                downloadedFilePath = destURL.path
            }
        } catch {
            await MainActor.run {
                isDownloading = false
                lastError = error.localizedDescription
            }
        }
    }
}

// MARK: - IPA 下载视图

public struct ReleaseView: View {
    @ObservedObject private var service = ReleaseService.shared
    
    public init() {}
    
    public var body: some View {
        List {
            Section(
                header: Text("自动构建版本"),
                footer: Text("下载 IPA 后通过分享面板安装（Feather 签名）")
            ) {
                if service.isLoading {
                    HStack {
                        ProgressView()
                        Text("加载 Release...")
                            .foregroundColor(.secondary)
                    }
                } else if let error = service.lastError {
                    Text("错误：\(error)")
                        .font(.caption)
                        .foregroundColor(.red)
                } else if service.releases.isEmpty {
                    Text("暂无 Release")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(service.releases) { release in
                        ReleaseRow(release: release, service: service)
                    }
                }
            }
            
            // 已下载的 IPA
            Section(header: Text("已下载")) {
                if let path = service.downloadedFilePath {
                    ShareLink(item: URL(fileURLWithPath: path)) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(.blue)
                            Text("分享 IPA 安装包")
                        }
                    }
                } else {
                    Text("下载后可在此分享")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("IPA 下载")
        .onAppear {
            Task { await service.fetchReleases() }
        }
        .refreshable {
            await service.fetchReleases()
        }
    }
}

struct ReleaseRow: View {
    let release: ReleaseInfo
    @ObservedObject var service: ReleaseService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "shippingbox")
                    .foregroundColor(.green)
                Text(release.tagName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text(release.publishedAt.formatted(.dateTime.month().day().hour().minute()))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            if let url = release.ipaURL {
                Button(action: {
                    Task { await service.downloadIPA(release) }
                }) {
                    HStack {
                        if service.isDownloading {
                            ProgressView()
                                .scaleEffect(0.7)
                            Text("下载中...")
                                .font(.caption)
                        } else {
                            Image(systemName: "icloud.and.arrow.down")
                                .font(.caption)
                            Text("下载 IPA（\(release.sizeDescription)）")
                                .font(.caption)
                        }
                    }
                    .foregroundColor(.blue)
                }
                .disabled(service.isDownloading)
            } else {
                Text("无 IPA 附件")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

#endif
