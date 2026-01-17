//
//  KeychainManager.swift
//  FitCat
//
//  Secure credential storage using iOS Keychain
//

import Foundation
import Security

class KeychainManager {
    static let shared = KeychainManager()

    private let service = "com.yourname.fitcat"

    private init() {}

    // MARK: - Save

    func save(key: String, value: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }

        // Delete any existing item first
        delete(key: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    // MARK: - Retrieve

    func retrieve(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }

        return value
    }

    // MARK: - Delete

    func delete(key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    // MARK: - OpenPetFoodFacts Credentials

    private let usernameKey = "openpetfoodfacts_username"
    private let passwordKey = "openpetfoodfacts_password"

    var openPetFoodFactsUsername: String? {
        get { retrieve(key: usernameKey) }
        set {
            if let value = newValue {
                _ = save(key: usernameKey, value: value)
            } else {
                _ = delete(key: usernameKey)
            }
        }
    }

    var openPetFoodFactsPassword: String? {
        get { retrieve(key: passwordKey) }
        set {
            if let value = newValue {
                _ = save(key: passwordKey, value: value)
            } else {
                _ = delete(key: passwordKey)
            }
        }
    }

    var hasOpenPetFoodFactsCredentials: Bool {
        openPetFoodFactsUsername != nil && openPetFoodFactsPassword != nil
    }
}
