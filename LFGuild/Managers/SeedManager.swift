//
//  SeedManager.swift
//  LFGuild
//
//  DEBUG-only helper for populating Firestore with sample guilds, bot users,
//  conversations, and messages.
//

import Foundation
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore

#if DEBUG
enum SeedingError: LocalizedError {
    case notSignedIn
    case emailNotVerified
    case missingFirebaseConfig
    case networkError(String)
    case firestoreError(String)

    var errorDescription: String? {
        switch self {
        case .notSignedIn:
            return "You must be signed in to seed data."
        case .emailNotVerified:
            return "Only verified email users can create sample guilds."
        case .missingFirebaseConfig:
            return "Firebase configuration is missing."
        case .networkError(let message):
            return "Network error: \(message)"
        case .firestoreError(let message):
            return "Firestore error: \(message)"
        }
    }
}

/// Populates Firestore with sample guilds, bot users, and conversations for development/testing.
/// Guilds are created with the current verified user as leader. Bot users, their public profiles,
/// and sample conversations are created via the Firebase Auth/Firestore REST APIs so the current
/// user's session is preserved.
@MainActor
final class SeedManager: ObservableObject {
    @Published var isSeeding = false
    @Published var progressMessage = ""
    @Published var lastError: SeedingError?
    @Published var seededGuildCount = 0
    @Published var seededBotCount = 0
    @Published var seededConversationCount = 0

    private let db = Firestore.firestore()

    func seed(currentUser: UserModel) async {
        guard !isSeeding else { return }

        isSeeding = true
        lastError = nil
        seededGuildCount = 0
        seededBotCount = 0
        seededConversationCount = 0

        do {
            progressMessage = "Checking permissions..."
            guard let firebaseUser = Auth.auth().currentUser else {
                throw SeedingError.notSignedIn
            }
            guard !firebaseUser.isAnonymous, firebaseUser.isEmailVerified else {
                throw SeedingError.emailNotVerified
            }
            guard let uid = firebaseUser.uid as String? else {
                throw SeedingError.notSignedIn
            }

            // Reload the user so the ID token reflects the latest email verification status.
            // Firebase may cache an older token that still claims email_verified == false.
            try await firebaseUser.reload()
            if !firebaseUser.isEmailVerified {
                throw SeedingError.emailNotVerified
            }

            let currentUserIdToken = try await firebaseUser.getIDToken()

            progressMessage = "Seeding sample guilds..."
            let guildCount = try await seedGuilds(leaderId: uid, leaderName: currentUser.name)
            seededGuildCount = guildCount

            progressMessage = "Seeding bot users..."
            let bots = try await seedBotUsers()
            seededBotCount = bots.count

            progressMessage = "Seeding sample conversations..."
            let conversationCount = try await seedConversations(
                currentUserId: uid,
                currentUserName: currentUser.name,
                currentUserIdToken: currentUserIdToken,
                bots: bots
            )
            seededConversationCount = conversationCount

            progressMessage = "Seeded \(guildCount) guild(s), \(bots.count) bot user(s), and \(conversationCount) conversation(s)."
        } catch let error as SeedingError {
            lastError = error
        } catch {
            lastError = Self.seedingError(from: error)
        }

        isSeeding = false
    }

    private static func seedingError(from error: Error) -> SeedingError {
        let nsError = error as NSError
        if nsError.domain == "FirebaseFirestore" && nsError.code == 7 {
            return .firestoreError(
                "Permission denied. Make sure your Firestore rules are deployed and the current user has a verified email address."
            )
        }
        return .networkError(error.localizedDescription)
    }

    // MARK: - Guilds

    private func seedGuilds(leaderId: String, leaderName: String) async throws -> Int {
        let sampleGuilds = makeSampleGuilds(leaderId: leaderId, leaderName: leaderName)

        for guild in sampleGuilds {
            let guildRef = db.collection("guilds").document()
            var newGuild = guild
            newGuild.id = guildRef.documentID

            try guildRef.setData(from: newGuild)

            let member = GuildMember(
                id: leaderId,
                userId: leaderId,
                name: leaderName,
                role: "Guild Leader",
                joinDate: Date(),
                status: .active
            )
            try guildRef.collection("members").document(leaderId).setData(from: member)
        }

        return sampleGuilds.count
    }

    private func makeSampleGuilds(leaderId: String, leaderName: String) -> [GuildModel] {
        [
            GuildModel(
                name: "Echoes of Azeroth",
                description: "A hardcore raiding guild focused on progression and weekly AOTC clears.",
                leaderId: leaderId,
                leaderName: leaderName,
                memberCount: 1,
                maxMembers: 30,
                tags: ["Raid Focused", "Hardcore"],
                requirements: "Must have relevant raid experience and Discord.",
                raidDays: ["Tuesday", "Thursday"],
                raidStartTime: "8:00 PM",
                raidEndTime: "11:00 PM",
                serverRealm: "Stormrage - US",
                region: "US",
                isActive: true,
                neededRoles: ["Tank", "Healer", "DPS"]
            ),
            GuildModel(
                name: "Casual Adventurers",
                description: "Friendly, laid-back guild for players who want to explore content at their own pace.",
                leaderId: leaderId,
                leaderName: leaderName,
                memberCount: 1,
                maxMembers: 50,
                tags: ["Casual", "Social"],
                requirements: "Be respectful and have fun.",
                raidDays: ["Saturday", "Sunday"],
                raidStartTime: "7:00 PM",
                raidEndTime: "10:00 PM",
                serverRealm: "Area-52 - US",
                region: "US",
                isActive: true,
                neededRoles: ["Healer", "DPS"]
            ),
            GuildModel(
                name: "Mythic Masters",
                description: "Push high Mythic+ keys and compete on the seasonal leaderboards.",
                leaderId: leaderId,
                leaderName: leaderName,
                memberCount: 1,
                maxMembers: 25,
                tags: ["Mythic+ Focused", "Hardcore"],
                requirements: "2.5k IO minimum, voice comms required.",
                raidDays: ["Monday", "Wednesday"],
                raidStartTime: "9:00 PM",
                raidEndTime: "12:00 AM",
                serverRealm: "Stormrage - US",
                region: "US",
                isActive: true,
                neededRoles: ["DPS"]
            ),
            GuildModel(
                name: "PvP Warband",
                description: "Battlegrounds, arenas, and world PvP enthusiasts welcome.",
                leaderId: leaderId,
                leaderName: leaderName,
                memberCount: 1,
                maxMembers: 40,
                tags: ["PvP", "Hardcore"],
                requirements: "PvP experience preferred but not required.",
                raidDays: ["Friday", "Saturday"],
                raidStartTime: "8:00 PM",
                raidEndTime: "11:00 PM",
                serverRealm: "Tichondrius - US",
                region: "US",
                isActive: true,
                neededRoles: ["Tank", "DPS"]
            ),
            GuildModel(
                name: "Weekend Warriors",
                description: "Weekend raiding guild with a focus on heroic progression and community events.",
                leaderId: leaderId,
                leaderName: leaderName,
                memberCount: 1,
                maxMembers: 35,
                tags: ["Casual", "Raid Focused"],
                requirements: "Willing to learn and improve.",
                raidDays: ["Saturday", "Sunday"],
                raidStartTime: "2:00 PM",
                raidEndTime: "5:00 PM",
                serverRealm: "Proudmoore - US",
                region: "US",
                isActive: true,
                neededRoles: ["Healer", "DPS"]
            ),
            GuildModel(
                name: "Raiding Renegades",
                description: "Semi-hardcore guild clearing current raid content on a two-night schedule.",
                leaderId: leaderId,
                leaderName: leaderName,
                memberCount: 1,
                maxMembers: 30,
                tags: ["Raid Focused", "Hardcore"],
                requirements: "Attendance required, research fights ahead of time.",
                raidDays: ["Wednesday", "Sunday"],
                raidStartTime: "8:00 PM",
                raidEndTime: "11:00 PM",
                serverRealm: "Illidan - US",
                region: "US",
                isActive: true,
                neededRoles: ["Tank", "Healer", "DPS"]
            ),
            GuildModel(
                name: "The Night Shift",
                description: "Late-night guild for players on odd schedules.",
                leaderId: leaderId,
                leaderName: leaderName,
                memberCount: 1,
                maxMembers: 25,
                tags: ["Casual", "Social"],
                requirements: "Active between 10 PM and 2 AM server time.",
                raidDays: ["Monday", "Tuesday", "Wednesday"],
                raidStartTime: "10:00 PM",
                raidEndTime: "1:00 AM",
                serverRealm: "Mal'Ganis - US",
                region: "US",
                isActive: true,
                neededRoles: ["Healer", "DPS"]
            ),
            GuildModel(
                name: "Dungeon Delvers",
                description: "All things dungeons — mythic+, timewalking, and achievement runs.",
                leaderId: leaderId,
                leaderName: leaderName,
                memberCount: 1,
                maxMembers: 45,
                tags: ["Mythic+ Focused", "Casual"],
                requirements: "No experience required, just bring a positive attitude.",
                raidDays: ["Thursday", "Friday"],
                raidStartTime: "7:00 PM",
                raidEndTime: "10:00 PM",
                serverRealm: "Dalaran - US",
                region: "US",
                isActive: true,
                neededRoles: ["Tank", "Healer", "DPS"]
            )
        ]
    }

    // MARK: - Bot Users

    private struct BotAccount {
        let uid: String
        let idToken: String
        let name: String
    }

    private func seedBotUsers() async throws -> [BotAccount] {
        guard let apiKey = FirebaseApp.app()?.options.apiKey,
              let projectID = FirebaseApp.app()?.options.projectID else {
            throw SeedingError.missingFirebaseConfig
        }

        let bots = makeSampleBotUsers()
        var createdBots: [BotAccount] = []

        for bot in bots {
            let signUpURL = URL(string: "https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=\(apiKey)")!
            let signUpBody: [String: Any] = ["returnSecureToken": true]
            let signUpResponse = try await postJSON(url: signUpURL, body: signUpBody)

            guard let idToken = signUpResponse["idToken"] as? String,
                  let uid = signUpResponse["localId"] as? String,
                  let name = bot["name"] as? String else {
                throw SeedingError.firestoreError("Failed to create bot user credentials.")
            }

            try await createPublicProfile(
                projectID: projectID,
                apiKey: apiKey,
                idToken: idToken,
                uid: uid,
                profile: bot
            )

            createdBots.append(BotAccount(uid: uid, idToken: idToken, name: name))
        }

        return createdBots
    }

    private func makeSampleBotUsers() -> [[String: Any]] {
        [
            [
                "name": "Aldric",
                "roles": ["Tank", "DPS"],
                "availableDays": ["Monday", "Wednesday", "Friday"],
                "gamingTags": ["Hardcore", "Raid Focused"],
                "preferredRealms": ["Stormrage - US"]
            ],
            [
                "name": "Lyra",
                "roles": ["Healer"],
                "availableDays": ["Tuesday", "Thursday", "Sunday"],
                "gamingTags": ["Casual", "Mythic+ Focused"],
                "preferredRealms": ["Area-52 - US"]
            ],
            [
                "name": "Thorne",
                "roles": ["Tank"],
                "availableDays": ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"],
                "gamingTags": ["Hardcore", "PvP"],
                "preferredRealms": ["Tichondrius - US"]
            ],
            [
                "name": "Mira",
                "roles": ["DPS", "Healer"],
                "availableDays": ["Saturday", "Sunday"],
                "gamingTags": ["Casual", "Social"],
                "preferredRealms": ["Proudmoore - US"]
            ],
            [
                "name": "Kael",
                "roles": ["DPS"],
                "availableDays": ["Wednesday", "Thursday", "Sunday"],
                "gamingTags": ["Raid Focused", "Hardcore"],
                "preferredRealms": ["Illidan - US"]
            ],
            [
                "name": "Sera",
                "roles": ["Healer", "DPS"],
                "availableDays": ["Monday", "Thursday"],
                "gamingTags": ["Mythic+ Focused", "Casual"],
                "preferredRealms": ["Dalaran - US"]
            ]
        ]
    }

    private func createPublicProfile(
        projectID: String,
        apiKey: String,
        idToken: String,
        uid: String,
        profile: [String: Any]
    ) async throws {
        let url = URL(string: "https://firestore.googleapis.com/v1/projects/\(projectID)/databases/(default)/documents/publicProfiles/\(uid)?key=\(apiKey)")!

        let firestoreFields = publicProfileFields(from: profile)
        let body: [String: Any] = ["fields": firestoreFields]

        try await patchDocument(url: url, idToken: idToken, body: body)
    }

    private func publicProfileFields(from profile: [String: Any]) -> [String: Any] {
        var fields: [String: Any] = [:]

        if let name = profile["name"] as? String {
            fields["name"] = ["stringValue": name]
        }
        if let roles = profile["roles"] as? [String] {
            fields["roles"] = ["arrayValue": ["values": roles.map { ["stringValue": $0] }]]
        }
        if let days = profile["availableDays"] as? [String] {
            fields["availableDays"] = ["arrayValue": ["values": days.map { ["stringValue": $0] }]]
        }
        if let tags = profile["gamingTags"] as? [String] {
            fields["gamingTags"] = ["arrayValue": ["values": tags.map { ["stringValue": $0] }]]
        }
        if let realms = profile["preferredRealms"] as? [String] {
            fields["preferredRealms"] = ["arrayValue": ["values": realms.map { ["stringValue": $0] }]]
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        fields["updatedAt"] = ["timestampValue": formatter.string(from: Date())]

        return fields
    }

    // MARK: - Conversations & Messages

    private func seedConversations(
        currentUserId: String,
        currentUserName: String,
        currentUserIdToken: String,
        bots: [BotAccount]
    ) async throws -> Int {
        guard let apiKey = FirebaseApp.app()?.options.apiKey,
              let projectID = FirebaseApp.app()?.options.projectID else {
            throw SeedingError.missingFirebaseConfig
        }

        var conversationCount = 0

        for bot in bots {
            let conversationId = createConversationId(userId1: currentUserId, userId2: bot.uid)
            let messages = sampleMessages(currentUserId: currentUserId, currentUserName: currentUserName, bot: bot)
            let lastMessage = messages.last!

            try await createConversationDocument(
                projectID: projectID,
                apiKey: apiKey,
                idToken: currentUserIdToken,
                conversationId: conversationId,
                participantIds: [currentUserId, bot.uid],
                participantNames: [currentUserId: currentUserName, bot.uid: bot.name],
                lastMessage: lastMessage,
                lastMessageTime: lastMessage.timestamp
            )

            for message in messages {
                let senderToken = message.senderId == currentUserId ? currentUserIdToken : bot.idToken
                try await createMessageDocument(
                    projectID: projectID,
                    apiKey: apiKey,
                    idToken: senderToken,
                    conversationId: conversationId,
                    message: message
                )
            }

            conversationCount += 1
        }

        return conversationCount
    }

    private func createConversationId(userId1: String, userId2: String) -> String {
        return [userId1, userId2].sorted().joined(separator: "_")
    }

    private func sampleMessages(currentUserId: String, currentUserName: String, bot: BotAccount) -> [SampleMessage] {
        let now = Date()
        let calendar = Calendar.current

        return [
            SampleMessage(
                senderId: currentUserId,
                senderName: currentUserName,
                recipientId: bot.uid,
                recipientName: bot.name,
                content: "Hey \(bot.name), I saw your profile and we seem to play at similar times!",
                timestamp: calendar.date(byAdding: .minute, value: -25, to: now) ?? now,
                isRead: true
            ),
            SampleMessage(
                senderId: bot.uid,
                senderName: bot.name,
                recipientId: currentUserId,
                recipientName: currentUserName,
                content: "Hi! Yeah, I'm usually on most weeknights. What content are you running?",
                timestamp: calendar.date(byAdding: .minute, value: -20, to: now) ?? now,
                isRead: true
            ),
            SampleMessage(
                senderId: currentUserId,
                senderName: currentUserName,
                recipientId: bot.uid,
                recipientName: bot.name,
                content: "Mostly raids and some M+. Are you in a guild right now?",
                timestamp: calendar.date(byAdding: .minute, value: -15, to: now) ?? now,
                isRead: true
            ),
            SampleMessage(
                senderId: bot.uid,
                senderName: bot.name,
                recipientId: currentUserId,
                recipientName: currentUserName,
                content: "I'm guildless at the moment. Looking for a friendly raiding group.",
                timestamp: calendar.date(byAdding: .minute, value: -10, to: now) ?? now,
                isRead: true
            ),
            SampleMessage(
                senderId: currentUserId,
                senderName: currentUserName,
                recipientId: bot.uid,
                recipientName: bot.name,
                content: "Cool, let me send you a guild invite link once I find a good match!",
                timestamp: calendar.date(byAdding: .minute, value: -5, to: now) ?? now,
                isRead: false
            )
        ]
    }

    private func createConversationDocument(
        projectID: String,
        apiKey: String,
        idToken: String,
        conversationId: String,
        participantIds: [String],
        participantNames: [String: String],
        lastMessage: SampleMessage,
        lastMessageTime: Date
    ) async throws {
        let url = URL(string: "https://firestore.googleapis.com/v1/projects/\(projectID)/databases/(default)/documents/messages/\(conversationId)?key=\(apiKey)")!

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        let body: [String: Any] = [
            "fields": [
                "participantIds": ["arrayValue": ["values": participantIds.map { ["stringValue": $0] }]],
                "participantNames": ["mapValue": ["fields": participantNames.mapValues { ["stringValue": $0] }]],
                "lastMessage": ["mapValue": ["fields": messageFields(lastMessage, formatter: formatter)]],
                "lastMessageTime": ["timestampValue": formatter.string(from: lastMessageTime)],
                "unreadCount": ["mapValue": ["fields": [
                    participantIds[0]: ["integerValue": "0"],
                    participantIds[1]: ["integerValue": "0"]
                ]]]
            ]
        ]

        try await patchDocument(url: url, idToken: idToken, body: body)
    }

    private func createMessageDocument(
        projectID: String,
        apiKey: String,
        idToken: String,
        conversationId: String,
        message: SampleMessage
    ) async throws {
        let url = URL(string: "https://firestore.googleapis.com/v1/projects/\(projectID)/databases/(default)/documents/messages/\(conversationId)/messages/\(message.id)?key=\(apiKey)")!

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        let body: [String: Any] = [
            "fields": messageFields(message, formatter: formatter)
        ]

        try await patchDocument(url: url, idToken: idToken, body: body)
    }

    private func messageFields(_ message: SampleMessage, formatter: ISO8601DateFormatter) -> [String: Any] {
        [
            "id": ["stringValue": message.id],
            "senderId": ["stringValue": message.senderId],
            "senderName": ["stringValue": message.senderName],
            "recipientId": ["stringValue": message.recipientId],
            "recipientName": ["stringValue": message.recipientName],
            "content": ["stringValue": message.content],
            "timestamp": ["timestampValue": formatter.string(from: message.timestamp)],
            "isRead": ["booleanValue": message.isRead]
        ]
    }

    // MARK: - Networking Helpers

    private func postJSON(url: URL, body: [String: Any]) async throws -> [String: Any] {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SeedingError.networkError("Invalid response.")
        }

        guard httpResponse.statusCode == 200 else {
            if let errorJSON = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let message = (errorJSON["error"] as? [String: Any])?["message"] as? String {
                throw SeedingError.networkError(message)
            }
            throw SeedingError.networkError("HTTP \(httpResponse.statusCode)")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SeedingError.networkError("Invalid JSON.")
        }

        return json
    }

    private func patchDocument(url: URL, idToken: String, body: [String: Any]) async throws {
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard statusCode == 200 else {
            if let errorJSON = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let message = (errorJSON["error"] as? [String: Any])?["message"] as? String {
                throw SeedingError.firestoreError(message)
            }
            throw SeedingError.firestoreError("HTTP \(statusCode)")
        }
    }
}

private struct SampleMessage {
    let id: String
    let senderId: String
    let senderName: String
    let recipientId: String
    let recipientName: String
    let content: String
    let timestamp: Date
    let isRead: Bool

    init(senderId: String, senderName: String, recipientId: String, recipientName: String, content: String, timestamp: Date, isRead: Bool) {
        self.id = UUID().uuidString
        self.senderId = senderId
        self.senderName = senderName
        self.recipientId = recipientId
        self.recipientName = recipientName
        self.content = content
        self.timestamp = timestamp
        self.isRead = isRead
    }
}
#endif
