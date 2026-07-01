//
//  BattleNetGuildSearchService.swift
//  LFGuild
//
//  Discovers real WoW guilds for a given realm using only the Battle.net API.
//
//  Battle.net does not provide a guild search/list endpoint, so guilds are
//  discovered indirectly:
//    1. Resolve the realm's connected-realm id.
//    2. Fetch the current Mythic Keystone leaderboard for that connected realm.
//    3. For top characters that belong to the selected realm, fetch their
//       profile summary to read the `guild` field.
//    4. Fetch the full guild profile + roster for each discovered guild.
//

import Foundation

final class BattleNetGuildSearchService {
    static let shared = BattleNetGuildSearchService()

    private let apiClient = BattleNetAPIClient.shared

    private init() {}

    /// Maximum number of guilds to return for testing.
    private let maxResults = 5
    /// Maximum number of leaderboard groups to scan.
    private let maxGroupsToScan = 60
    /// Stop scanning once this many candidate guilds are collected.
    private let maxCandidates = 12

    func searchGuilds(on realm: WoWRealm) async throws -> [GuildModel] {
        let realmSlug = BattleNetAPIClient.realmSlug(from: realm.rawValue)

        let connectedRealmId = try await apiClient.connectedRealmId(for: realmSlug)
        let dungeons = try await apiClient.fetchLeaderboardDungeons(connectedRealmId: connectedRealmId)

        guard let firstDungeon = dungeons.first else { return [] }

        let leaderboard = try await apiClient.fetchLeaderboard(href: firstDungeon.key.href)

        // Collect candidate guild (name, realmSlug) pairs from characters on the
        // selected realm. Using a task group keeps character lookups concurrent.
        let candidates = try await discoverGuildCandidates(
            from: leaderboard.leadingGroups,
            targetRealmSlug: realmSlug
        )

        guard !candidates.isEmpty else { return [] }

        // Fetch the full guild data for each candidate concurrently, skipping 404s.
        let results = try await withThrowingTaskGroup(of: GuildModel?.self) { group in
            for candidate in candidates.prefix(self.maxCandidates) {
                group.addTask {
                    try? await self.fetchGuild(name: candidate.name, realmSlug: candidate.realmSlug, displayRealm: realm)
                }
            }

            var guilds: [GuildModel] = []
            for try await guild in group {
                if let guild { guilds.append(guild) }
            }
            return guilds
        }

        return Array(results.sorted { $0.memberCount > $1.memberCount }.prefix(maxResults))
    }

    // MARK: - Discovery Helpers

    private func discoverGuildCandidates(
        from groups: [BattleNetLeaderboardGroup],
        targetRealmSlug: String
    ) async throws -> [(name: String, realmSlug: String)] {
        await withTaskGroup(of: (name: String, realmSlug: String)?.self) { group in
            var candidates: [(name: String, realmSlug: String)] = []
            var seen = Set<String>()
            var scanned = 0

            for entry in groups.prefix(self.maxGroupsToScan) {
                guard candidates.count < self.maxCandidates else { break }

                for member in entry.members {
                    let memberRealm = member.profile.realm.slug
                    guard memberRealm == targetRealmSlug else { continue }

                    let characterName = member.profile.name
                    let nameSlug = BattleNetAPIClient.guildSlug(from: characterName)

                    group.addTask { [self] in
                        guard let profile = try? await self.apiClient.fetchCharacterProfile(
                            realmSlug: memberRealm,
                            nameSlug: nameSlug
                        ),
                        let guild = profile.guild,
                        guild.realm.slug == targetRealmSlug else {
                            return nil
                        }
                        return (name: guild.name, realmSlug: guild.realm.slug)
                    }

                    scanned += 1
                    if scanned >= self.maxGroupsToScan * 5 { break }
                }

                if scanned >= self.maxGroupsToScan * 5 { break }
            }

            for await result in group {
                if candidates.count >= self.maxCandidates { continue }
                guard let result else { continue }
                let key = "\(result.realmSlug):\(result.name.lowercased())"
                guard !seen.contains(key) else { continue }
                seen.insert(key)
                candidates.append(result)
            }

            return candidates
        }
    }

    private func fetchGuild(name: String, realmSlug: String, displayRealm: WoWRealm) async throws -> GuildModel {
        let guildSlug = BattleNetAPIClient.guildSlug(from: name)

        async let profileTask = apiClient.fetchGuildProfile(realmSlug: realmSlug, guildSlug: guildSlug)
        async let rosterTask = apiClient.fetchGuildRoster(realmSlug: realmSlug, guildSlug: guildSlug)

        let (profile, roster) = try await (profileTask, rosterTask)

        let officers = roster.members
            .filter { $0.rank <= 2 }
            .sorted { $0.rank < $1.rank }
            .map {
                BattleNetOfficer(
                    name: $0.character.name,
                    level: $0.character.level,
                    playableClass: $0.character.playableClass.className,
                    rank: $0.rank
                )
            }

        return GuildModel(
            name: profile.name,
            description: "",
            leaderId: "",
            leaderName: "",
            memberCount: profile.memberCount,
            serverRealm: displayRealm.rawValue,
            region: displayRealm.region,
            isActive: true,
            battleNetGuildId: profile.id,
            faction: profile.faction.name,
            battleNetMemberCount: profile.memberCount,
            battleNetOfficers: officers,
            battleNetLastSyncedAt: Date()
        )
    }
}