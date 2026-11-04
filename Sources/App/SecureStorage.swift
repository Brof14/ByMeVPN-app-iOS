import Foundation
import Security

/// Secrets are stored only in Keychain. App Group receives a short-lived tunnel
/// config, never account access/refresh tokens.
final class SecureStorage {
    static let shared = SecureStorage()
    private let service = "com.bymevpn.ios.credentials"
    private let lock = NSLock()
    private init() {}

    private func read(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func put(_ value: String?, for key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
        guard let value else { return }
        var item = query
        item[kSecValueData as String] = Data(value.utf8)
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(item as CFDictionary, nil)
    }

    var accessToken: String? { lock.lock(); defer { lock.unlock() }; return read("access") }
    var refreshToken: String? { lock.lock(); defer { lock.unlock() }; return read("refresh") }

    var installID: String {
        lock.lock()
        defer { lock.unlock() }
        if let id = read("install-id"), !id.isEmpty { return id }
        let id = UUID().uuidString.lowercased()
        put(id, for: "install-id")
        return id
    }

    func setTokens(access: String, refresh: String) {
        lock.lock(); defer { lock.unlock() }
        put(access, for: "access")
        put(refresh, for: "refresh")
    }

    func clearSession() {
        lock.lock(); defer { lock.unlock() }
        put(nil, for: "access")
        put(nil, for: "refresh")
        // Keep install-id stable for device counting and trial eligibility.
    }
}
