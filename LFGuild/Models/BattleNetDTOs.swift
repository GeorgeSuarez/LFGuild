//
//  BattleNetDTOs.swift
//  LFGuild
//
//  Created by George Suarez on 6/29/26.
//

import Foundation

// MARK: - OAuth

struct BattleNetTokenResponse: Codable {
    let accessToken: String
    let expiresIn: Int

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresIn = "expires_in"
    }
}

// MARK: - Guild Profile

struct BattleNetGuildProfileResponse: Codable {
    let id: Int
    let name: String
    let faction: BattleNetNamedType
    let memberCount: Int
    let realm: BattleNetRealm

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case faction
        case memberCount = "member_count"
        case realm
    }
}

struct BattleNetNamedType: Codable {
    let type: String
    let name: String
}

struct BattleNetRealm: Codable {
    let id: Int
    let slug: String
    let name: String
}

// MARK: - Guild Roster

struct BattleNetGuildRosterResponse: Codable {
    let members: [BattleNetRosterEntry]
}

struct BattleNetRosterEntry: Codable {
    let character: BattleNetRosterCharacter
    let rank: Int
}

struct BattleNetRosterCharacter: Codable {
    let name: String
    let level: Int
    let playableClass: BattleNetNamedType
    let realm: BattleNetRealm

    enum CodingKeys: String, CodingKey {
        case name
        case level
        case playableClass = "playable_class"
        case realm
    }
}

// MARK: - Errors

enum BattleNetError: LocalizedError {
    case missingCredentials
    case invalidCredentials
    case guildNotFound
    case rateLimited
    case networkFailure(String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .missingCredentials:
            return "Battle.net credentials are missing. Check BattleNetSecrets.xcconfig."
        case .invalidCredentials:
            return "Invalid Battle.net credentials."
        case .guildNotFound:
            return "Guild not found. Check the guild name and realm."
        case .rateLimited:
            return "Battle.net rate limit reached. Please try again later."
        case .networkFailure(let message):
            return "Network error: \(message)"
        case .invalidResponse:
            return "Unexpected response from Battle.net."
        }
    }
}
