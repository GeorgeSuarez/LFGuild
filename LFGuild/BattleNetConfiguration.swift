//
//  BattleNetConfiguration.swift
//  LFGuild
//
//  Created by George Suarez on 8/6/25.
//

import Foundation

import SwiftUI

// MARK: - Configuration Service
class BattleNetConfigurationService: ObservableObject {
    static let shared = BattleNetConfigurationService()
    
    @Published var isConfigured = false
    private var configuration: BattleNetConfiguration?
    
    private init() {
        loadConfiguration()
    }
    
    struct BattleNetConfiguration: Codable {
        let clientID: String
        let clientSecret: String
        let redirectURI: String
        let apiBaseURL: String
        let oauthBaseURL: String
        let authorizationURL: String
        let tokenURL: String
        let scopes: String
        let region: String
    }
    
    private func loadConfiguration() {
        #if DEBUG
        // Development: Use environment variables or local config
        loadDevelopmentConfig()
        #else
        // Production: Fetch from secure backend
        Task {
            await loadProductionConfig()
        }
        #endif
    }
    
    private func loadDevelopmentConfig() {
        // Try environment variables first
        if let clientID = ProcessInfo.processInfo.environment["BATTLENET_CLIENT_ID"],
           let clientSecret = ProcessInfo.processInfo.environment["BATTLENET_CLIENT_SECRET"] {
            
            let region = ProcessInfo.processInfo.environment["BATTLENET_REGION"] ?? "us"
            
            configuration = BattleNetConfiguration(
                clientID: clientID,
                clientSecret: clientSecret,
                redirectURI: "lfguild://oauth/battlenet",
                apiBaseURL: "https://\(region).api.blizzard.com",
                oauthBaseURL: "https://\(region).battle.net/oauth",
                authorizationURL: "https://\(region).battle.net/oauth/authorize",
                tokenURL: "https://\(region).battle.net/oauth/token",
                scopes: "wow.profile",
                region: region
            )
            isConfigured = true
        } else {
            // Fallback to local config file (not in repo)
            loadLocalConfigFile()
        }
    }
    
    private func loadLocalConfigFile() {
        // Look for a local config file that's not committed to git
        guard let configURL = Bundle.main.url(forResource: "BattleNetConfig", withExtension: "plist"),
              let configData = try? Data(contentsOf: configURL),
              let config = try? PropertyListSerialization.propertyList(from: configData, format: nil) as? [String: Any] else {
            
            print("⚠️ Battle.net configuration not found. Please set up environment variables or create BattleNetConfig.plist")
            return
        }
        
        if let clientID = config["clientID"] as? String,
           let clientSecret = config["clientSecret"] as? String {
            
            let region = config["region"] as? String ?? "us"
            
            configuration = BattleNetConfiguration(
                clientID: clientID,
                clientSecret: clientSecret,
                redirectURI: "lfguild://oauth/battlenet",
                apiBaseURL: "https://\(region).api.blizzard.com",
                oauthBaseURL: "https://\(region).battle.net/oauth",
                authorizationURL: "https://\(region).battle.net/oauth/authorize",
                tokenURL: "https://\(region).battle.net/oauth/token",
                scopes: "wow.profile",
                region: region
            )
            isConfigured = true
        }
    }
    
    private func loadProductionConfig() async {
        // In production, fetch configuration from your secure backend
        // This keeps sensitive credentials out of the app binary
        
        guard let url = URL(string: "https://your-backend.com/api/config/battlenet") else { return }
        
        do {
            var request = URLRequest(url: url)
            request.setValue("Bearer \(getAppToken())", forHTTPHeaderField: "Authorization")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                print("Failed to fetch configuration")
                return
            }
            
            let config = try JSONDecoder().decode(BattleNetConfiguration.self, from: data)
            await MainActor.run {
                self.configuration = config
                self.isConfigured = true
            }
        } catch {
            print("Error loading production config: \(error)")
        }
    }
    
    private func getAppToken() -> String {
        // Get app-level authentication token for your backend
        // This could be from Firebase Auth, your own auth system, etc.
        return "app-token"
    }
    
    // MARK: - Public Accessors
    var clientID: String {
        configuration?.clientID ?? ""
    }
    
    var clientSecret: String {
        configuration?.clientSecret ?? ""
    }
    
    var redirectURI: String {
        configuration?.redirectURI ?? "lfguild://oauth/battlenet"
    }
    
    var apiBaseURL: String {
        configuration?.apiBaseURL ?? "https://us.api.blizzard.com"
    }
    
    var oauthBaseURL: String {
        configuration?.oauthBaseURL ?? "https://us.battle.net/oauth"
    }
    
    var authorizationURL: String {
        configuration?.authorizationURL ?? "https://us.battle.net/oauth/authorize"
    }
    
    var tokenURL: String {
        configuration?.tokenURL ?? "https://us.battle.net/oauth/token"
    }
    
    var scopes: String {
        configuration?.scopes ?? "wow.profile"
    }
    
    var region: String {
        configuration?.region ?? "us"
    }
}

// MARK: - Updated BattleNetConfig using Configuration Service
struct BattleNetConfig {
    private static let service = BattleNetConfigurationService.shared
    
    static var clientID: String { service.clientID }
    static var clientSecret: String { service.clientSecret }
    static var redirectURI: String { service.redirectURI }
    static var authorizationURL: String { service.authorizationURL }
    static var tokenURL: String { service.tokenURL }
    static var apiBaseURL: String { service.apiBaseURL }
    static var oauthBaseURL: String { service.oauthBaseURL }
    static var scopes: String { service.scopes }
}

// MARK: - Backend Token Exchange Service (Most Secure)
class BattleNetBackendService {
    static let shared = BattleNetBackendService()
    
    private let baseURL = "https://your-backend.com/api/battlenet"
    
    /// Initiates OAuth flow through your backend (most secure)
    func authenticateViaBackend() async throws -> String {
        // 1. Get session token from your backend
        let sessionToken = try await createAuthSession()
        
        // 2. Open Battle.net OAuth with session token
        let authURL = "\(BattleNetConfig.authorizationURL)?client_id=\(BattleNetConfig.clientID)&redirect_uri=\(BattleNetConfig.redirectURI)&response_type=code&scope=\(BattleNetConfig.scopes)&state=\(sessionToken)"
        
        // 3. After user authorizes, your backend handles the token exchange
        // 4. App receives the access token from your backend (not directly from Battle.net)
        
        return authURL
    }
    
    private func createAuthSession() async throws -> String {
        guard let url = URL(string: "\(baseURL)/session") else {
            throw BattleNetError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        struct SessionResponse: Codable {
            let sessionToken: String
        }
        
        let response = try JSONDecoder().decode(SessionResponse.self, from: data)
        return response.sessionToken
    }
    
    func exchangeCodeForToken(code: String, sessionToken: String) async throws -> String {
        guard let url = URL(string: "\(baseURL)/token") else {
            throw BattleNetError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        struct TokenRequest: Codable {
            let code: String
            let sessionToken: String
        }
        
        let body = TokenRequest(code: code, sessionToken: sessionToken)
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        struct TokenResponse: Codable {
            let accessToken: String
            let expiresIn: Int
        }
        
        let response = try JSONDecoder().decode(TokenResponse.self, from: data)
        return response.accessToken
    }
}
