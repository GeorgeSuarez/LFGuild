//
//  CardDataModel.swift
//  LFGuild
//
//  Created by George Suarez on 8/2/25.
//

import Foundation

struct CardItem: Identifiable, Hashable {
    let id = UUID()
    var title: String
    var description: String
    let memberCount: Int
    let tags: [String]
    let requirements: String
    let leader: String
    let raidDays: [String]
    let raidTime: String
    let serverRealm: String
    let guildId: String?
    let matchScore: Double

    init(title: String, description: String, memberCount: Int, tags: [String], requirements: String, leader: String, raidDays: [String] = [], raidTime: String = "", serverRealm: String = "", guildId: String? = nil, matchScore: Double = 0) {
        self.title = title
        self.description = description
        self.memberCount = memberCount
        self.tags = tags
        self.requirements = requirements
        self.leader = leader
        self.raidDays = raidDays
        self.raidTime = raidTime
        self.serverRealm = serverRealm
        self.guildId = guildId
        self.matchScore = matchScore
    }

    init(from guild: GuildModel) {
        self.title = guild.name
        self.description = guild.description
        self.memberCount = guild.memberCount
        self.tags = guild.tags
        self.requirements = guild.requirements
        self.leader = guild.leaderName
        self.raidDays = guild.raidDays
        self.raidTime = guild.raidTimeDisplay
        self.serverRealm = guild.serverRealm
        self.guildId = guild.id
        self.matchScore = guild.matchScore
    }
}


