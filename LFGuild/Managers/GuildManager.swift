//
//  GuildManager.swift
//  LFGuild
//
//  Created by George Suarez on 8/10/25.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

@MainActor
class GuildManager: ObservableObject {
    @Published var guilds: [GuildModel] = []
    @Published var userGuilds: [GuildModel] = []
    @Published var currentGuild: GuildModel?
    @Published var isLoading = false
    @Published var error: GuildError?
    @Published var applications: [GuildApplication] = []
    
    private let db = Firestore.firestore()
    private var guildsListener: ListenerRegistration?
    private var applicationsListener: ListenerRegistration?
    
    deinit {
        guildsListener?.remove()
        applicationsListener?.remove()
    }
    
    // MARK: - Fetching
    
    func fetchAllGuilds() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let snapshot = try await db.collection("guilds")
                .whereField("isActive", isEqualTo: true)
                .order(by: "memberCount", descending: true)
                .getDocuments()
            
            self.guilds = snapshot.documents.compactMap { try? $0.data(as: GuildModel.self) }
        } catch {
            self.error = .invalidData
        }
    }
    
    func fetchGuild(byId id: String) async -> GuildModel? {
        do {
            let document = try await db.collection("guilds").document(id).getDocument()
            return try? document.data(as: GuildModel.self)
        } catch {
            self.error = .invalidData
            return nil
        }
    }
    
    func startListeningForGuilds() {
        guildsListener?.remove()
        
        guildsListener = db.collection("guilds")
            .whereField("isActive", isEqualTo: true)
            .order(by: "memberCount", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if error != nil {
                    self.error = .invalidData
                    return
                }

                guard let documents = snapshot?.documents else { return }

                self.guilds = documents.compactMap { try? $0.data(as: GuildModel.self) }
            }
    }
    
    func fetchGuildsForUser(userId: String) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let memberSnapshot = try await db.collectionGroup("members")
                .whereField("userId", isEqualTo: userId)
                .whereField("status", isEqualTo: "active")
                .getDocuments()
            
            var userGuilds: [GuildModel] = []
            for doc in memberSnapshot.documents {
                let guildRef = doc.reference.parent.parent
                if let guildDoc = try? await guildRef?.getDocument(),
                   let guild = try? guildDoc.data(as: GuildModel.self) {
                    userGuilds.append(guild)
                }
            }
            
            self.userGuilds = userGuilds
        } catch {
            // Non-fatal; user guilds list may be empty.
        }
    }
    
    // MARK: - Matching
    
    func fetchMatchingGuilds(for user: UserModel) async -> [GuildModel] {
        isLoading = true
        defer { isLoading = false }
        error = nil

        do {
            var query: Query = db.collection("guilds")
                .whereField("isActive", isEqualTo: true)
            
            // Filter by realm if user has preferred realms
            if let preferredRealm = user.preferredRealms.first {
                query = query.whereField("serverRealm", isEqualTo: preferredRealm)
            }
            
            let snapshot = try await query.getDocuments()
            var guilds = snapshot.documents.compactMap { try? $0.data(as: GuildModel.self) }
            
            // Client-side filtering for more complex criteria
            guilds = guilds.filter { guild in
                // Check if user roles match guild needs
                let userRoles = user.roles
                let neededRoles = Set(guild.neededRoles)
                let hasMatchingRole = userRoles.isEmpty || !userRoles.isDisjoint(with: neededRoles)
                
                // Check if user available days overlap with guild raid days
                let userDays = user.availableDays
                let guildDays = Set(guild.raidDays)
                let hasMatchingDays = userDays.isEmpty || !userDays.isDisjoint(with: guildDays)
                
                // Check if guild is not full
                let notFull = !guild.isFull
                
                return hasMatchingRole && hasMatchingDays && notFull
            }
            
            // Calculate match scores
            guilds = guilds.map { guild in
                var scoredGuild = guild
                var score: Double = 0
                
                // Realm match (highest weight)
                if user.preferredRealms.contains(guild.serverRealm) {
                    score += 0.4
                }
                
                // Role match
                let userRoles = user.roles
                let neededRoles = Set(guild.neededRoles)
                if !userRoles.isEmpty && !neededRoles.isEmpty {
                    let intersection = userRoles.intersection(neededRoles)
                    score += Double(intersection.count) / Double(neededRoles.count) * 0.3
                }
                
                // Days match
                let userDays = user.availableDays
                let guildDays = Set(guild.raidDays)
                if !userDays.isEmpty && !guildDays.isEmpty {
                    let intersection = userDays.intersection(guildDays)
                    score += Double(intersection.count) / Double(guildDays.count) * 0.3
                }
                
                scoredGuild.matchScore = score
                return scoredGuild
            }
            
            // Sort by match score
            return guilds.sorted { $0.matchScore > $1.matchScore }
            
        } catch {
            self.error = .invalidData
            return []
        }
    }
    
    // MARK: - Battle.net Enrichment

    /// Fetches the guild's profile and roster from Battle.net and returns an enriched copy.
    /// Only the GM and officers (rank <= 2) are included from the roster.
    func enrichFromBattleNet(_ guild: GuildModel) async throws -> GuildModel {
        let realmSlug = BattleNetAPIClient.realmSlug(from: guild.serverRealm)
        let guildSlug = BattleNetAPIClient.guildSlug(from: guild.name)

        async let profileTask = BattleNetAPIClient.shared.fetchGuildProfile(realmSlug: realmSlug, guildSlug: guildSlug)
        async let rosterTask = BattleNetAPIClient.shared.fetchGuildRoster(realmSlug: realmSlug, guildSlug: guildSlug)

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

        var enriched = guild
        enriched.battleNetGuildId = profile.id
        enriched.faction = profile.faction.name
        enriched.battleNetMemberCount = profile.memberCount
        enriched.battleNetOfficers = officers
        enriched.battleNetLastSyncedAt = Date()
        return enriched
    }

    /// Refreshes Battle.net data for an existing guild and persists the update.
    func refreshBattleNetData(for guildId: String) async throws -> GuildModel {
        guard var guild = await fetchGuild(byId: guildId) else {
            throw GuildError.notFound
        }
        guild = try await enrichFromBattleNet(guild)
        try await updateGuild(guild)
        return guild
    }

    // MARK: - Guild Creation & Management

    func createGuild(_ guild: GuildModel) async throws {
        guard let currentUser = Auth.auth().currentUser else {
            throw GuildError.unauthorized
        }

        var newGuild = guild
        newGuild.leaderId = currentUser.uid
        newGuild.name = guild.name.trimmingCharacters(in: .whitespacesAndNewlines)
        newGuild.description = guild.description.trimmingCharacters(in: .whitespacesAndNewlines)
        newGuild.requirements = guild.requirements.trimmingCharacters(in: .whitespacesAndNewlines)
        newGuild.leaderName = guild.leaderName.trimmingCharacters(in: .whitespacesAndNewlines)
        newGuild.createdAt = Date()
        newGuild.updatedAt = Date()

        guard !newGuild.name.isEmpty, !newGuild.serverRealm.isEmpty else {
            throw GuildError.invalidData
        }
        guard newGuild.name.count <= 100,
              newGuild.description.count <= 2000,
              newGuild.requirements.count <= 1000,
              newGuild.leaderName.count <= 100 else {
            throw GuildError.invalidData
        }

        let guildRef = db.collection("guilds").document()
        try guildRef.setData(from: newGuild)

        // Add leader as first member
        let member = GuildMember(
            id: currentUser.uid,
            userId: currentUser.uid,
            name: newGuild.leaderName,
            role: "Guild Leader",
            joinDate: Date(),
            status: .active
        )

        try guildRef.collection("members").document(currentUser.uid).setData(from: member)
    }
    
    func updateGuild(_ guild: GuildModel) async throws {
        guard let id = guild.id else { throw GuildError.invalidData }
        guard let currentUser = Auth.auth().currentUser,
              currentUser.uid == guild.leaderId else {
            throw GuildError.unauthorized
        }
        
        var updatedGuild = guild
        updatedGuild.updatedAt = Date()
        
        try db.collection("guilds").document(id).setData(from: updatedGuild, merge: true)
    }
    
    func deleteGuild(_ guild: GuildModel) async throws {
        guard let id = guild.id else { throw GuildError.invalidData }
        guard let currentUser = Auth.auth().currentUser,
              currentUser.uid == guild.leaderId else {
            throw GuildError.unauthorized
        }
        
        try await db.collection("guilds").document(id).delete()
    }
    
    // MARK: - Applications
    
    func applyToGuild(guildId: String, userId: String, userName: String, message: String) async throws {
        guard let firebaseUser = Auth.auth().currentUser,
              !firebaseUser.isAnonymous,
              firebaseUser.isEmailVerified else {
            throw GuildError.emailNotVerified
        }

        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty else {
            throw GuildError.invalidData
        }
        guard trimmedMessage.count <= 1000 else {
            throw GuildError.invalidData
        }

        let trimmedUserName = userName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedUserName.isEmpty, trimmedUserName.count <= 100 else {
            throw GuildError.invalidData
        }

        let guildRef = db.collection("guilds").document(guildId)

        // Check if already applied
        let existingQuery = try await guildRef.collection("applications")
            .whereField("userId", isEqualTo: userId)
            .getDocuments()

        if !existingQuery.documents.isEmpty {
            throw GuildError.alreadyApplied
        }

        // Check if already member
        let memberDoc = try await guildRef.collection("members").document(userId).getDocument()
        if memberDoc.exists {
            throw GuildError.alreadyMember
        }

        let application = GuildApplication(
            userId: userId,
            userName: trimmedUserName,
            message: trimmedMessage,
            status: .pending,
            createdAt: Date()
        )

        try guildRef.collection("applications").addDocument(from: application)
    }
    
    func respondToApplication(guildId: String, applicationId: String, accept: Bool) async throws {
        guard Auth.auth().currentUser != nil else {
            throw GuildError.unauthorized
        }
        
        let guildRef = db.collection("guilds").document(guildId)
        let appRef = guildRef.collection("applications").document(applicationId)
        
        let application = try await appRef.getDocument().data(as: GuildApplication.self)
        
        if accept {
            // Add as member
            let member = GuildMember(
                id: application.userId,
                userId: application.userId,
                name: application.userName,
                role: "Member",
                joinDate: Date(),
                status: .active
            )
            
            try guildRef.collection("members").document(application.userId).setData(from: member)
            
            // Update member count
            try await guildRef.updateData([
                "memberCount": FieldValue.increment(Int64(1))
            ])
            
            try await appRef.updateData(["status": "approved"])
        } else {
            try await appRef.updateData(["status": "declined"])
        }
    }
    
    func startListeningForApplications(guildId: String) {
        applicationsListener?.remove()
        
        applicationsListener = db.collection("guilds").document(guildId)
            .collection("applications")
            .whereField("status", isEqualTo: "pending")
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if error != nil {
                    // Non-fatal; applications list may be stale.
                    return
                }

                guard let documents = snapshot?.documents else { return }
                self.applications = documents.compactMap { try? $0.data(as: GuildApplication.self) }
            }
    }
    
    func stopListening() {
        guildsListener?.remove()
        applicationsListener?.remove()
        guildsListener = nil
        applicationsListener = nil
    }
}
