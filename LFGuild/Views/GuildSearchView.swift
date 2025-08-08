//
//  GuildSearchView.swift
//  LFGuild
//
//  Created by George Suarez on 8/8/25.
//

import SwiftUI

struct GuildSearchView: View {
    @EnvironmentObject private var authManager: AuthenticationManager
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
    
    private let availableDays = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
    private let availableTags = ["Raid Focused", "Mythic+ Focused", "Hardcore", "Casual", "PvP", "Social", "Competitive"]
    private let availableRealms = ["Stormrage - US", "Tichondrius - US", "Area-52 - US", "Mal'Ganis - US", "Dalaran - US", "Illidan - US", "Thrall - US"]
    private let availableRoles = ["Tank", "Healer", "DPS"]
    
    // Sample guild data
    private let sampleGuilds = [
        CardItem(imageURL: "https://via.placeholder.com/400x300/FF6B6B/FFFFFF?text=Guild+1",
                 title: "Adventure Seekers",
                 description: "Join us for epic quests and dungeon crawling adventures in the realm of fantasy gaming.",
                 memberCount: 42,
                 tags: ["Raid Focused", "Hardcore"],
                 requirements: "Level 10+ characters preferred",
                 leader: "DragonSlayer99",
                 raidDays: ["Tuesday", "Thursday", "Sunday"],
                 raidTime: "8:00 PM - 11:00 PM EST",
                 serverRealm: "Stormrage - US"),
        
        CardItem(imageURL: "https://via.placeholder.com/400x300/4ECDC4/FFFFFF?text=Guild+2",
                 title: "Strategy Masters",
                 description: "Tactical gameplay and strategic thinking. Perfect for players who love chess-like challenges.",
                 memberCount: 28,
                 tags: ["Mythic+ Focused", "Competitive"],
                 requirements: "Must pass strategy test",
                 leader: "TacticalGenius",
                 raidDays: ["Monday", "Wednesday", "Friday"],
                 raidTime: "7:30 PM - 10:30 PM PST",
                 serverRealm: "Tichondrius - US"),
        
        CardItem(imageURL: "https://via.placeholder.com/400x300/45B7D1/FFFFFF?text=Guild+3",
                 title: "Casual Gamers",
                 description: "Relaxed gaming environment for those who want to have fun without the pressure.",
                 memberCount: 67,
                 tags: ["Casual", "Social"],
                 requirements: "Just be friendly!",
                 leader: "ChillPlayer",
                 raidDays: ["Saturday"],
                 raidTime: "2:00 PM - 5:00 PM CST",
                 serverRealm: "Area-52 - US"),
        
        CardItem(imageURL: "https://via.placeholder.com/400x300/96CEB4/FFFFFF?text=Guild+4",
                 title: "Competitive Arena",
                 description: "High-stakes competitive gaming for serious players looking to climb the ranks.",
                 memberCount: 35,
                 tags: ["Competitive", "PvP", "Hardcore"],
                 requirements: "Rank Gold or higher",
                 leader: "ChampionMaster",
                 raidDays: ["Tuesday", "Wednesday", "Thursday"],
                 raidTime: "9:00 PM - 12:00 AM EST",
                 serverRealm: "Mal'Ganis - US"),
        
        CardItem(imageURL: "https://via.placeholder.com/400x300/FFEAA7/333333?text=Guild+5",
                 title: "Social Hub",
                 description: "Community-focused guild where friendships are formed and memories are made.",
                 memberCount: 89,
                 tags: ["Social", "Casual"],
                 requirements: "Active participation required",
                 leader: "SocialButterfly",
                 raidDays: ["Friday", "Saturday"],
                 raidTime: "6:00 PM - 9:00 PM MST",
                 serverRealm: "Dalaran - US"),
        
        CardItem(imageURL: "https://via.placeholder.com/400x300/A29BFE/FFFFFF?text=Guild+6",
                 title: "Mythic Raiders",
                 description: "Elite raiding guild focused on clearing the hardest content in the game.",
                 memberCount: 25,
                 tags: ["Raid Focused", "Hardcore", "Mythic+ Focused"],
                 requirements: "ilvl 480+ required",
                 leader: "MythicMaster",
                 raidDays: ["Tuesday", "Wednesday", "Thursday", "Sunday"],
                 raidTime: "8:30 PM - 11:30 PM EST",
                 serverRealm: "Illidan - US")
    ]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search Bar
                SearchBar(text: $searchText, onSearchButtonClicked: performSearch)
                    .padding(.horizontal)
                
                // Filter Toggle Button
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
                
                // Expandable Filters
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
                
                // Results
                List(searchResults, id: \.id) { guild in
                    GuildSearchResultRow(guild: guild)
                        .onTapGesture {
                            selectedGuild = guild
                        }
                }
                .listStyle(.plain)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay {
                    if searchResults.isEmpty {
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
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Search Guilds")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                performInitialSearch()
            }
            .onChange(of: selectedRaidDays) { _ in performSearch() }
            .onChange(of: selectedTags) { _ in performSearch() }
            .onChange(of: selectedRealms) { _ in performSearch() }
            .onChange(of: selectedRoles) { _ in performSearch() }
            .onChange(of: startTimeFilter) { _ in performSearch() }
            .onChange(of: endTimeFilter) { _ in performSearch() }
        }
        .sheet(item: $selectedGuild) { guild in
            CardDetailView(card: guild, isPresented: .init(
                get: { selectedGuild != nil },
                set: { if !$0 { selectedGuild = nil } }
            ))
        }
    }
    
    private func performInitialSearch() {
        searchResults = sampleGuilds
    }
    
    private func performSearch() {
        var filteredGuilds = sampleGuilds
        
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
        
        // Role availability filter (placeholder - would need actual role availability data)
        if !selectedRoles.isEmpty {
            // For now, assume all guilds need all roles
            filteredGuilds = filteredGuilds.filter { _ in true }
        }
        
        searchResults = filteredGuilds
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
            AsyncImage(url: URL(string: guild.imageURL)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
            }
            .frame(width: 60, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
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