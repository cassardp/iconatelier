import Foundation
import Security

/// Stores the per-project delete token in the Keychain, keyed by project UUID.
/// Kept out of `IconProject` on purpose: the token must never end up in the
/// public bundle uploaded to the gallery. Also holds the gallery admin token
/// used for moderation, under a fixed account.
actor CommunityCredentialStore {
    static let shared = CommunityCredentialStore()

    private let service = "com.iconatelier.gallery"
    private let adminAccount = "admin-token"

    func token(for uuid: UUID) -> String? { value(forAccount: uuid.uuidString) }

    @discardableResult
    func save(_ token: String, for uuid: UUID) -> Bool { save(token, forAccount: uuid.uuidString) }

    @discardableResult
    func delete(for uuid: UUID) -> Bool { delete(forAccount: uuid.uuidString) }

    func adminToken() -> String? { value(forAccount: adminAccount) }

    @discardableResult
    func saveAdminToken(_ token: String) -> Bool { save(token, forAccount: adminAccount) }

    @discardableResult
    func clearAdminToken() -> Bool { delete(forAccount: adminAccount) }

    private func value(forAccount account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let string = String(data: data, encoding: .utf8) else { return nil }
        return string
    }

    @discardableResult
    private func save(_ token: String, forAccount account: String) -> Bool {
        let data = Data(token.utf8)
        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        var addQuery = baseQuery
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly

        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        switch addStatus {
        case errSecSuccess:
            return true
        case errSecDuplicateItem:
            let attrs: [String: Any] = [kSecValueData as String: data]
            return SecItemUpdate(baseQuery as CFDictionary, attrs as CFDictionary) == errSecSuccess
        default:
            return false
        }
    }

    @discardableResult
    private func delete(forAccount account: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
