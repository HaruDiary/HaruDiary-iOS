import Foundation
import Security

/// Generic passwords in the app's Keychain, readable only on this device after the first unlock
/// (not included in backups or moved to another device).
final class KeychainSecretStore: SecretStore {
    private let service: String

    init(service: String = (Bundle.main.bundleIdentifier ?? "EveryDiary") + ".secrets") {
        self.service = service
    }

    func string(for key: String) -> String? {
        var query = baseQuery(key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func set(_ value: String, for key: String) throws {
        let data = Data(value.utf8)
        let update: [String: Any] = [kSecValueData as String: data,
                                     kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]
        var status = SecItemUpdate(baseQuery(key) as CFDictionary, update as CFDictionary)
        if status == errSecItemNotFound {
            var add = baseQuery(key)
            add.merge(update) { $1 }
            status = SecItemAdd(add as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw KeychainError(status: status) }
    }

    func remove(_ key: String) {
        SecItemDelete(baseQuery(key) as CFDictionary)
    }

    private func baseQuery(_ key: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: key]
    }
}

struct KeychainError: Error {
    let status: OSStatus
}
