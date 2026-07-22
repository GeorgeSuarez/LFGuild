//
//  TestGuildSeeder.swift
//  LFGuild
//
//  DEBUG-only utility that seeds diverse sample guilds into Firestore so the
//  matching carousel, search, and filters have data to test against. Also
//  removes previously seeded guilds via the `isTestGuild` flag.
//

#if DEBUG

import Foundation
import FirebaseFirestore
import FirebaseAuth

@MainActor
final class TestGuildSeeder: ObservableObject {
    @Published var isSeeding = false
    @Published var isRemoving = false
    @Published var statusMessage: String?

    private let db = Firestore.firestore()

    private struct TestGuild {
        let name: String
        let description: String
        let realm: WoWRealm
        let faction: String
        let tags: [String]
        let raidDays: [String]
        let raidStartTime: String
        let raidEndTime: String
        let neededRoles: [String]
        let memberCount: Int
        let requirements: String
    }

    /// A varied catalog spanning realms, factions, tags, raid days, times, and
    /// needed roles so the matcher produces a range of scores regardless of the
    /// current user's preferences.
    private let catalog: [TestGuild] = [
        TestGuild(name: "Stormrage Vanguard", description: "Progression mythic raiding guild pushing Cutting Edge each tier. Organized, prepared, and consistent.", realm: .stormrage, faction: "Alliance", tags: [Tag.raidFocused.rawValue, Tag.hardcore.rawValue], raidDays: [Day.tuesday.rawValue, Day.thursday.rawValue, Day.sunday.rawValue], raidStartTime: "8:00 PM", raidEndTime: "11:00 PM", neededRoles: ["Tank", "Healer", "DPS"], memberCount: 28, requirements: "2k+ IO, AoTC, 90%+ raid attendance"),
        TestGuild(name: "Tichondrius Legion", description: "PvP-focused guild running rated battlegrounds and arena. Horde dominant, always queuing.", realm: .tichondrius, faction: "Horde", tags: [Tag.pvp.rawValue, Tag.hardcore.rawValue], raidDays: [Day.wednesday.rawValue, Day.friday.rawValue, Day.saturday.rawValue], raidStartTime: "9:00 PM", raidEndTime: "12:00 AM", neededRoles: ["Tank", "DPS"], memberCount: 40, requirements: "1.8k+ RBG rating or 2k+ arena rating"),
        TestGuild(name: "Area 52 Expedition", description: "Casual mythic+ pushing community. Low pressure, high keys, good vibes.", realm: .area52, faction: "Horde", tags: [Tag.mythicPlus.rawValue, Tag.casual.rawValue], raidDays: [Day.monday.rawValue, Day.thursday.rawValue], raidStartTime: "7:00 PM", raidEndTime: "10:00 PM", neededRoles: ["Healer", "DPS"], memberCount: 15, requirements: "Chill attitude, 1k+ IO preferred"),
        TestGuild(name: "Dalaran Scholars", description: "Roleplay and light raiding. Story-driven events weekly.", realm: .dalaran, faction: "Alliance", tags: [Tag.roleplay.rawValue, Tag.casual.rawValue], raidDays: [Day.saturday.rawValue, Day.sunday.rawValue], raidStartTime: "2:00 PM", raidEndTime: "5:00 PM", neededRoles: ["Tank", "Healer", "DPS"], memberCount: 22, requirements: "Respectful of RP etiquette"),
        TestGuild(name: "Illidan Reapers", description: "Hardcore raiding guild recruiting for mythic progress. Prepared raiders only.", realm: .illidan, faction: "Horde", tags: [Tag.raidFocused.rawValue, Tag.hardcore.rawValue], raidDays: [Day.tuesday.rawValue, Day.wednesday.rawValue], raidStartTime: "8:00 PM", raidEndTime: "11:00 PM", neededRoles: ["Tank", "Healer"], memberCount: 35, requirements: "3k+ IO, mythic experience, 95% attendance"),
        TestGuild(name: "Proudmoore Fleet", description: "Social casual guild running mythic+ and normal raids. All welcome.", realm: .proudmoore, faction: "Alliance", tags: [Tag.casual.rawValue, Tag.mythicPlus.rawValue], raidDays: [Day.friday.rawValue, Day.saturday.rawValue], raidStartTime: "8:00 PM", raidEndTime: "11:00 PM", neededRoles: ["DPS"], memberCount: 18, requirements: "No requirements — just show up!"),
        TestGuild(name: "Sargeras Sentinels", description: "PvP and raiding hybrid. Rated BGs twice weekly, mythic raiding on off nights.", realm: .sargeras, faction: "Alliance", tags: [Tag.pvp.rawValue, Tag.raidFocused.rawValue], raidDays: [Day.thursday.rawValue, Day.sunday.rawValue], raidStartTime: "9:00 PM", raidEndTime: "12:00 AM", neededRoles: ["Healer", "DPS"], memberCount: 30, requirements: "1.5k+ PvP rating or AoTC"),
        TestGuild(name: "Emerald Dream Wardens", description: "Heavy RP guild with campaign arcs and in-character events.", realm: .emeraldDream, faction: "Alliance", tags: [Tag.roleplay.rawValue, Tag.casual.rawValue], raidDays: [Day.saturday.rawValue], raidStartTime: "3:00 PM", raidEndTime: "6:00 PM", neededRoles: ["Tank", "DPS"], memberCount: 12, requirements: "Character backstory and RP willingness"),
        TestGuild(name: "Mal'Ganis Marauders", description: "Mythic+ powerhouse pushing high keys every week. Dedicated key runners.", realm: .malganis, faction: "Horde", tags: [Tag.hardcore.rawValue, Tag.mythicPlus.rawValue], raidDays: [Day.monday.rawValue, Day.wednesday.rawValue, Day.friday.rawValue], raidStartTime: "8:00 PM", raidEndTime: "11:00 PM", neededRoles: ["Tank", "Healer", "DPS"], memberCount: 45, requirements: "2.6k+ IO, own keys, voice comms"),
        TestGuild(name: "Kil'jaeden Crusade", description: "Casual raiding guild clearing heroic each tier. Friendly and helpful.", realm: .kiljaeden, faction: "Horde", tags: [Tag.raidFocused.rawValue, Tag.casual.rawValue], raidDays: [Day.tuesday.rawValue, Day.thursday.rawValue], raidStartTime: "7:00 PM", raidEndTime: "10:00 PM", neededRoles: ["DPS"], memberCount: 25, requirements: "Willingness to learn and have fun"),
        TestGuild(name: "Barthilas Brethren", description: "OCE progression raiding guild. Mythic focused, tight-knit roster.", realm: .barthilas, faction: "Horde", tags: [Tag.raidFocused.rawValue, Tag.hardcore.rawValue], raidDays: [Day.tuesday.rawValue, Day.thursday.rawValue], raidStartTime: "8:00 PM", raidEndTime: "11:00 PM", neededRoles: ["Tank", "Healer", "DPS"], memberCount: 33, requirements: "Aussie time zone, 3k+ IO"),
        TestGuild(name: "Draenor Vanguard", description: "EU casual mythic+ and social guild. Low stress, high fun.", realm: .draenor, faction: "Alliance", tags: [Tag.casual.rawValue, Tag.mythicPlus.rawValue], raidDays: [Day.wednesday.rawValue, Day.sunday.rawValue], raidStartTime: "7:00 PM", raidEndTime: "10:00 PM", neededRoles: ["Healer", "DPS"], memberCount: 20, requirements: "English-speaking, 1k+ IO preferred")
    ]

    /// Creates the sample guilds, skipping any that already exist (same name +
    /// realm). The signed-in user becomes the `leaderId` (required by Firestore
    /// rules) but is NOT added as a member, so they can still apply to test the
    /// application flow.
    func seed(authManager: AuthenticationManager) async {
        guard authManager.isVerifiedEmailUser else {
            statusMessage = "Seed failed: verify your email first. Test guilds require a verified email/password account."
            return
        }
        guard let firebaseUser = Auth.auth().currentUser else {
            statusMessage = "Seed failed: no signed-in user."
            return
        }
        let uid = firebaseUser.uid
        let leaderName = authManager.currentUser?.name.nilIfEmpty
            ?? firebaseUser.displayName
            ?? "Test Leader"

        isSeeding = true
        statusMessage = nil
        var created = 0
        var skipped = 0
        defer { isSeeding = false }

        for guild in catalog {
            if await exists(name: guild.name, realm: guild.realm.rawValue) {
                skipped += 1
                continue
            }

            let docRef = db.collection("guilds").document()
            let model = GuildModel(
                id: docRef.documentID,
                name: guild.name,
                description: guild.description,
                leaderId: uid,
                leaderName: leaderName,
                memberCount: guild.memberCount,
                maxMembers: 50,
                tags: guild.tags,
                requirements: guild.requirements,
                raidDays: guild.raidDays,
                raidStartTime: guild.raidStartTime,
                raidEndTime: guild.raidEndTime,
                serverRealm: guild.realm.rawValue,
                region: guild.realm.region,
                isActive: true,
                neededRoles: guild.neededRoles,
                createdAt: Date(),
                updatedAt: Date(),
                faction: guild.faction,
                battleNetMemberCount: guild.memberCount,
                battleNetLastSyncedAt: Date(),
                isTestGuild: true
            )

            do {
                try docRef.setData(from: model)
                created += 1
            } catch {
                statusMessage = "Stopped after \(created) guilds: \(error.localizedDescription)"
                return
            }

            // Small delay to be kind to Firestore.
            try? await Task.sleep(nanoseconds: 100_000_000)
        }

        statusMessage = "Seeded \(created) test guild\(created == 1 ? "" : "s")\(skipped > 0 ? ", \(skipped) already existed" : ""). Pull-to-refresh on Home to see matches."
    }

    /// Deletes every guild the current user leads that is marked `isTestGuild`.
    func removeAll(authManager: AuthenticationManager) async {
        guard let uid = Auth.auth().currentUser?.uid else {
            statusMessage = "Remove failed: no signed-in user."
            return
        }
        isRemoving = true
        statusMessage = nil
        defer { isRemoving = false }

        do {
            let snapshot = try await db.collection("guilds")
                .whereField("leaderId", isEqualTo: uid)
                .getDocuments()

            let testDocs = snapshot.documents.filter { doc in
                (doc.data()["isTestGuild"] as? Bool) == true
            }

            for doc in testDocs {
                try? await doc.reference.delete()
            }

            statusMessage = "Removed \(testDocs.count) test guild\(testDocs.count == 1 ? "" : "s")."
        } catch {
            statusMessage = "Remove failed: \(error.localizedDescription)"
        }
    }

    private func exists(name: String, realm: String) async -> Bool {
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
}

private extension String {
    var nilIfEmpty: String? {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : self
    }
}

#endif