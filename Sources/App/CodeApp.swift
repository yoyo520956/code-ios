import SwiftUI

#if canImport(UIKit)
// MARK: - App 入口（iOS 真机运行需要）
@main
struct CodeApp: App {
    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
    }
}
#endif
