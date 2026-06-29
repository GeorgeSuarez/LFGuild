//
//  CardDetailView.swift
//  LFGuild
//
//  Created by George Suarez on 8/2/25.
//

import SwiftUI

struct CardDetailView: View {
    let card: CardItem
    @Binding var isPresented: Bool
    @EnvironmentObject private var authManager: AuthenticationManager
    @StateObject private var messagingManager = MessagingManager()
    @StateObject private var guildManager = GuildManager()
    @State private var showingMessageComposer = false
    @State private var showingApplicationSheet = false
    @State private var showingError = false
    @State private var showingSuccess = false
    @State private var showingVerificationPrompt = false
    @State private var isSendingVerification = false
    @State private var errorMessage = ""
    @State private var successMessage = ""
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            ScrollView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text(card.title)
                                .font(.largeTitle)
                                .fontWeight(.bold)
                            
                            Spacer()
                            
                            VStack(alignment: .trailing) {
                                HStack(spacing: 4) {
                                    Image(systemName: "person.2.fill")
                                        .font(.subheadline)
                                    Text("\(card.memberCount) members")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }
                                .foregroundColor(.blue)
                            }
                        }
                        
                        if card.matchScore > 0 {
                            HStack {
                                Image(systemName: "star.fill")
                                    .foregroundColor(.yellow)
                                Text("\(Int(card.matchScore * 100))% Match")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.yellow)
                                Spacer()
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("About")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            Text(card.description)
                                .font(.body)
                                .foregroundColor(.primary)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Tags")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 8) {
                                ForEach(card.tags, id: \.self) { tag in
                                    Text(tag)
                                        .font(.caption)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.blue.opacity(0.1))
                                        .foregroundColor(.blue)
                                        .cornerRadius(12)
                                }
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Guild Leader")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            HStack {
                                Circle()
                                    .fill(Color.blue.opacity(0.3))
                                    .frame(width: 40, height: 40)
                                    .overlay {
                                        Text(String(card.leader.prefix(1)))
                                            .font(.headline)
                                            .fontWeight(.bold)
                                            .foregroundColor(.blue)
                                    }
                                
                                Text(card.leader)
                                    .font(.body)
                                    .fontWeight(.medium)
                                
                                Spacer()
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Server / Realm")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            HStack {
                                Image(systemName: "server.rack")
                                    .foregroundColor(.blue)
                                Text(card.serverRealm)
                                    .font(.body)
                                    .fontWeight(.medium)
                                Spacer()
                            }
                        }
                        
                        if !card.raidDays.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Raid Schedule")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Image(systemName: "calendar")
                                            .foregroundColor(.blue)
                                        Text("Days:")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        Text(card.raidDays.joined(separator: ", "))
                                            .font(.subheadline)
                                        Spacer()
                                    }
                                    
                                    if !card.raidTime.isEmpty {
                                        HStack {
                                            Image(systemName: "clock")
                                                .foregroundColor(.blue)
                                            Text("Time:")
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                            Text(card.raidTime)
                                                .font(.subheadline)
                                            Spacer()
                                        }
                                    }
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.05))
                                .cornerRadius(8)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Requirements")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            Text(card.requirements)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        
                        VStack(spacing: 12) {
                            Button(action: {
                                showingApplicationSheet = true
                            }) {
                                HStack {
                                    if isLoading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(0.8)
                                    }
                                    Text("Request to Join")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color.blue)
                                .cornerRadius(12)
                            }
                            .disabled(isLoading)
                            
                            Button(action: {
                                showingMessageComposer = true
                            }) {
                                HStack {
                                    Image(systemName: "message.fill")
                                    Text("Message Guild Leader")
                                }
                                .font(.headline)
                                .foregroundColor(.blue)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(12)
                            }
                        }
                        .padding(.top, 20)
                    }
                    .padding(.horizontal)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
            .sheet(isPresented: $showingMessageComposer) {
                MessageGuildLeaderView(guildLeader: card.leader)
                    .environmentObject(authManager)
                    .environmentObject(messagingManager)
            }
            .sheet(isPresented: $showingApplicationSheet) {
                GuildApplicationSheet(
                    guildName: card.title,
                    onSubmit: submitApplication
                )
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            .alert("Success", isPresented: $showingSuccess) {
                Button("OK") {
                    isPresented = false
                }
            } message: {
                Text(successMessage)
            }
            .alert("Verify Email", isPresented: $showingVerificationPrompt) {
                Button("Cancel", role: .cancel) { }
                Button("Send Verification Email") {
                    Task {
                        isSendingVerification = true
                        do {
                            try await authManager.sendEmailVerification()
                            successMessage = "Verification email sent. Please check your inbox."
                            showingSuccess = true
                        } catch {
                            errorMessage = error.localizedDescription
                            showingError = true
                        }
                        isSendingVerification = false
                    }
                }
                .disabled(isSendingVerification)
            } message: {
                Text("You need a verified email address to apply to guilds. Would you like us to send a verification email?")
            }
        }
    }

    private func submitApplication(message: String) {
        guard let guildId = card.guildId,
              let user = authManager.currentUser,
              let userId = user.firebaseUID else {
            errorMessage = "Unable to apply. Missing guild or user information."
            showingError = true
            return
        }

        isLoading = true

        Task {
            do {
                try await guildManager.applyToGuild(
                    guildId: guildId,
                    userId: userId,
                    userName: user.name,
                    message: message
                )

                await MainActor.run {
                    isLoading = false
                    successMessage = "Your application to \(card.title) has been submitted!"
                    showingSuccess = true
                }
            } catch GuildError.emailNotVerified {
                await MainActor.run {
                    isLoading = false
                    showingVerificationPrompt = true
                }
            } catch let error as GuildError {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Failed to submit application: \(error.localizedDescription)"
                    showingError = true
                }
            }
        }
    }
}

struct GuildApplicationSheet: View {
    let guildName: String
    let onSubmit: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var message = ""
    @FocusState private var isFocused: Bool
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Apply to \(guildName)")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Introduce yourself and tell the guild leader why you'd be a good fit.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                TextEditor(text: $message)
                    .focused($isFocused)
                    .frame(minHeight: 150)
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
                
                Spacer()
            }
            .padding()
            .navigationTitle("Application")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Submit") {
                        onSubmit(message)
                        dismiss()
                    }
                    .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                isFocused = true
            }
        }
    }
}

#Preview {
    let card = CardItem(title: "Some Guild Name", description: "Some Guild Description", memberCount: 32, tags: ["Raiding", "Mythic +", "PvP", "Social"], requirements: "Purple Parses or 3k IO", leader: "John Pork", raidDays: ["Tuesday", "Thursday", "Sunday"], raidTime: "8:00 PM - 11:00 PM EST", serverRealm: "Stormrage - US", guildId: "preview-guild-id")
    CardDetailView(card: card, isPresented: .constant(true))
        .environmentObject(AuthenticationManager())
        .environmentObject(MessagingManager())
}
