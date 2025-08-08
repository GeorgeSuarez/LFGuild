//
//  ChatView.swift
//  LFGuild
//
//  Created by George Suarez on 8/3/25.
//

import SwiftUI

struct ChatView: View {
    let conversation: Conversation
    @EnvironmentObject private var authManager: AuthenticationManager
    @EnvironmentObject private var messagingManager: MessagingManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var messageText = ""
    @State private var showingError = false
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Messages List
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(messagingManager.currentMessages) { message in
                                MessageBubbleView(
                                    message: message,
                                    isFromCurrentUser: message.senderId == authManager.currentUser?.firebaseUID
                                )
                                .id(message.id)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: messagingManager.currentMessages.count) { _, _ in
                        if let lastMessage = messagingManager.currentMessages.last {
                            withAnimation(.easeOut(duration: 0.3)) {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }
                
                Divider()
                
                // Message Input
                HStack(spacing: 12) {
                    TextField("Type a message...", text: $messageText, axis: .vertical)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .focused($isTextFieldFocused)
                        .lineLimit(1...4)
                    
                    Button(action: sendMessage) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : .blue)
                    }
                    .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || messagingManager.isLoading)
                }
                .padding()
                .background(Color(.systemBackground))
            }
            .navigationTitle(conversation.participantName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                if let currentUserId = authManager.currentUser?.firebaseUID {
                    messagingManager.startListeningForMessages(
                        conversationId: conversation.id,
                        currentUserId: currentUserId
                    )
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(messagingManager.error?.errorDescription ?? "An error occurred")
            }
        }
    }
    
    private func sendMessage() {
        guard let currentUser = authManager.currentUser,
              !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        let content = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        messageText = ""
        
        // Create recipient UserModel from conversation
        let recipient = UserModel(
            firebaseUID: conversation.participantId,
            name: conversation.participantName,
            email: "", // We don't have email in conversation, but it's not needed for messaging
            countryRegion: ""
        )
        
        Task {
            do {
                try await messagingManager.sendMessage(
                    to: recipient,
                    content: content,
                    currentUser: currentUser
                )
            } catch {
                messagingManager.error = error as? MessageError ?? .sendFailed
                showingError = true
            }
        }
    }
}

struct MessageBubbleView: View {
    let message: Message
    let isFromCurrentUser: Bool
    
    var body: some View {
        HStack {
            if isFromCurrentUser {
                Spacer(minLength: 50)
            }
            
            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                if !isFromCurrentUser {
                    Text(message.senderName)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Text(message.content)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(isFromCurrentUser ? Color.blue : Color(.systemGray5))
                    .foregroundColor(isFromCurrentUser ? .white : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                
                Text(formatMessageTime(message.timestamp))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            if !isFromCurrentUser {
                Spacer(minLength: 50)
            }
        }
    }
    
    private func formatMessageTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    let conversation = Conversation(
        id: "preview",
        participantId: "user123",
        participantName: "John Doe",
        lastMessage: nil,
        unreadCount: 0
    )
    
    ChatView(conversation: conversation)
        .environmentObject(AuthenticationManager())
        .environmentObject(MessagingManager())
}
