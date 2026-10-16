import Foundation
import Security

/// Stores the Gemini API key in the iOS Keychain rather than in
/// UserDefaults or the app bundle. The key never reaches the repository
/// or the IPA; it is typed on the device and stays there.
enum KeychainStore {
    private static let service = "com.vytr.app"
    private static let account = "gemini-api-key"

    enum Failure: LocalizedError {
        case status(OSStatus)

        var errorDescription: String? {
            switch self {
            case .status(let code):
                return "Keychain error \(code)."
            }
        }
    }

    private static var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }

    static func save(_ value: String) throws {
        SecItemDelete(baseQuery as CFDictionary)

        var attributes = baseQuery
        attributes[kSecValueData as String] = Data(value.utf8)
        // Readable after the first unlock, and never synced off this device.
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else { throw Failure.status(status) }
    }

    static func read() -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8),
              !value.isEmpty
        else { return nil }

        return value
    }

    @discardableResult
    static func delete() -> Bool {
        SecItemDelete(baseQuery as CFDictionary) == errSecSuccess
    }

    static var hasKey: Bool { read() != nil }
}
