//
//  MessageGuildLeaderView.swift
//  LFGuild
//
//  Created by George Suarez on 8/3/25.
//

import SwiftUI

struct MessageGuildLeaderView: View {
    let guildLeader: String
    @EnvironmentObject private var authManager: AuthenticationManager
    @EnvironmentObject private var messagingManager: MessagingManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var messageText = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    @FocusState private var isMessageFocused: Bool
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("To: \(guildLeader)")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("Send a message to this guild leader")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Message")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    TextField("Hi! I'm interested in joining your guild...", text: $messageText, axis: .vertical)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .focused($isMessageFocused)
                        .lineLimit(4...8)
                }
                
                Button(action: sendMessage) {
                    HStack {
                        if messagingManager.isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "paperplane.fill")
                        }
                        Text("Send Message")
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(canSendMessage ? Color.blue : Color.gray)
                    .cornerRadius(12)
                }
                .disabled(!canSendMessage || messagingManager.isLoading)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Message Guild Leader")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                isMessageFocused = true
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private var canSendMessage: Bool {
        !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func sendMessage() {
        guard let currentUser = authManager.currentUser else {
            errorMessage = "User not authenticated"
            showingError = true
            return
        }
        
        let content = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        Task {
            do {
                try await messagingManager.sendMessage(
                    to: guildLeader,
                    content: content,
                    currentUser: currentUser
                )
                
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    if let messageError = error as? MessageError {
                        errorMessage = messageError.errorDescription ?? "An error occurred"
                    } else {
                        errorMessage = error.localizedDescription
                    }
                    showingError = true
                }
            }
        }
    }
}

#Preview {
    MessageGuildLeaderView(guildLeader: "Guild Leader Test")
        .environmentObject(AuthenticationManager())
        .environmentObject(MessagingManager())
}
