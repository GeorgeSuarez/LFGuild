//
//  GuildDiscoveryManager.swift
//  LFGuild
//
//  Background importer that populates Firestore with real WoW guilds from
//  popular US and OCE realms using the Battle.net API.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

/// Imports real WoW guilds from popular US/OCE realms so users don't have to
/// manually import guilds themselves.
@MainActor
final class GuildDiscoveryManager: ObservableObject {
    static let shared = GuildDiscoveryManager()

    @Published var isImporting = false
    @Published var importedCount = 0
    @Published var lastError: String?

    private let db = Firestore.firestore()
    private let guildManager = GuildManager()

    /// Minimum interval between full discovery runs.
    private let importInterval: TimeInterval = 24 * 60 * 60

    private init() {}

    /// Imports popular guilds if the user is signed in with a verified email and
    /// enough time has passed since the last run.
    func importPopularGuildsIfNeeded() async {
        guard let currentUser = Auth.auth().currentUser,
              !currentUser.isAnonymous,
              currentUser.isEmailVerified else {
            return
        }

        let defaults = UserDefaults.standard
        let lastImport = defaults.object(forKey: "lastPopularGuildImport") as? Date
        if let lastImport = lastImport,
           Date().timeIntervalSince(lastImport) < importInterval {
            return
        }

        await importMissingPopularGuilds()
        defaults.set(Date(), forKey: "lastPopularGuildImport")
    }

    /// Imports each curated candidate unless a guild with the same name and realm
    /// already exists in Firestore.
    private func importMissingPopularGuilds() async {
        isImporting = true
        defer { isImporting = false }

        importedCount = 0
        lastError = nil

        guard let currentUser = Auth.auth().currentUser else { return }

        for realm in BattleNetGuildCatalog.searchableRealms {
            for name in BattleNetGuildCatalog.candidatesByRealm[realm] ?? [] {
                if await guildExists(name: name, realm: realm.rawValue) {
                    continue
                }

                do {
                    let tempGuild = GuildModel(
                        name: name,
                        description: "",
                        leaderId: currentUser.uid,
                        leaderName: currentUser.displayName ?? "",
                        serverRealm: realm.rawValue,
                        region: realm.region
                    )

                    let enriched = try await guildManager.enrichFromBattleNet(tempGuild)

                    var guild = enriched
                    guild.leaderId = currentUser.uid
                    guild.leaderName = currentUser.displayName ?? name
                    guild.description = "Imported from Battle.net. \(guild.faction ?? "") guild on \(guild.serverRealm)."
                    guild.requirements = "Contact the guild in-game for requirements."
                    guild.tags = defaultTags(for: realm)
                    guild.neededRoles = ["Tank", "Healer", "DPS"]
                    guild.maxMembers = 50
                    guild.isActive = true

                    try await createImportedGuild(guild)
                    importedCount += 1

                    // Small delay to be kind to the Battle.net API.
                    try? await Task.sleep(nanoseconds: 200_000_000)
                } catch {
                    lastError = error.localizedDescription
                    // Continue with the next candidate; a single failure shouldn't block the rest.
                }
            }
        }
    }

    private func defaultTags(for realm: WoWRealm) -> [String] {
        switch realm.region {
        case "OCE":
            return ["Raid Focused", "Hardcore"]
        default:
            return ["Raid Focused", "Hardcore"]
        }
    }

    private func guildExists(name: String, realm: String) async -> Bool {
        do {
            let snapshot = try await db.collection("guilds")
                .whereField("name", isEqualTo: name)
                .whereField("serverRealm", isEqualTo: realm)
                .limit(to: 1)
                .getDocuments()
            return !snapshot.documents.isEmpty
        } catch {
            return false
        }
    }

    private func createImportedGuild(_ guild: GuildModel) async throws {
        guard let currentUser = Auth.auth().currentUser else {
            throw GuildError.unauthorized
        }

        let guildRef = db.collection("guilds").document()
        var importedGuild = guild
        importedGuild.id = guildRef.documentID
        importedGuild.leaderId = currentUser.uid
        importedGuild.leaderName = currentUser.displayName ?? importedGuild.leaderName
        importedGuild.createdAt = Date()
        importedGuild.updatedAt = Date()

        try guildRef.setData(from: importedGuild)
    }

}
