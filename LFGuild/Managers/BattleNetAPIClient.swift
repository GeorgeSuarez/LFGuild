//
//  BattleNetAPIClient.swift
//  LFGuild
//
//  Created by George Suarez on 6/29/26.
//

import Foundation

/// Client for the Battle.net World of Warcraft Profile APIs.
/// Currently supports the US region only and uses the client-credentials OAuth flow.
/// Credentials are read from Info.plist, injected via BattleNetSecrets.xcconfig.
actor BattleNetAPIClient {
    static let shared = BattleNetAPIClient()

    private let tokenEndpoint = "https://oauth.battle.net/token"
    private let apiBaseURL = "https://us.api.blizzard.com"
    private let namespace = "profile-us"
    private let locale = "en_US"

    private var accessToken: String?
    private var tokenExpiration: Date?

    private var credentials: (clientId: String, clientSecret: String) {
        get throws {
            guard
                let clientId = Bundle.main.object(forInfoDictionaryKey: "BNET_CLIENT_ID") as? String,
                let clientSecret = Bundle.main.object(forInfoDictionaryKey: "BNET_CLIENT_SECRET") as? String,
                !clientId.isEmpty,
                clientId != "YOUR_BNET_CLIENT_ID",
                !clientSecret.isEmpty,
                clientSecret != "YOUR_BNET_CLIENT_SECRET"
            else {
                throw BattleNetError.missingCredentials
            }
            return (clientId, clientSecret)
        }
    }

    private init() {}

    // MARK: - Public API

    func fetchGuildProfile(realmSlug: String, guildSlug: String) async throws -> BattleNetGuildProfileResponse {
        let request = try await guildRequest(realmSlug: realmSlug, guildSlug: guildSlug, suffix: nil)
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response)
        return try JSONDecoder().decode(BattleNetGuildProfileResponse.self, from: data)
    }

    func fetchGuildRoster(realmSlug: String, guildSlug: String) async throws -> BattleNetGuildRosterResponse {
        let request = try await guildRequest(realmSlug: realmSlug, guildSlug: guildSlug, suffix: "roster")
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response)
        return try JSONDecoder().decode(BattleNetGuildRosterResponse.self, from: data)
    }

    // MARK: - Token Management

    private func validAccessToken() async throws -> String {
        if let token = accessToken, let expiration = tokenExpiration, Date() < expiration {
            return token
        }

        let (clientId, clientSecret) = try credentials

        guard var components = URLComponents(string: tokenEndpoint) else {
            throw BattleNetError.networkFailure("Invalid token endpoint.")
        }
        components.queryItems = [
            URLQueryItem(name: "grant_type", value: "client_credentials"),
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "client_secret", value: clientSecret)
        ]

        guard let url = components.url else {
            throw BattleNetError.networkFailure("Invalid token URL.")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response)

        let tokenResponse = try JSONDecoder().decode(BattleNetTokenResponse.self, from: data)
        accessToken = tokenResponse.accessToken
        // Refresh a little before expiry to avoid edge-case rejections.
        tokenExpiration = Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn - 60))
        return tokenResponse.accessToken
    }

    // MARK: - URL Construction

    private func guildRequest(realmSlug: String, guildSlug: String, suffix: String?) async throws -> URLRequest {
        let token = try await validAccessToken()

        var path = "/data/wow/guild/\(realmSlug)/\(guildSlug)"
        if let suffix = suffix {
            path += "/\(suffix)"
        }

        guard var components = URLComponents(string: apiBaseURL + path) else {
            throw BattleNetError.networkFailure("Invalid API URL.")
        }
        components.queryItems = [
            URLQueryItem(name: "namespace", value: namespace),
            URLQueryItem(name: "locale", value: locale)
        ]

        guard let url = components.url else {
            throw BattleNetError.networkFailure("Invalid API URL.")
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    // MARK: - Validation

    private func validate(response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw BattleNetError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            return
        case 401, 403:
            throw BattleNetError.invalidCredentials
        case 404:
            throw BattleNetError.guildNotFound
        case 429:
            throw BattleNetError.rateLimited
        default:
            throw BattleNetError.networkFailure("HTTP \(httpResponse.statusCode)")
        }
    }
}

// MARK: - Slug Helpers

extension BattleNetAPIClient {
    /// Converts a user-facing realm such as "Stormrage - US" or "Mal'Ganis" into a Battle.net realm slug.
    static func realmSlug(from realm: String) -> String {
        let withoutRegion = realm
            .replacingOccurrences(of: " - US", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: " - EU", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: " - KR", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: " - TW", with: "", options: .caseInsensitive)
        return slugify(withoutRegion)
    }

    /// Converts a guild name such as "My Guild" into a Battle.net guild slug.
    static func guildSlug(from name: String) -> String {
        return slugify(name)
    }

    private static func slugify(_ value: String) -> String {
        value
            .lowercased()
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "_", with: "-")
            .components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-")).inverted)
            .joined(separator: "")
            .replacingOccurrences(of: "--", with: "-")
    }
}
