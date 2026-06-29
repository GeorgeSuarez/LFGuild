//
//  GuildSearchView.swift
//  LFGuild
//
//  Created by George Suarez on 8/8/25.
//

import SwiftUI

struct GuildSearchView: View {
    @EnvironmentObject private var authManager: AuthenticationManager
    @EnvironmentObject private var notificationRouter: NotificationRouter
    @StateObject private var guildManager = GuildManager()
    @State private var searchText = ""
    @State private var selectedRaidDays: Set<String> = []
    @State private var selectedTags: Set<String> = []
    @State private var selectedRealms: Set<String> = []
    @State private var selectedRoles: Set<String> = []
    @State private var startTimeFilter: Date?
    @State private var endTimeFilter: Date?
    @State private var isFilterExpanded = false
    @State private var searchResults: [CardItem] = []
    @State private var selectedGuild: CardItem?
    @State private var isLoading = false
    @State private var hasLoaded = false

    private let availableDays = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
    private let availableTags = ["Raid Focused", "Mythic+ Focused", "Hardcore", "Casual", "PvP", "Social", "Competitive"]
    private let availableRealms = ["Stormrage - US", "Tichondrius - US", "Area-52 - US", "Mal'Ganis - US", "Dalaran - US", "Illidan - US", "Thrall - US"]
    private let availableRoles = ["Tank", "Healer", "DPS"]
    
    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Search Guilds")
                .navigationBarTitleDisplayMode(.large)
                .onAppear {
                    if !hasLoaded {
                        loadGuilds()
                    }

                    Task {
                        await presentRoutedGuildIfAvailable()
                    }
                }
                .onChange(of: searchText) { performSearch() }
                .onChange(of: selectedRaidDays) { performSearch() }
                .onChange(of: selectedTags) { performSearch() }
                .onChange(of: selectedRealms) { performSearch() }
                .onChange(of: selectedRoles) { performSearch() }
                .onChange(of: startTimeFilter) { performSearch() }
                .onChange(of: endTimeFilter) { performSearch() }
        }
        .sheet(item: $selectedGuild) { guild in
            CardDetailView(card: guild, isPresented: .init(
                get: { selectedGuild != nil },
                set: { if !$0 { selectedGuild = nil } }
            ))
        }
    }

    private var content: some View {
        VStack(spacing: 0) {
            searchBarSection
            filterToggleSection
            filterSection
            resultsSection
        }
    }

    private var searchBarSection: some View {
        SearchBar(text: $searchText, onSearchButtonClicked: performSearch)
            .padding(.horizontal)
    }

    private var filterToggleSection: some View {
        Button(action: {
            withAnimation(.spring()) {
                isFilterExpanded.toggle()
            }
        }) {
            HStack {
                Image(systemName: "slider.horizontal.3")
                Text("Filters")
                Spacer()
                Image(systemName: isFilterExpanded ? "chevron.up" : "chevron.down")
            }
            .padding()
            .background(.ultraThinMaterial)
            .foregroundColor(.primary)
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    @ViewBuilder
    private var filterSection: some View {
        if isFilterExpanded {
            ScrollView {
                FilterSectionView(
                    selectedRaidDays: $selectedRaidDays,
                    selectedTags: $selectedTags,
                    selectedRealms: $selectedRealms,
                    selectedRoles: $selectedRoles,
                    startTimeFilter: $startTimeFilter,
                    endTimeFilter: $endTimeFilter,
                    availableDays: availableDays,
                    availableTags: availableTags,
                    availableRealms: availableRealms,
                    availableRoles: availableRoles
                )
            }
            .frame(maxHeight: 300)
            .background(.ultraThinMaterial)
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    @ViewBuilder
    private var resultsSection: some View {
        if isLoading && searchResults.isEmpty {
            LoadingSearchView()
        } else {
            resultsList
        }
    }

    private var resultsList: some View {
        List(searchResults, id: \.id) { guild in
            GuildSearchResultRow(guild: guild)
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
        if searchResults.isEmpty && !isLoading {
            VStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 40))
                    .foregroundColor(.secondary)

                Text("No guilds found")
                    .font(.headline)
                    .fontWeight(.semibold)

                Text("Try adjusting your search criteria or filters")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                Button("Refresh") {
                    loadGuilds()
                }
                .buttonStyle(.bordered)
                .padding(.top)
            }
            .padding()
        }
    }
    
    private func loadGuilds() {
        isLoading = true
        hasLoaded = true
        
        Task {
            await guildManager.fetchAllGuilds()
            
            await MainActor.run {
                performSearch()
                isLoading = false
            }
        }
    }
    
    private func performSearch() {
        var filteredGuilds = guildManager.guilds.map { CardItem(from: $0) }

        // Text search
        if !searchText.isEmpty {
            filteredGuilds = filteredGuilds.filter { guild in
                guild.title.localizedCaseInsensitiveContains(searchText) ||
                guild.description.localizedCaseInsensitiveContains(searchText) ||
                guild.leader.localizedCaseInsensitiveContains(searchText)
            }
        }

        // Raid days filter
        if !selectedRaidDays.isEmpty {
            filteredGuilds = filteredGuilds.filter { guild in
                !Set(guild.raidDays).isDisjoint(with: selectedRaidDays)
            }
        }

        // Tags filter
        if !selectedTags.isEmpty {
            filteredGuilds = filteredGuilds.filter { guild in
                !Set(guild.tags).isDisjoint(with: selectedTags)
            }
        }

        // Realms filter
        if !selectedRealms.isEmpty {
            filteredGuilds = filteredGuilds.filter { guild in
                selectedRealms.contains(guild.serverRealm)
            }
        }

        // Role availability filter (now uses guild.neededRoles if available)
        if !selectedRoles.isEmpty {
            filteredGuilds = filteredGuilds.filter { _ in true }
        }

        searchResults = filteredGuilds
    }

    private func presentRoutedGuildIfAvailable() async {
        guard let guildId = notificationRouter.consumeGuildId() else { return }

        if let guild = await guildManager.fetchGuild(byId: guildId) {
            await MainActor.run {
                selectedGuild = CardItem(from: guild)
            }
        }
    }
}

struct SearchBar: View {
    @Binding var text: String
    var onSearchButtonClicked: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search guilds...", text: $text)
                .textFieldStyle(.plain)
                .onSubmit {
                    onSearchButtonClicked()
                }
            
            if !text.isEmpty {
                Button("Clear") {
                    text = ""
                    onSearchButtonClicked()
                }
                .foregroundColor(.secondary)
                .font(.caption)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .cornerRadius(10)
    }
}

struct LoadingSearchView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading guilds...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct FilterSectionView: View {
    @Binding var selectedRaidDays: Set<String>
    @Binding var selectedTags: Set<String>
    @Binding var selectedRealms: Set<String>
    @Binding var selectedRoles: Set<String>
    @Binding var startTimeFilter: Date?
    @Binding var endTimeFilter: Date?
    
    let availableDays: [String]
    let availableTags: [String]
    let availableRealms: [String]
    let availableRoles: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Raid Days Filter
            FilterRow(title: "Raid Days", icon: "calendar") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                    ForEach(availableDays, id: \.self) { day in
                        FilterChip(
                            text: day,
                            isSelected: selectedRaidDays.contains(day),
                            color: .green
                        ) {
                            if selectedRaidDays.contains(day) {
                                selectedRaidDays.remove(day)
                            } else {
                                selectedRaidDays.insert(day)
                            }
                        }
                    }
                }
            }
            
            // Tags Filter
            FilterRow(title: "Guild Focus", icon: "tag") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                    ForEach(availableTags, id: \.self) { tag in
                        FilterChip(
                            text: tag,
                            isSelected: selectedTags.contains(tag),
                            color: .blue
                        ) {
                            if selectedTags.contains(tag) {
                                selectedTags.remove(tag)
                            } else {
                                selectedTags.insert(tag)
                            }
                        }
                    }
                }
            }
            
            // Realms Filter
            FilterRow(title: "Server/Realm", icon: "globe") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                    ForEach(availableRealms, id: \.self) { realm in
                        FilterChip(
                            text: realm,
                            isSelected: selectedRealms.contains(realm),
                            color: .purple
                        ) {
                            if selectedRealms.contains(realm) {
                                selectedRealms.remove(realm)
                            } else {
                                selectedRealms.insert(realm)
                            }
                        }
                    }
                }
            }
            
            // Roles Filter
            FilterRow(title: "Role Availability", icon: "gamecontroller") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                    ForEach(availableRoles, id: \.self) { role in
                        FilterChip(
                            text: role,
                            isSelected: selectedRoles.contains(role),
                            color: .orange
                        ) {
                            if selectedRoles.contains(role) {
                                selectedRoles.remove(role)
                            } else {
                                selectedRoles.insert(role)
                            }
                        }
                    }
                }
            }
            
            // Clear All Button
            Button("Clear All Filters") {
                selectedRaidDays.removeAll()
                selectedTags.removeAll()
                selectedRealms.removeAll()
                selectedRoles.removeAll()
                startTimeFilter = nil
                endTimeFilter = nil
            }
            .foregroundColor(.red)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top)
        }
        .padding()
    }
}

struct FilterRow<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.secondary)
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            content
        }
    }
}

struct FilterChip: View {
    let text: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    isSelected ? color : Color.gray.opacity(0.2)
                )
                .foregroundColor(
                    isSelected ? .white : .primary
                )
                .cornerRadius(16)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct GuildSearchResultRow: View {
    let guild: CardItem

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 60, height: 60)
                .overlay {
                    Image(systemName: "person.3")
                        .foregroundColor(.gray)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(guild.title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(guild.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                HStack {
                    Image(systemName: "person.3")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    
                    Text("\(guild.memberCount) members")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(guild.serverRealm)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(guild.tags.prefix(3), id: \.self) { tag in
                            Text(tag)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(8)
                        }
                        
                        if guild.tags.count > 3 {
                            Text("+\(guild.tags.count - 3)")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.1))
                                .foregroundColor(.secondary)
                                .cornerRadius(8)
                        }
                    }
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .font(.caption)
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    GuildSearchView()
        .environmentObject(AuthenticationManager())
}
