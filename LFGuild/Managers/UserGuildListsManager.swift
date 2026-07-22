//
//  UserGuildListsManager.swift
//  LFGuild
//
//  Persists per-user saved ("favorite") guilds and dismissed ("hidden") guilds
//  so they can be reused across the matching carousel and the search screen.
//

import Foundation
import FirebaseFirestore

@MainActor
final class UserGuildListsManager: ObservableObject {
    static let shared = UserGuildListsManager()

    @Published private(set) var favoriteGuildIds: Set<String> = []
    @Published private(set) var hiddenGuildIds: Set<String> = []

    private let db = Firestore.firestore()
    private var userId: String?

    private init() {}

    /// Loads favorites + hidden IDs for the given user. Safe to call on user
    /// change; clears state when signing out.
    func configure(for userId: String?) async {
        self.userId = userId
        guard let userId else {
            favoriteGuildIds = []
            hiddenGuildIds = []
            return
        }
        await loadLists(userId: userId)
    }

    private func loadLists(userId: String) async {
        async let favorites = fetchIds(collection: "favorites", userId: userId)
        async let hidden = fetchIds(collection: "hiddenGuilds", userId: userId)
        let (fav, hid) = await (favorites, hidden)
        favoriteGuildIds = fav
        hiddenGuildIds = hid
    }

    private func fetchIds(collection: String, userId: String) async -> Set<String> {
        do {
            let snapshot = try await db.collection("users")
                .document(userId)
                .collection(collection)
                .getDocuments()
            return Set(snapshot.documents.map { $0.documentID })
        } catch {
            return []
        }
    }

    // MARK: - Favorites

    func isFavorite(_ guildId: String?) -> Bool {
        guard let guildId else { return false }
        return favoriteGuildIds.contains(guildId)
    }

    func toggleFavorite(guildId: String) async {
        guard let userId else { return }
        let ref = db.collection("users").document(userId)
            .collection("favorites").document(guildId)

        if favoriteGuildIds.contains(guildId) {
            do { try await ref.delete() } catch { return }
            favoriteGuildIds.remove(guildId)
        } else {
            do {
                try await ref.setData([
                    "guildId": guildId,
                    "savedAt": FieldValue.serverTimestamp()
                ])
                favoriteGuildIds.insert(guildId)
            } catch {
                return
            }
        }
    }

    // MARK: - Hidden / "Not interested"

    func isHidden(_ guildId: String?) -> Bool {
        guard let guildId else { return false }
        return hiddenGuildIds.contains(guildId)
    }

    func hideGuild(guildId: String) async {
        guard let userId, !hiddenGuildIds.contains(guildId) else { return }
        let ref = db.collection("users").document(userId)
            .collection("hiddenGuilds").document(guildId)
        do {
            try await ref.setData([
                "guildId": guildId,
                "hiddenAt": FieldValue.serverTimestamp()
            ])
            hiddenGuildIds.insert(guildId)
        } catch {
            return
        }
    }

    func unhideGuild(guildId: String) async {
        guard let userId, hiddenGuildIds.contains(guildId) else { return }
        let ref = db.collection("users").document(userId)
            .collection("hiddenGuilds").document(guildId)
        do { try await ref.delete() } catch { return }
        hiddenGuildIds.remove(guildId)
    }
}