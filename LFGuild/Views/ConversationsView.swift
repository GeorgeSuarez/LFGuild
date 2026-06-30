//
//  ConversationsView.swift
//  LFGuild
//
//  Created by George Suarez on 8/3/25.
//

import SwiftUI

struct ConversationsView: View {
    @EnvironmentObject private var authManager: AuthenticationManager
    @EnvironmentObject private var notificationRouter: NotificationRouter
    @StateObject private var messagingManager = MessagingManager()
    @State private var showingNewMessage = false
    @State private var selectedConversation: Conversation?

    var body: some View {
        VStack {
            if messagingManager.conversations.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "message")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    
                    Text("No Messages Yet")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("Start a conversation by messaging someone!")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button("New Message") {
                        showingNewMessage = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                Spacer()
            } else {
                List {
                    ForEach(messagingManager.conversations) { conversation in
                        ConversationRowView(conversation: conversation) {
                            selectedConversation = conversation
                        }
                    }
                }
                .listStyle(PlainListStyle())
            }
        }
        .navigationTitle("Messages")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showingNewMessage = true
                }) {
                    Image(systemName: "square.and.pencil")
                }
            }
        }
        .sheet(isPresented: $showingNewMessage) {
            NewMessageView()
                .environmentObject(authManager)
                .environmentObject(messagingManager)
        }
        .sheet(item: $selectedConversation) { conversation in
            ChatView(conversation: conversation)
                .environmentObject(authManager)
                .environmentObject(messagingManager)
        }
        .onAppear {
            if let currentUser = authManager.currentUser,
               let userId = currentUser.firebaseUID {
                messagingManager.startListeningForConversations(currentUserId: userId)
            }

            presentRoutedConversationIfAvailable()
        }
        .onChange(of: messagingManager.conversations.count) { _, _ in
            presentRoutedConversationIfAvailable()
        }
        .onDisappear {
            messagingManager.stopListening()
        }
    }

    private func presentRoutedConversationIfAvailable() {
        guard let conversationId = notificationRouter.consumeConversationId() else { return }

        if let conversation = messagingManager.conversations.first(where: { $0.id == conversationId }) {
            selectedConversation = conversation
        }
    }
}

#Preview {
    ConversationsView()
        .environmentObject(AuthenticationManager())
        .environmentObject(NotificationRouter())
}
