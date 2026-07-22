//
//  GuildSearchFilters.swift
//  LFGuild
//
//  Filter + sort models for guild search and discovery.
//

import Foundation

struct GuildSearchFilters: Equatable {
    var factions: Set<String> = []
    var regions: Set<String> = []
    var minMemberCount: Int? = nil
    var maxMemberCount: Int? = nil
    var raidDays: Set<String> = []
    var neededRoles: Set<String> = []
    var tags: Set<String> = []

    static let empty = GuildSearchFilters()

    var isDefault: Bool {
        factions.isEmpty
            && regions.isEmpty
            && minMemberCount == nil
            && maxMemberCount == nil
            && raidDays.isEmpty
            && neededRoles.isEmpty
            && tags.isEmpty
    }

    mutating func clear() {
        self = .empty
    }

    /// Client-side predicate applied after Firestore returns a page of guilds.
    func matches(_ guild: GuildModel) -> Bool {
        if !factions.isEmpty, let faction = guild.faction, !factions.contains(faction) {
            return false
        }
        if !factions.isEmpty && guild.faction == nil {
            return false
        }
        if !regions.isEmpty, !regions.contains(guild.region) {
            return false
        }
        if let min = minMemberCount, guild.memberCount < min {
            return false
        }
        if let max = maxMemberCount, guild.memberCount > max {
            return false
        }
        if !raidDays.isEmpty && Set(guild.raidDays).intersection(raidDays).isEmpty {
            return false
        }
        if !neededRoles.isEmpty && Set(guild.neededRoles).intersection(neededRoles).isEmpty {
            return false
        }
        if !tags.isEmpty && Set(guild.tags).intersection(tags).isEmpty {
            return false
        }
        return true
    }

    /// Returns the Firestore field name + direction used as the primary order
    /// for the query. Client-side scoring is applied afterwards when sorting by
    /// match score.
    var primaryOrder: (field: String, descending: Bool) {
        switch sort {
        case .memberCount: return ("memberCount", true)
        case .newest:       return ("createdAt", true)
        case .name:         return ("name", false)
        case .matchScore:   return ("memberCount", true)
        }
    }

    /// Sort option used by the picker. Stored on the filters struct so the
    /// search view, filter sheet, and query layer share a single source of
    /// truth.
    var sort: GuildSearchSortOption = .memberCount
}

enum GuildSearchSortOption: String, CaseIterable, Identifiable {
    case matchScore
    case memberCount
    case newest
    case name

    var id: String { rawValue }

    var label: String {
        switch self {
        case .matchScore:  return "Match Score"
        case .memberCount:  return "Member Count"
        case .newest:       return "Newest"
        case .name:         return "Name (A–Z)"
        }
    }
}

/// Stable filter option metadata used by the filter sheet's chip rows.
struct FilterOption: Identifiable, Hashable {
    let id: String
    let label: String
    var isSelected: Bool
}