import Foundation
import Security

/// Simple Keychain wrapper for storing and loading raw key bytes.
public enum KeychainService {

    public enum KeychainError: Error {
        case saveFailed(OSStatus)
        case loadFailed(OSStatus)
        case deleteFailed(OSStatus)
        case unexpectedData
    }

    // MARK: - Save

    public static func save(_ data: Data, account: String) throws {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: account,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData: data
        ]
        // Delete existing entry first to allow updates
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.saveFailed(status) }
    }

    // MARK: - Load

    public static func load(account: String) throws -> Data {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { throw KeychainError.loadFailed(status) }
        guard let data = result as? Data else { throw KeychainError.unexpectedData }
        return data
    }

    // MARK: - Delete

    public static func delete(account: String) throws {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }
}

// MARK: - Keychain account key constants

public extension KeychainService {
    /// Account key for the X25519 agreement private key.
    static let agreementPrivateKeyAccount = "com.driftsonar.key.agreement"
    /// Account key for the Ed25519 signing private key.
    static let signingPrivateKeyAccount   = "com.driftsonar.key.signing"
}
