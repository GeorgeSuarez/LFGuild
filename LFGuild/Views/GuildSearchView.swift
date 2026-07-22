//
//  GuildSearchView.swift
//  LFGuild
//
//  Created by George Suarez on 8/8/25.
//

import SwiftUI
import FirebaseFirestore

struct GuildSearchView: View {
    @EnvironmentObject private var authManager: AuthenticationManager
    @StateObject private var guildManager = GuildManager()
    @EnvironmentObject private var lists: UserGuildListsManager

    @State private var mode: SearchMode = .lfguild

    // Shared
    @State private var searchResults: [GuildModel] = []
    @State private var selectedGuild: GuildModel?
    @State private var isLoading = false
    @State private var hasSearched = false
    @State private var errorMessage: String?
    @State private var showingError = false

    // LFGuild (Firestore) search state
    @State private var searchQuery = ""
    @State private var filters = GuildSearchFilters.empty
    @State private var nextCursor: QueryDocumentSnapshot?
    @State private var isLoadingMore = false
    @State private var showingFilters = false
    @FocusState private var isSearchFieldFocused: Bool

    // Battle.net search state
    @State private var selectedRealm: WoWRealm?

    private let searchableRealms = WoWRealm.allCases
    private let pageSize = 20

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                modePicker
                switch mode {
                case .lfguild:
                    lfguildSearchSection
                    lfguildResultsSection
                case .battleNet:
                    realmSelectorSection
                    searchButtonSection
                    battleNetResultsSection
                }
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
        .sheet(isPresented: $showingFilters) {
            GuildSearchFiltersView(filters: $filters)
                .onDisappear {
                    // Re-run the LFGuild search whenever filters change.
                    if mode == .lfguild { Task { await runLfguildSearch(reset: true) } }
                }
        }
    }

    // MARK: - Mode picker

    private var modePicker: some View {
        Picker("Search Mode", selection: $mode) {
            Text("LFGuild").tag(SearchMode.lfguild)
            Text("Battle.net").tag(SearchMode.battleNet)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .padding(.top, 8)
        .onChange(of: mode) { _, _ in
            searchResults = []
            hasSearched = false
            nextCursor = nil
        }
    }

    // MARK: - LFGuild (Firestore) search

    private var lfguildSearchSection: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search by name or tag", text: $searchQuery)
                    .textFieldStyle(.plain)
                    .focused($isSearchFieldFocused)
                    .submitLabel(.search)
                    .onSubmit { Task { await runLfguildSearch(reset: true) } }

                if !searchQuery.isEmpty {
                    Button {
                        searchQuery = ""
                        Task { await runLfguildSearch(reset: true) }
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(.rect(cornerRadius: 12))

            HStack {
                Menu {
                    Picker("Sort", selection: $filters.sort) {
                        ForEach(GuildSearchSortOption.allCases) { option in
                            Text(option.label).tag(option)
                        }
                    }
                } label: {
                    Label(filters.sort.label, systemImage: "arrow.up.arrow.down")
                        .font(.subheadline)
                }

                Spacer()

                Button {
                    showingFilters = true
                } label: {
                    Label("Filters", systemImage: "line.3.horizontal.decrease.circle")
                        .font(.subheadline)
                        .foregroundColor(filters.isDefault ? Color.primary : Color.blue)
                }
            }
            .padding(.horizontal)
        }
        .padding(.top, 8)
        .background(.ultraThinMaterial)
    }

    @ViewBuilder
    private var lfguildResultsSection: some View {
        if isLoading && searchResults.isEmpty {
            LoadingSearchView(message: "Searching guilds...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            lfguildResultsList
        }
    }

    private var lfguildResultsList: some View {
        List {
            ForEach(searchResults, id: \.self) { guild in
                LFGuildGuildRow(
                    guild: guild,
                    isFavorite: lists.isFavorite(guild.id),
                    onToggleFavorite: { Task { await lists.toggleFavorite(guildId: guild.id ?? "") } }
                )
                .onTapGesture { selectedGuild = guild }
            }

            if nextCursor != nil {
                Button {
                    Task { await loadMore() }
                } label: {
                    HStack {
                        if isLoadingMore { ProgressView() }
                        Text(isLoadingMore ? "Loading..." : "Load More")
                    }
                    .frame(maxWidth: .infinity)
                }
                .disabled(isLoadingMore)
            }
        }
        .listStyle(.plain)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay { lfguildEmptyState }
    }

    @ViewBuilder
    private var lfguildEmptyState: some View {
        if searchResults.isEmpty && !isLoading {
            VStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 40))
                    .foregroundColor(.secondary)

                Text(hasSearched ? "No guilds found" : "Find Your Guild")
                    .font(.headline)
                    .fontWeight(.semibold)

                Text(hasSearched
                     ? "Try a different keyword, adjust filters, or sort by another option."
                     : "Search imported LFGuild guilds by name or tag. Need more options? Tap Filters.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
        }
    }

    // MARK: - Battle.net search

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
            Button(action: performBattleNetSearch) {
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
    private var battleNetResultsSection: some View {
        if isLoading && searchResults.isEmpty {
            LoadingSearchView(message: "Loading guilds from Battle.net...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            battleNetResultsList
        }
    }

    private var battleNetResultsList: some View {
        List(searchResults, id: \.self) { guild in
            BattleNetGuildRow(guild: guild)
                .onTapGesture { selectedGuild = guild }
        }
        .listStyle(.plain)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay { battleNetEmptyState }
    }

    @ViewBuilder
    private var battleNetEmptyState: some View {
        if searchResults.isEmpty && !isLoading {
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

    // MARK: - Actions

    private func runLfguildSearch(reset: Bool) async {
        if reset { nextCursor = nil }
        isSearchFieldFocused = false
        isLoading = true
        hasSearched = true
        errorMessage = nil

        let page = await guildManager.searchGuilds(
            query: searchQuery,
            filters: filters,
            pageSize: pageSize,
            cursor: reset ? nil : nextCursor
        )

        if reset {
            searchResults = page.guilds
        } else {
            searchResults.append(contentsOf: page.guilds)
        }
        nextCursor = page.nextCursor
        isLoading = false

        AnalyticsManager.shared.logSearchPerformed(query: searchQuery, resultCount: searchResults.count)
    }

    private func loadMore() async {
        guard nextCursor != nil, !isLoadingMore else { return }
        isLoadingMore = true
        let page = await guildManager.searchGuilds(
            query: searchQuery,
            filters: filters,
            pageSize: pageSize,
            cursor: nextCursor
        )
        searchResults.append(contentsOf: page.guilds)
        nextCursor = page.nextCursor
        isLoadingMore = false
    }

    private func performBattleNetSearch() {
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
                    AnalyticsManager.shared.logSearchPerformed(query: realm.rawValue, resultCount: results.count)
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

    private enum SearchMode {
        case lfguild, battleNet
    }
}

// MARK: - Rows

struct LFGuildGuildRow: View {
    let guild: GuildModel
    let isFavorite: Bool
    let onToggleFavorite: () -> Void

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

            Button(action: onToggleFavorite) {
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .foregroundStyle(isFavorite ? .pink : .secondary)
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isFavorite ? "Unsave \(guild.name)" : "Save \(guild.name)")

            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .font(.caption)
        }
        .padding(.vertical, 8)
    }

    private func factionColor(_ faction: String?) -> Color {
        switch faction?.lowercased() {
        case "alliance": return .blue
        case "horde": return .red
        default: return .gray
        }
    }
}

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
    var message = "Loading guilds from Battle.net..."

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    GuildSearchView()
        .environmentObject(AuthenticationManager())
        .environmentObject(NotificationRouter())
        .environmentObject(UserGuildListsManager.shared)
}