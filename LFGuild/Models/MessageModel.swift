//
//  MessageModel.swift
//  LFGuild
//
//  Created by George Suarez on 8/3/25.
//

import Foundation
import FirebaseFirestore

struct Message: Identifiable, Codable {
    let id: String
    let senderId: String
    let senderName: String
    let recipientName: String
    let recipientId: String
    let content: String
    let timestamp: Date
    let isRead: Bool
    
    init(id: String = UUID().uuidString,
         senderId: String,
         senderName: String,
         recipientName: String,
         recipientId: String,
         content: String,
         timestamp: Date = Date(),
         isRead: Bool = false)
    {
        self.id = id
        self.senderId = senderId
        self.senderName = senderName
        self.recipientName = recipientName
        self.recipientId = recipientId
        self.content = content
        self.timestamp = timestamp
        self.isRead = isRead
    }
}

struct Conversation: Identifiable {
    let id: String
    let participantId: String
    let participantName: String
    let lastMessage: Message?
    let unreadCount: Int
    
    var lastMessageTime: Date {
        return lastMessage?.timestamp ?? Date.distantPast
    }
}

enum MessageError: LocalizedError {
    case userNotFound
    case invalidReceipient
    case sendFailed
    case loadFailed
    
    var errorDescription: String? {
        switch self {
        case .userNotFound:
            return "User not found"
        case .invalidReceipient:
            return "Invalid recipient"
        case .sendFailed:
            return "Failed to send message"
        case .loadFailed:
            return "Failed to load message"
        
        }
    }
}
