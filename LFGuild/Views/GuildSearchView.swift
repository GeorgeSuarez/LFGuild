//
//  GuildSearchView.swift
//  LFGuild
//
//  Created by George Suarez on 8/8/25.
//

import SwiftUI

struct GuildSearchView: View {
    @EnvironmentObject private var authManager: AuthenticationManager
    @State private var selectedRealm: WoWRealm?
    @State private var searchResults: [GuildModel] = []
    @State private var selectedGuild: GuildModel?
    @State private var isLoading = false
    @State private var hasSearched = false
    @State private var errorMessage: String?
    @State private var showingError = false

    private let searchableRealms = WoWRealm.allCases
    private let maxResults = 5

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                realmSelectorSection
                searchButtonSection
                resultsSection
            }
            .navigationTitle("Search Guilds")
            .navigationBarTitleDisplayMode(.large)
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage ?? "Unable to load guilds.")
            }
        }
        .sheet(isPresented: Binding(
            get: { selectedGuild != nil },
            set: { if !$0 { selectedGuild = nil } }
        )) {
            if let guild = selectedGuild {
                BattleNetGuildDetailView(
                    guild: guild,
                    isPresented: Binding(
                        get: { selectedGuild != nil },
                        set: { if !$0 { selectedGuild = nil } }
                    )
                )
            }
        }
    }

    // MARK: - Sections

    private var realmSelectorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Select a Realm")
                .font(.headline)
                .fontWeight(.semibold)

            Menu {
                ForEach(searchableRealms, id: \.self) { realm in
                    Button(action: { selectedRealm = realm }) {
                        HStack {
                            Text(realm.rawValue)
                            Spacer()
                            if selectedRealm == realm {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    Text(selectedRealm?.rawValue ?? "Choose a realm")
                        .foregroundColor(selectedRealm == nil ? .secondary : .primary)

                    Spacer()

                    Image(systemName: "chevron.down")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
    }

    private var searchButtonSection: some View {
        VStack(spacing: 12) {
            Button(action: performSearch) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    }

                    Text("Find Guilds")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(selectedRealm == nil || isLoading ? Color.gray : Color.blue)
                .cornerRadius(12)
            }
            .disabled(selectedRealm == nil || isLoading)
            .padding(.horizontal)
            .padding(.top, 8)
        }
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
    }

    @ViewBuilder
    private var resultsSection: some View {
        if isLoading && searchResults.isEmpty {
            LoadingSearchView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            resultsList
        }
    }

    private var resultsList: some View {
        List(displayedResults, id: \.self) { guild in
            BattleNetGuildRow(guild: guild)
                .onTapGesture {
                    selectedGuild = guild
                }
        }
        .listStyle(.plain)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay {
            emptyStateOverlay
        }
    }

    @ViewBuilder
    private var emptyStateOverlay: some View {
        if displayedResults.isEmpty && !isLoading {
            VStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 40))
                    .foregroundColor(.secondary)

                Text(hasSearched ? "No guilds found" : "Search for Guilds")
                    .font(.headline)
                    .fontWeight(.semibold)

                Text(hasSearched
                     ? "No valid guilds were returned for the selected realm. Try another realm."
                     : "Pick a realm and tap Find Guilds to see real WoW guilds from Battle.net.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
        }
    }

    // MARK: - Computed Properties

    /// Returns the top popular guilds from the selected realm, capped for testing.
    private var displayedResults: [GuildModel] {
        Array(searchResults.prefix(maxResults))
    }

    // MARK: - Actions

    private func performSearch() {
        guard let realm = selectedRealm else { return }

        isLoading = true
        hasSearched = true
        errorMessage = nil

        Task {
            do {
                let results = try await BattleNetGuildSearchService.shared.searchGuilds(on: realm)
                await MainActor.run {
                    searchResults = results
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showingError = true
                    isLoading = false
                }
            }
        }
    }

}

// MARK: - Row

struct BattleNetGuildRow: View {
    let guild: GuildModel

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(guild.name)
                    .font(.headline)
                    .fontWeight(.semibold)

                HStack(spacing: 4) {
                    if let faction = guild.faction {
                        Text(faction)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(factionColor(faction))
                    }

                    Text("· \(guild.memberCount) members")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Text(guild.serverRealm)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .font(.caption)
        }
        .padding(.vertical, 8)
    }

    private func factionColor(_ faction: String?) -> Color {
        switch faction?.lowercased() {
        case "alliance":
            return .blue
        case "horde":
            return .red
        default:
            return .gray
        }
    }
}

struct LoadingSearchView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading guilds from Battle.net...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    GuildSearchView()
        .environmentObject(AuthenticationManager())
        .environmentObject(NotificationRouter())
}
