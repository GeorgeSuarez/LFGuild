//
//  SeedDataView.swift
//  LFGuild
//
//  DEBUG-only view for populating Firestore with sample guilds and bot users.
//

import SwiftUI

#if DEBUG
struct SeedDataView: View {
    @EnvironmentObject private var authManager: AuthenticationManager
    @StateObject private var seedManager = SeedManager()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.green)

                Text("Seed Sample Data")
                    .font(.title)
                    .fontWeight(.bold)

                Text("This creates sample guilds and bot users in Firestore for testing. You must be signed in with a verified email account.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                if seedManager.isSeeding {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text(seedManager.progressMessage)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    VStack(spacing: 8) {
                        Text("Seeded \(seedManager.seededGuildCount) guild(s)")
                        Text("Seeded \(seedManager.seededBotCount) bot user(s)")
                        Text("Seeded \(seedManager.seededConversationCount) conversation(s)")
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }

                if let error = seedManager.lastError {
                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Spacer()

                Button(action: seed) {
                    HStack {
                        if seedManager.isSeeding {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        }
                        Text(seedManager.isSeeding ? "Seeding..." : "Seed Data")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(seedManager.isSeeding ? Color.gray : Color.green)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(seedManager.isSeeding)
            }
            .padding()
            .navigationTitle("Debug Seeding")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func seed() {
        guard let user = authManager.currentUser else { return }
        Task {
            await seedManager.seed(currentUser: user)
        }
    }
}

#Preview {
    SeedDataView()
        .environmentObject(AuthenticationManager())
}
#endif
