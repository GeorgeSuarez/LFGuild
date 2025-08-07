//
//  BattleNetAPIManager.swift
//  LFGuild
//
//  Created by George Suarez on 8/6/25.
//

import Foundation
import AuthenticationServices
import SwiftUI

// MARK: - Models
struct BattleNetToken: Codable {
    let accessToken: String
    let tokenType: String
    let expiresIn: Int
    let scope: String
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case scope
    }
}

struct WoWCharacter: Codable, Identifiable {
    let id: Int
    let name: String
    let realm: WoWRealm
    let level: Int
    let characterClass: WoWClass
    let race: WoWRace
    let gender: WoWGender
    let faction: WoWFaction
    let guild: WoWGuildSummary?
    
    enum CodingKeys: String, CodingKey {
        case id, name, realm, level
        case characterClass = "playable_class"
        case race = "playable_race"
        case gender, faction, guild
    }
}

struct WoWRealm: Codable {
    let id: Int
    let name: String
    let slug: String
}

struct WoWClass: Codable {
    let id: Int
    let name: String
}

struct WoWRace: Codable {
    let id: Int
    let name: String
}

struct WoWGender: Codable {
    let type: String
    let name: String
}

struct WoWFaction: Codable {
    let type: String
    let name: String
}

struct WoWGuildSummary: Codable {
    let id: Int
    let name: String
    let realm: WoWRealm
}

struct WoWGuild: Codable {
    let id: Int
    let name: String
    let faction: WoWFaction
    let achievementPoints: Int
    let memberCount: Int
    let realm: WoWRealm
    let createdTimestamp: Int
    let roster: [WoWGuildMember]?
    
    enum CodingKeys: String, CodingKey {
        case id, name, faction
        case achievementPoints = "achievement_points"
        case memberCount = "member_count"
        case realm
        case createdTimestamp = "created_timestamp"
        case roster
    }
}

struct WoWGuildMember: Codable {
    let character: WoWCharacterSummary
    let rank: Int
}

struct WoWCharacterSummary: Codable {
    let id: Int
    let name: String
    let realm: WoWRealm
    let level: Int
}

struct WoWProfile: Codable {
    let id: Int
    let wowAccounts: [WoWAccount]
    
    enum CodingKeys: String, CodingKey {
        case id
        case wowAccounts = "wow_accounts"
    }
}

struct WoWAccount: Codable {
    let id: Int
    let characters: [WoWCharacter]
}

// MARK: - Error Types
enum BattleNetError: LocalizedError {
    case invalidURL
    case invalidToken
    case networkError(String)
    case decodingError(String)
    case authenticationRequired
    case tokenExpired
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL configuration"
        case .invalidToken:
            return "Invalid or expired access token"
        case .networkError(let message):
            return "Network error: \(message)"
        case .decodingError(let message):
            return "Failed to decode response: \(message)"
        case .authenticationRequired:
            return "Battle.net authentication required"
        case .tokenExpired:
            return "Access token has expired. Please reconnect your Battle.net account"
        }
    }
}

// MARK: - Authentication Context Helper
class AuthenticationContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return ASPresentationAnchor()
    }
}

// MARK: - API Manager
@MainActor
class BattleNetAPIManager: NSObject, ObservableObject {
    static let shared = BattleNetAPIManager()
    
    @Published var isAuthenticated = false
    @Published var currentProfile: WoWProfile?
    @Published var userCharacters: [WoWCharacter] = []
    @Published var isLoading = false
    @Published var error: BattleNetError?
    
    private var authSession: ASWebAuthenticationSession?
    private let keychain = KeychainManager()
    private let tokenKey = "battlenet_access_token"
    private let tokenExpiryKey = "battlenet_token_expiry"
    private let authContextProvider = AuthenticationContextProvider()
    
    override init() {
        super.init()
        checkAuthenticationStatus()
    }
    
    // MARK: - Authentication
    func authenticate() async throws {
        let state = UUID().uuidString
        
        var components = URLComponents(string: BattleNetConfig.authorizationURL)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: BattleNetConfig.clientID),
            URLQueryItem(name: "redirect_uri", value: BattleNetConfig.redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: BattleNetConfig.scopes),
            URLQueryItem(name: "state", value: state)
        ]
        
        guard let authURL = components.url else {
            throw BattleNetError.invalidURL
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            authSession = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: "lfguild"
            ) { [weak self] callbackURL, error in
                guard let self = self else { return }
                
                if let error = error {
                    if (error as NSError).code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                        continuation.resume(throwing: BattleNetError.authenticationRequired)
                    } else {
                        continuation.resume(throwing: BattleNetError.networkError(error.localizedDescription))
                    }
                    return
                }
                
                guard let callbackURL = callbackURL,
                      let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
                      let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
                    continuation.resume(throwing: BattleNetError.invalidURL)
                    return
                }
                
                Task {
                    do {
                        try await self.exchangeCodeForToken(code)
                        continuation.resume()
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
            
            authSession?.presentationContextProvider = authContextProvider
            authSession?.prefersEphemeralWebBrowserSession = false
            
            if !authSession!.start() {
                continuation.resume(throwing: BattleNetError.authenticationRequired)
            }
        }
    }
    
    
    private func exchangeCodeForToken(_ code: String) async throws {
        var request = URLRequest(url: URL(string: BattleNetConfig.tokenURL)!)
        request.httpMethod = "POST"
        
        let credentials = "\(BattleNetConfig.clientID):\(BattleNetConfig.clientSecret)"
        let credentialsData = credentials.data(using: .utf8)!
        let base64Credentials = credentialsData.base64EncodedString()
        
        request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "grant_type", value: "authorization_code"),
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "redirect_uri", value: BattleNetConfig.redirectURI)
        ]
        
        request.httpBody = components.query?.data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw BattleNetError.networkError("Failed to exchange code for token")
        }
        
        let token = try JSONDecoder().decode(BattleNetToken.self, from: data)
        try saveToken(token)
        isAuthenticated = true
        
        // Fetch user profile after successful authentication
        try await fetchUserProfile()
    }
    
    private func saveToken(_ token: BattleNetToken) throws {
        // Save token to keychain
        let tokenData = token.accessToken.data(using: .utf8)!
        let tokenQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "LFGuild",
            kSecAttrAccount as String: tokenKey,
            kSecValueData as String: tokenData
        ]
        
        SecItemDelete(tokenQuery as CFDictionary)
        let status = SecItemAdd(tokenQuery as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw BattleNetError.networkError("Failed to save token")
        }
        
        // Save expiry time
        let expiryTime = Date().addingTimeInterval(TimeInterval(token.expiresIn))
        UserDefaults.standard.set(expiryTime, forKey: tokenExpiryKey)
    }
    
    func getAccessToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "LFGuild",
            kSecAttrAccount as String: tokenKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        // Check if token is expired
        if let expiryTime = UserDefaults.standard.object(forKey: tokenExpiryKey) as? Date,
           Date() > expiryTime {
            disconnect()
            return nil
        }
        
        return token
    }
    
    func checkAuthenticationStatus() {
        isAuthenticated = getAccessToken() != nil
        
        if isAuthenticated {
            Task {
                try? await fetchUserProfile()
            }
        }
    }
    
    func disconnect() {
        // Remove token from keychain
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "LFGuild",
            kSecAttrAccount as String: tokenKey
        ]
        
        SecItemDelete(query as CFDictionary)
        
        // Clear expiry time
        UserDefaults.standard.removeObject(forKey: tokenExpiryKey)
        
        // Reset state
        isAuthenticated = false
        currentProfile = nil
        userCharacters = []
    }
    
    // MARK: - API Calls
    func fetchUserProfile() async throws {
        guard let token = getAccessToken() else {
            throw BattleNetError.authenticationRequired
        }
        
        isLoading = true
        defer { isLoading = false }
        
        let url = URL(string: "\(BattleNetConfig.oauthBaseURL)/userinfo")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 401 {
                disconnect()
                throw BattleNetError.tokenExpired
            }
            throw BattleNetError.networkError("Failed to fetch user profile")
        }
        
        // Get WoW profile
        try await fetchWoWProfile()
    }
    
    func fetchWoWProfile() async throws {
        guard let token = getAccessToken() else {
            throw BattleNetError.authenticationRequired
        }
        
        let url = URL(string: "\(BattleNetConfig.apiBaseURL)/profile/user/wow?namespace=profile-us&locale=en_US")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw BattleNetError.networkError("Failed to fetch WoW profile")
        }
        
        do {
            let profile = try JSONDecoder().decode(WoWProfile.self, from: data)
            currentProfile = profile
            
            // Flatten all characters from all WoW accounts
            userCharacters = profile.wowAccounts.flatMap { $0.characters }
        } catch {
            throw BattleNetError.decodingError(error.localizedDescription)
        }
    }
    
    func fetchGuild(realmSlug: String, guildName: String) async throws -> WoWGuild {
        guard let token = getAccessToken() else {
            throw BattleNetError.authenticationRequired
        }
        
        let encodedGuildName = guildName.lowercased().replacingOccurrences(of: " ", with: "-")
        let url = URL(string: "\(BattleNetConfig.apiBaseURL)/data/wow/guild/\(realmSlug)/\(encodedGuildName)?namespace=profile-us&locale=en_US")!
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw BattleNetError.networkError("Failed to fetch guild data")
        }
        
        return try JSONDecoder().decode(WoWGuild.self, from: data)
    }
    
    func fetchGuildRoster(realmSlug: String, guildName: String) async throws -> [WoWGuildMember] {
        guard let token = getAccessToken() else {
            throw BattleNetError.authenticationRequired
        }
        
        let encodedGuildName = guildName.lowercased().replacingOccurrences(of: " ", with: "-")
        let url = URL(string: "\(BattleNetConfig.apiBaseURL)/data/wow/guild/\(realmSlug)/\(encodedGuildName)/roster?namespace=profile-us&locale=en_US")!
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw BattleNetError.networkError("Failed to fetch guild roster")
        }
        
        struct RosterResponse: Codable {
            let members: [WoWGuildMember]
        }
        
        let roster = try JSONDecoder().decode(RosterResponse.self, from: data)
        return roster.members
    }
    
    func searchGuilds(name: String? = nil, realm: String? = nil) async throws -> [WoWGuild] {
        // Note: Battle.net API doesn't have a direct guild search endpoint
        // You would typically need to implement this through your own backend
        // that aggregates guild data or use the guild finder endpoints
        
        // This is a placeholder for where you'd implement guild search
        return []
    }
}
