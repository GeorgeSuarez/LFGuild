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
    @State private var guild: GuildModel?
    @State private var isRefreshingBattleNet = false
    @State private var battleNetError: String?

    var body: some View {
        NavigationView {
            ScrollView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(card.title)
                                    .font(.largeTitle)
                                    .fontWeight(.bold)

                                if let faction = guild?.faction {
                                    HStack(spacing: 4) {
                                        Image(systemName: factionIcon(faction))
                                            .font(.caption)
                                        Text(faction)
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                    }
                                    .foregroundStyle(factionColor(faction))
                                }
                            }

                            Spacer()

                            VStack(alignment: .trailing) {
                                HStack(spacing: 4) {
                                    Image(systemName: "person.2.fill")
                                        .font(.subheadline)
                                    Text("\(displayedMemberCount) members")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }
                                .foregroundStyle(.blue)

                                if let lastSynced = guild?.battleNetLastSyncedAt {
                                    Text("Synced \(lastSynced, formatter: dateFormatter)")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        
                        if card.matchScore > 0 {
                            HStack {
                                Image(systemName: "star.fill")
                                    .foregroundColor(.yellow)
                                Text("\(Int((matchBreakdown?.total ?? card.matchScore) * 100))% Match")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.yellow)
                                Spacer()
                            }
                        }

                        if let breakdown = matchBreakdown, breakdown.total > 0 {
                            MatchScoreBreakdownView(breakdown: breakdown)
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

                        if let officers = guild?.battleNetOfficers, !officers.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Leadership")
                                    .font(.headline)
                                    .fontWeight(.semibold)

                                VStack(alignment: .leading, spacing: 6) {
                                    ForEach(officers, id: \.self) { officer in
                                        HStack {
                                            Image(systemName: officer.isGuildMaster ? "crown.fill" : "shield.fill")
                                                .foregroundStyle(officer.isGuildMaster ? .yellow : .orange)
                                                .frame(width: 20)

                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(officer.name)
                                                    .font(.body)
                                                    .fontWeight(.medium)
                                                Text("\(officer.displayTitle) · Lv. \(officer.level) \(officer.playableClass)")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }

                                            Spacer()
                                        }
                                    }
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.05))
                                .clipShape(.rect(cornerRadius: 8))
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
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        isPresented = false
                    }
                }

                if isCurrentUserLeader {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: refreshBattleNet) {
                            if isRefreshingBattleNet {
                                ProgressView()
                            } else {
                                Image(systemName: "arrow.clockwise")
                            }
                        }
                        .disabled(isRefreshingBattleNet)
                        .accessibilityLabel("Refresh Battle.net data")
                    }
                }
            }
            .task {
                await loadGuild()
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

    private var isCurrentUserLeader: Bool {
        guard let currentUserId = authManager.currentUser?.firebaseUID,
              let leaderId = guild?.leaderId else { return false }
        return currentUserId == leaderId
    }

    /// Recomputes the match breakdown from the loaded guild + current user so
    /// the "Why You Matched" section reflects the freshest guild data.
    private var matchBreakdown: MatchScoreBreakdown? {
        guard let user = authManager.currentUser,
              let guild else { return nil }
        return MatchScorer.breakdown(user: user, guild: guild)
    }

    private var displayedMemberCount: Int {
        guild?.battleNetMemberCount ?? card.memberCount
    }

    private func loadGuild() async {
        guard let guildId = card.guildId else { return }
        guild = await guildManager.fetchGuild(byId: guildId)
    }

    private func refreshBattleNet() {
        guard let guildId = card.guildId else { return }
        isRefreshingBattleNet = true
        battleNetError = nil

        Task {
            do {
                let updated = try await guildManager.refreshBattleNetData(for: guildId)
                await MainActor.run {
                    guild = updated
                    isRefreshingBattleNet = false
                }
            } catch {
                await MainActor.run {
                    isRefreshingBattleNet = false
                    battleNetError = error.localizedDescription
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }

    private func factionColor(_ faction: String) -> Color {
        switch faction.lowercased() {
        case "alliance":
            return .blue
        case "horde":
            return .red
        default:
            return .primary
        }
    }

    private func factionIcon(_ faction: String) -> String {
        switch faction.lowercased() {
        case "alliance":
            return "a.circle.fill"
        case "horde":
            return "h.circle.fill"
        default:
            return "flag.fill"
        }
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }
}

struct MatchScoreBreakdownView: View {
    let breakdown: MatchScoreBreakdown

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Why You Matched")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(Int(breakdown.total * 100))%")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.yellow)
            }

            ForEach(breakdown.rows, id: \.label) { row in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(row.label)
                            .font(.subheadline)
                        Spacer()
                        Text("+\(Int(row.points * 100))")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    }
                    ProgressView(value: row.portion)
                        .tint(row.portion > 0.6 ? .green : (row.portion > 0 ? .blue : .gray))
                }
            }
        }
        .padding()
        .background(Color.yellow.opacity(0.05))
        .clipShape(.rect(cornerRadius: 12))
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
