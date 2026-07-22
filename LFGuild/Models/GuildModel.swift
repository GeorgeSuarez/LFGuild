//
//  GuildModel.swift
//  LFGuild
//
//  Created by George Suarez on 7/28/25.
//

import Foundation
import FirebaseFirestore

struct GuildModel: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    var name: String
    var description: String
    var leaderId: String
    var leaderName: String
    var memberCount: Int
    var maxMembers: Int
    var tags: [String]
    var requirements: String
    var raidDays: [String]
    var raidStartTime: String
    var raidEndTime: String
    var serverRealm: String
    var region: String
    var isActive: Bool
    var neededRoles: [String]
    var createdAt: Date?
    var updatedAt: Date?

    // Battle.net enrichment
    var battleNetGuildId: Int?
    var faction: String?
    var battleNetMemberCount: Int?
    var battleNetOfficers: [BattleNetOfficer]?
    var battleNetLastSyncedAt: Date?

    /// Debug-only flag marking guilds created by the test seeder so they can be
    /// cleaned up. Optional so existing documents decode without it.
    var isTestGuild: Bool?

    init(
        id: String? = nil,
        name: String,
        description: String,
        leaderId: String,
        leaderName: String,
        memberCount: Int = 1,
        maxMembers: Int = 50,
        tags: [String] = [],
        requirements: String = "",
        raidDays: [String] = [],
        raidStartTime: String = "",
        raidEndTime: String = "",
        serverRealm: String,
        region: String = "US",
        isActive: Bool = true,
        neededRoles: [String] = ["Tank", "Healer", "DPS"],
        matchScore: Double = 0.0,
        createdAt: Date? = nil,
        updatedAt: Date? = nil,
        battleNetGuildId: Int? = nil,
        faction: String? = nil,
        battleNetMemberCount: Int? = nil,
        battleNetOfficers: [BattleNetOfficer]? = nil,
        battleNetLastSyncedAt: Date? = nil,
        isTestGuild: Bool? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.leaderId = leaderId
        self.leaderName = leaderName
        self.memberCount = memberCount
        self.maxMembers = maxMembers
        self.tags = tags
        self.requirements = requirements
        self.raidDays = raidDays
        self.raidStartTime = raidStartTime
        self.raidEndTime = raidEndTime
        self.serverRealm = serverRealm
        self.region = region
        self.isActive = isActive
        self.neededRoles = neededRoles
        self.matchScore = matchScore
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.battleNetGuildId = battleNetGuildId
        self.faction = faction
        self.battleNetMemberCount = battleNetMemberCount
        self.battleNetOfficers = battleNetOfficers
        self.battleNetLastSyncedAt = battleNetLastSyncedAt
        self.isTestGuild = isTestGuild
    }
    
    var raidTimeDisplay: String {
        if raidStartTime.isEmpty && raidEndTime.isEmpty {
            return "Not set"
        }
        return "\(raidStartTime) - \(raidEndTime)"
    }
    
    var isFull: Bool {
        memberCount >= maxMembers
    }

    var matchScore: Double = 0.0
}

struct BattleNetOfficer: Codable, Hashable {
    let name: String
    let level: Int
    let playableClass: String
    let rank: Int

    var isGuildMaster: Bool {
        rank == 0
    }

    var displayTitle: String {
        isGuildMaster ? "Guild Master" : "Officer"
    }
}

struct GuildMember: Identifiable, Codable {
    let id: String
    var userId: String
    var name: String
    var role: String
    var joinDate: Date
    var status: MemberStatus
    
    enum MemberStatus: String, Codable {
        case active, inactive, pending
    }
}

struct GuildApplication: Identifiable, Codable {
    @DocumentID var id: String?
    var userId: String
    var userName: String
    var message: String
    var status: ApplicationStatus
    var createdAt: Date?
    
    enum ApplicationStatus: String, Codable {
        case pending, approved, declined
    }
}

enum GuildError: LocalizedError {
    case notFound
    case alreadyMember
    case guildFull
    case alreadyApplied
    case unauthorized
    case invalidData
    case emailNotVerified

    var errorDescription: String? {
        switch self {
        case .notFound:
            return "Guild not found"
        case .alreadyMember:
            return "You are already a member of this guild"
        case .guildFull:
            return "This guild is currently full"
        case .alreadyApplied:
            return "You have already applied to this guild"
        case .unauthorized:
            return "You are not authorized to perform this action"
        case .invalidData:
            return "Invalid guild data"
        case .emailNotVerified:
            return "Please verify your email address before applying to a guild"
        }
    }
}
