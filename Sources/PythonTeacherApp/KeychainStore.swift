import Foundation
import PythonTeacherCore
import Security

struct KeychainStore {
    var service = "local.pythonteacher.openai"
    /// Service used while the app was named Coding Teacher.
    var legacyService = "local.codingteacher.openai"
    private let account = "personal-api-key"

    /// Each provider keeps its own Keychain item; the OpenAI item keeps its original service name.
    static func provider(_ provider: TeacherProvider) -> KeychainStore {
        KeychainStore(service: "local.pythonteacher.\(provider.rawValue)")
    }

    func load() throws -> String? {
        try load(service: service)
    }

    func save(_ key: String) throws {
        let value = Data(key.trimmingCharacters(in: .whitespacesAndNewlines).utf8)
        let status = SecItemUpdate(query(service) as CFDictionary, [kSecValueData as String: value] as CFDictionary)
        if status == errSecItemNotFound {
            var query = query(service)
            query[kSecValueData as String] = value
            query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            let added = SecItemAdd(query as CFDictionary, nil)
            guard added == errSecSuccess else { throw KeychainError(status: added) }
        } else if status != errSecSuccess {
            throw KeychainError(status: status)
        }
    }

    func remove() throws {
        try remove(service: service)
    }

    /// Moves an API key saved under the legacy service when no current key exists.
    /// The legacy item is deleted only after the current item was saved.
    func migrateLegacyItem() throws {
        guard try load(service: service) == nil, let key = try load(service: legacyService) else { return }
        try save(key)
        try remove(service: legacyService)
    }

    private func load(service: String) throws -> String? {
        var query = query(service)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else { throw KeychainError(status: status) }
        return String(data: data, encoding: .utf8)
    }

    private func remove(service: String) throws {
        let status = SecItemDelete(query(service) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw KeychainError(status: status) }
    }

    private func query(_ service: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account]
    }
}

struct KeychainError: LocalizedError {
    let status: OSStatus
    var errorDescription: String? { "macOS Keychain could not complete this operation (\(status)). Check the app's Keychain access permission." }
}
