//
//  BattleNetGuildCatalog.swift
//  LFGuild
//
//  Curated list of well-known guild names grouped by realm. Used to discover
//  real WoW guilds via the Battle.net API because Blizzard does not expose a
//  guild-search endpoint.
//

import Foundation

enum BattleNetGuildCatalog {
    /// Guild names to query for each supported realm.
    static let candidatesByRealm: [WoWRealm: [String]] = [
        // US
        .illidan: ["Liquid", "Big Dumb Guild"],
        .area52: ["Instant Dollars"],
        .tichondrius: ["Vindictum"],
        .stormrage: ["Poptart Corndog"],
        .malganis: ["SNF"],
        .thrall: ["Reckoning"],
        .zuljin: ["Club Camel"],
        .sargeras: ["Midwinter"],
        .dalaran: ["Acheron"],
        .kiljaeden: ["Divide by Zero"],
        .emeraldDream: ["Warsong Battalion"],
        .proudmoore: ["Abyss"],

        // OCE
        .frostmourne: ["Honestly", "Synergy"],
        .barthilas: ["Vindictum", "Honestly"],
        .jubeithos: ["Synergy"],
        .gundrak: ["Descendants of Darkness"],
        .saurfang: ["The Deadly Alliance"]
    ]

    /// All realms that have at least one candidate guild.
    static var searchableRealms: [WoWRealm] {
        Array(candidatesByRealm.keys)
            .sorted { WoWRealm.allCases.firstIndex(of: $0)! < WoWRealm.allCases.firstIndex(of: $1)! }
    }
}
