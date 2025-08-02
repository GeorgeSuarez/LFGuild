//
//  KeychainManager.swift
//  LFGuild
//
//  Created by George Suarez on 8/1/25.
//

import Foundation
import SwiftUI

class KeychainManager {
    private let service = "LFGuild"
    private let emailKey = "user_email"
    private let passwordKey = "user_password"
    
    struct Credentials {
        let email: String
        let password: String
    }
    
    func store(email: String, password: String) throws {
        let emailData = email.data(using: .utf8)!
        let passwordData = password.data(using: .utf8)!
        
        let emailQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: emailKey,
            kSecValueData as String: emailData
        ]
        
        SecItemDelete(emailQuery as CFDictionary)
        let emailStatus = SecItemAdd(emailQuery as CFDictionary, nil)
        
        let passwordQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: passwordKey,
            kSecValueData as String: passwordData
        ]
        
        SecItemDelete(passwordQuery as CFDictionary)
        let passwordStatus = SecItemAdd(passwordQuery as CFDictionary, nil)
        
        guard emailStatus == errSecSuccess && passwordStatus == errSecSuccess else {
            throw AuthenticationError.unknown("Failed to store credentials")
        }
    }
    
    func getCredentials() -> Credentials? {
        guard let email = getString(for: emailKey),
            let password = getString(for: passwordKey) else {
            return nil
        }
        
        return Credentials(email: email, password: password)
    }
    
    func deleteCrendentials() {
        deleteItem(for: emailKey)
        deleteItem(for: passwordKey)
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

