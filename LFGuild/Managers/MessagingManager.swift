//
//  MessagingManager.swift
//  LFGuild
//
//  Created by George Suarez on 8/3/25.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

@MainActor
class MessagingManager: ObservableObject {
    @Published var conversations: [Conversation] = []
    @Published var currentMessages: [Message] = []
    @Published var isLoading = false
    @Published var error: MessageError?
    
    
    private let db = Firestore.firestore()
    private var conversationListener: ListenerRegistration?
    private var messagesListener: ListenerRegistration?
    private var cancellables: Set<AnyCancellable> = []
    
    deinit {
        conversationListener?.remove()
        messagesListener?.remove()
    }
    
    func startListeningForConversations(currentUserId: String) {
        conversationListener?.remove()
        
        conversationListener = db.collection("messages")
            .whereField("participantIds", arrayContains: currentUserId)
            .order(by: "lastMessageTime", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if error != nil {
                    self.error = .loadFailed
                    return
                }

                guard let documents = snapshot?.documents else { return }

                Task {
                    await self.processConversationDocuments(documents, currentUserId: currentUserId)
                }
            }

    }

    func startListeningForMessages(conversationId: String, currentUserId: String) {
        messagesListener?.remove()
        currentMessages = []

        messagesListener = db.collection("messages")
            .document(conversationId)
            .collection("messages")
            .order(by: "timestamp", descending: false)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }

                if error != nil {
                    self.error = .loadFailed
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                let messages = documents.compactMap { doc -> Message? in
                    let data = doc.data()
                    return Message(
                        id: doc.documentID,
                        senderId: data["senderId"] as? String ?? "",
                        senderName: data["senderName"] as? String ?? "",
                        recipientName: data["recipientName"] as? String ?? "",
                        recipientId: data["recipientId"] as? String ?? "",
                        content: data["content"] as? String ?? "",
                        timestamp: (data["timestamp"] as? Timestamp)?.dateValue() ?? Date(),
                        isRead: data["isRead"] as? Bool ?? false
                    )
                }
                
                self.currentMessages = messages
                
                Task {
                    await self.markMessagesAsRead(conversationId: conversationId, currentUserId: currentUserId)
                }
            }
    }
    
    func sendMessage(to recipientNickname: String, content: String, currentUser: UserModel) async throws {
        isLoading = true
        defer { isLoading = false }

        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContent.isEmpty else {
            throw MessageError.sendFailed
        }
        guard trimmedContent.count <= 2000 else {
            throw MessageError.sendFailed
        }

        let recipientQuery = db.collection("publicProfiles")
            .whereField("name", isEqualTo: recipientNickname)
            .limit(to: 1)

        let recipientSnapshot = try await recipientQuery.getDocuments()

        guard let recipientDoc = recipientSnapshot.documents.first else {
            throw MessageError.userNotFound
        }

        let recipientId = recipientDoc.documentID
        let recipientData = recipientDoc.data()
        let recipientName = recipientData["name"] as? String ?? recipientNickname

        guard let currentUserId = currentUser.firebaseUID else {
            throw MessageError.invalidReceipient
        }

        let message = Message(
            senderId: currentUserId,
            senderName: currentUser.name,
            recipientName: recipientName,
            recipientId: recipientId,
            content: trimmedContent
        )
        
        let conversationId = createConversationId(userId1: currentUserId, userId2: recipientId)
        
        try await saveMessage(message, conversationId: conversationId)
        
        try await updateConversationMetadata(
            conversationId: conversationId,
            message: message,
            currentUserId: currentUserId,
            recipientId: recipientId
        )
    }
    
    func sendMessage(to recipient: UserModel, content: String, currentUser: UserModel) async throws {
        guard let recipientId = recipient.firebaseUID,
              let currentUserId = currentUser.firebaseUID else {
            throw MessageError.invalidReceipient
        }

        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContent.isEmpty else {
            throw MessageError.sendFailed
        }
        guard trimmedContent.count <= 2000 else {
            throw MessageError.sendFailed
        }

        isLoading = true
        defer { isLoading = false }

        let message = Message(
            senderId: currentUserId,
            senderName: currentUser.name,
            recipientName: recipient.name,
            recipientId: recipientId,
            content: trimmedContent
        )
        
        let conversationId = createConversationId(userId1: currentUserId, userId2: recipientId)
        
        try await saveMessage(message, conversationId: conversationId)
        try await updateConversationMetadata(
            conversationId: conversationId,
            message: message,
            currentUserId: currentUserId,
            recipientId: recipientId
        )
    }
    
    func stopListening() {
        conversationListener?.remove()
        messagesListener?.remove()
        conversationListener = nil
        messagesListener = nil
    }
    
    private func processConversationDocuments(_ documents: [QueryDocumentSnapshot], currentUserId: String) async {
        var newConversations: [Conversation] = []
        
        for doc in documents {
            let data = doc.data()
            let participantIds = data["participantIds"] as? [String] ?? []
            
            // Find the other participant
            guard let otherParticipantId = participantIds.first(where: { $0 != currentUserId }) else {
                continue
            }
            
            let participantName = data["participantNames"] as? [String: String] ?? [:]
            let otherParticipantName = participantName[otherParticipantId] ?? "Unknown"
            
            // Get last message data
            let lastMessageData = data["lastMessage"] as? [String: Any]
            let lastMessage = lastMessageData != nil ? Message(
                id: lastMessageData?["id"] as? String ?? "",
                senderId: lastMessageData?["senderId"] as? String ?? "",
                senderName: lastMessageData?["senderName"] as? String ?? "",
                recipientName: lastMessageData?["recipientName"] as? String ?? "",
                recipientId: lastMessageData?["recipientId"] as? String ?? "",
                content: lastMessageData?["content"] as? String ?? "",
                timestamp: (lastMessageData?["timestamp"] as? Timestamp)?.dateValue() ?? Date(),
                isRead: lastMessageData?["isRead"] as? Bool ?? false
            ) : nil
            
            let unreadCount = data["unreadCount"] as? [String: Int] ?? [:]
            let userUnreadCount = unreadCount[currentUserId] ?? 0
            
            let conversation = Conversation(
                id: doc.documentID,
                participantId: otherParticipantId,
                participantName: otherParticipantName,
                lastMessage: lastMessage,
                unreadCount: userUnreadCount
            )
            
            newConversations.append(conversation)
        }
        
        self.conversations = newConversations.sorted { $0.lastMessageTime > $1.lastMessageTime }
    }
    
    private func saveMessage(_ message: Message, conversationId: String) async throws {
        let messageData: [String: Any] = [
            "senderId": message.senderId,
            "senderName": message.senderName,
            "recipientId": message.recipientId,
            "recipientName": message.recipientName,
            "content": message.content,
            "timestamp": Timestamp(date: message.timestamp),
            "isRead": message.isRead
        ]
        
        try await db.collection("messages")
            .document(conversationId)
            .collection("messages")
            .document(message.id)
            .setData(messageData)
    }
    
    private func updateConversationMetadata(conversationId: String, message: Message, currentUserId: String, recipientId: String) async throws {
        let conversationRef = db.collection("messages").document(conversationId)
        
        let lastMessageData: [String: Any] = [
            "id": message.id,
            "senderId": message.senderId,
            "senderName": message.senderName,
            "recipientId": message.recipientId,
            "recipientName": message.recipientName,
            "content": message.content,
            "timestamp": Timestamp(date: message.timestamp),
            "isRead": message.isRead
        ]
        
        let conversationData: [String: Any] = [
            "participantIds": [currentUserId, recipientId],
            "participantNames": [
                currentUserId: message.senderName,
                recipientId: message.recipientName
            ],
            "lastMessage": lastMessageData,
            "lastMessageTime": Timestamp(date: message.timestamp),
            "unreadCount": [
                currentUserId: 0,
                recipientId: FieldValue.increment(Int64(1))
            ]
        ]
        
        try await conversationRef.setData(conversationData, merge: true)
    }
    
    private func markMessagesAsRead(conversationId: String, currentUserId: String) async {
        do {
            // Reset unread count for current user
            try await db.collection("messages")
                .document(conversationId)
                .updateData([
                    "unreadCount.\(currentUserId)": 0
                ])
            
            // Mark unread messages as read
            let unreadMessages = try await db.collection("messages")
                .document(conversationId)
                .collection("messages")
                .whereField("recipientId", isEqualTo: currentUserId)
                .whereField("isRead", isEqualTo: false)
                .getDocuments()
            
            let batch = db.batch()
            for doc in unreadMessages.documents {
                batch.updateData(["isRead": true], forDocument: doc.reference)
            }
            try await batch.commit()
            
        } catch {
            // Non-fatal; unread counts will retry on next snapshot.
        }
    }
    
    private func createConversationId(userId1: String, userId2: String) -> String {
        return [userId1, userId2].sorted().joined(separator: "_")
    }
}
