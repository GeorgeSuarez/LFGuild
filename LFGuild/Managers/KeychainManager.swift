//
//  KeychainManager.swift
//  LFGuild
//
//  Created by George Suarez on 8/1/25.
//

import Foundation

/// Stores the user's email in the Keychain for the "Remember Me" feature.
/// Passwords are intentionally not persisted; Firebase Auth handles secure token storage.
final class KeychainManager {
    private let service: String
    private let emailKey = "user_email"

    init(service: String = "LFGuild") {
        self.service = service
    }

    func store(email: String) throws {
        guard let emailData = email.data(using: .utf8) else {
            throw AuthenticationError.unknown("Failed to encode email")
        }

        try store(data: emailData, forKey: emailKey)
    }

    func getEmail() -> String? {
        return getString(for: emailKey)
    }

    func deleteEmail() {
        deleteItem(for: emailKey)
    }

    // MARK: - Private Helpers

    private func store(data: Data, forKey key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        if status == errSecDuplicateItem {
            // Item already exists — update it atomically instead of failing.
            let updateQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: key
            ]
            let updateAttributes: [String: Any] = [
                kSecValueData as String: data
            ]
            let updateStatus = SecItemUpdate(updateQuery as CFDictionary, updateAttributes as CFDictionary)
            guard updateStatus == errSecSuccess else {
                throw AuthenticationError.unknown("Failed to update keychain item: \(updateStatus)")
            }
        } else if status != errSecSuccess {
            throw AuthenticationError.unknown("Failed to store keychain item: \(status)")
        }
    }

    private func getString(for key: String) -> String? {
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
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return string
    }

    private func deleteItem(for key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        SecItemDelete(query as CFDictionary)
    }
}
