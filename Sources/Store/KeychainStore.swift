import Foundation
import Security

#if canImport(UIKit)

// MARK: - Keychain 安全存储
// API Key / Token 等敏感信息存 Keychain（iOS 系统加密），不用 UserDefaults 明文

public final class KeychainStore {
    public static let shared = KeychainStore()
    
    private let service = "com.code.app.keychain"
    
    private init() {}
    
    @discardableResult
    public func get(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        guard status == errSecSuccess, let data = item as? Data else {
            return nil
        }
        
        return String(data: data, encoding: .utf8)
    }
    
    @discardableResult
    public func set(_ value: String, for key: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(deleteQuery as CFDictionary)
        
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    @discardableResult
    public func delete(_ key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
    
    public func setAIKey(_ key: String, providerId: UUID) -> Bool {
        set(key, for: "ai.provider.\(providerId.uuidString)")
    }
    
    public func getAIKey(providerId: UUID) -> String? {
        get("ai.provider.\(providerId.uuidString)")
    }
    
    public func deleteAIKey(providerId: UUID) -> Bool {
        delete("ai.provider.\(providerId.uuidString)")
    }
}

#endif
