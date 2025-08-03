//
//  CoversationRowView.swift
//  LFGuild
//
//  Created by George Suarez on 8/3/25.
//

import SwiftUI

struct ConversationRowView: View {
    let conversation: Conversation
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Avatar
                Circle()
                    .fill(Color.blue.opacity(0.3))
                    .frame(width: 50, height: 50)
                    .overlay {
                        Text(String(conversation.participantName.prefix(1).uppercased()))
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                    }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(conversation.participantName)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        if let lastMessage = conversation.lastMessage {
                            Text(formatTime(lastMessage.timestamp))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    HStack {
                        Text(conversation.lastMessage?.content ?? "No messages yet")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        if conversation.unreadCount > 0 {
                            Text("\(conversation.unreadCount)")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .frame(minWidth: 18, minHeight: 18)
                                .background(Color.red)
                                .clipShape(Circle())
                        }
                    }
                }
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        let now = Date()
        let calendar = Calendar.current
        
        if calendar.isDateInToday(date) {
            formatter.timeStyle = .short
            return formatter.string(from: date)
        } else if calendar.isDate(date, equalTo: now, toGranularity: .weekOfYear) {
            formatter.dateFormat = "E"
            return formatter.string(from: date)
        } else {
            formatter.dateStyle = .short
            return formatter.string(from: date)
        }
    }
}

#Preview {
    let conversation = Conversation(id: "123", participantId: "123", participantName: "Tim Cheese", lastMessage: Message(senderId: "321", senderName: "John Prok", recipientName: "Tim Cheese", recipientId: "123", content: "Type shii"), unreadCount: 12)
    ConversationRowView(conversation: conversation, onTap: {})
        .environmentObject(AuthenticationManager())
}
