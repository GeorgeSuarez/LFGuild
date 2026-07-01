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
    let name: String?
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
    let playableClass: BattleNetPlayableClass
    let realm: BattleNetRealm

    enum CodingKeys: String, CodingKey {
        case name
        case level
        case playableClass = "playable_class"
        case realm
    }
}

struct BattleNetPlayableClass: Codable {
    let id: Int
    let name: String?

    var className: String {
        BattleNetPlayableClass.className(for: id)
    }

    static func className(for classId: Int) -> String {
        switch classId {
        case 1: return "Warrior"
        case 2: return "Paladin"
        case 3: return "Hunter"
        case 4: return "Rogue"
        case 5: return "Priest"
        case 6: return "Death Knight"
        case 7: return "Shaman"
        case 8: return "Mage"
        case 9: return "Warlock"
        case 10: return "Monk"
        case 11: return "Druid"
        case 12: return "Demon Hunter"
        case 13: return "Evoker"
        default: return "Unknown"
        }
    }
}

// MARK: - Realm / Leaderboard Discovery

struct BattleNetHref: Codable {
    let href: String
}

struct BattleNetRealmSlugResponse: Codable {
    let slug: String
    let connectedRealm: BattleNetHref

    enum CodingKeys: String, CodingKey {
        case slug
        case connectedRealm = "connected_realm"
    }
}

struct BattleNetLeaderboardIndexResponse: Codable {
    let currentLeaderboards: [BattleNetLeaderboardEntry]

    enum CodingKeys: String, CodingKey {
        case currentLeaderboards = "current_leaderboards"
    }
}

struct BattleNetLeaderboardEntry: Codable {
    let key: BattleNetHref
    let id: Int
    let name: String?
}

struct BattleNetLeaderboardResponse: Codable {
    let leadingGroups: [BattleNetLeaderboardGroup]

    enum CodingKeys: String, CodingKey {
        case leadingGroups = "leading_groups"
    }
}

struct BattleNetLeaderboardGroup: Codable {
    let ranking: Int
    let members: [BattleNetLeaderboardMember]
}

struct BattleNetLeaderboardMember: Codable {
    let profile: BattleNetLeaderboardProfile
}

struct BattleNetLeaderboardProfile: Codable {
    let name: String
    let realm: BattleNetRealm
}

// MARK: - Character Profile (for guild discovery)

struct BattleNetCharacterProfileSummary: Codable {
    let guild: BattleNetCharacterGuild?
}

struct BattleNetCharacterGuild: Codable {
    let name: String
    let realm: BattleNetRealm
    let faction: BattleNetNamedType?
}

// MARK: - Errors

enum BattleNetError: LocalizedError, Equatable {
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
