//
//  GuildBrowserView.swift
//  LFGuild
//
//  Created by George Suarez on 8/6/25.
//

import SwiftUI
import FirebaseFirestore

// MARK: - Guild Model for Firestore
struct Guild: Codable, Identifiable {
    @DocumentID var id: String?
    let battleNetId: Int
    let name: String
    let realmName: String
    let realmSlug: String
    let faction: String
    let region: String
    let memberCount: Int
    let achievementPoints: Int
    let description: String?
    let recruitmentStatus: RecruitmentStatus
    let lookingFor: [String] // Tank, Healer, DPS, etc.
    let raidSchedule: [RaidSchedule]?
    let contactInfo: String?
    let createdAt: Date
    let updatedAt: Date
    
    struct RecruitmentStatus: Codable {
        let isRecruiting: Bool
        let minimumLevel: Int
        let requiredItemLevel: Int?
        let recruitmentMessage: String?
    }
    
    struct RaidSchedule: Codable {
        let day: String
        let startTime: String
        let endTime: String
        let timezone: String
    }
}

// MARK: - Guild Browser View
struct GuildBrowserView: View {
    @StateObject private var battleNetManager = BattleNetAPIManager.shared
    @State private var searchText = ""
    @State private var selectedRealm = "All Realms"
    @State private var selectedFaction: String? = nil
    @State private var showOnlyRecruiting = false
    @State private var guilds: [Guild] = []
    @State private var isLoading = false
    @State private var showingGuildDetail: Guild?
    
    private let db = Firestore.firestore()
    
    let realms = [
        "All Realms",
        "Area 52", "Stormrage", "Illidan", "Tichondrius",
        "Mal'Ganis", "Zul'jin", "Dalaran", "Sargeras"
        // Add more realms as needed
    ]
    
    var filteredGuilds: [Guild] {
        guilds.filter { guild in
            let matchesSearch = searchText.isEmpty ||
            guild.name.localizedCaseInsensitiveContains(searchText)
            let matchesRealm = selectedRealm == "All Realms" ||
            guild.realmName == selectedRealm
            let matchesFaction = selectedFaction == nil ||
            guild.faction == selectedFaction
            let matchesRecruiting = !showOnlyRecruiting ||
            guild.recruitmentStatus.isRecruiting
            
            return matchesSearch && matchesRealm && matchesFaction && matchesRecruiting
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search and Filter Bar
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Search guilds...", text: $searchText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    .padding(.horizontal)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            // Realm Picker
                            Menu {
                                ForEach(realms, id: \.self) { realm in
                                    Button(realm) {
                                        selectedRealm = realm
                                    }
                                }
                            } label: {
                                Label(selectedRealm, systemImage: "server.rack")
                                    .font(.caption)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color(.systemGray5))
                                    .cornerRadius(15)
                            }
                            
                            // Faction Filter
                            ForEach(["Alliance", "Horde"], id: \.self) { faction in
                                Button(action: {
                                    if selectedFaction == faction {
                                        selectedFaction = nil
                                    } else {
                                        selectedFaction = faction
                                    }
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: faction == "Alliance" ? "shield.fill" : "flame.fill")
                                            .font(.caption)
                                        Text(faction)
                                            .font(.caption)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(selectedFaction == faction ?
                                                (faction == "Alliance" ? Color.blue : Color.red).opacity(0.2) :
                                                    Color(.systemGray5))
                                    .foregroundColor(selectedFaction == faction ?
                                                     (faction == "Alliance" ? .blue : .red) :
                                            .primary)
                                    .cornerRadius(15)
                                }
                            }
                            
                            // Recruiting Toggle
                            Button(action: {
                                showOnlyRecruiting.toggle()
                            }) {
                                Label("Recruiting", systemImage: showOnlyRecruiting ? "checkmark.circle.fill" : "circle")
                                    .font(.caption)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(showOnlyRecruiting ? Color.green.opacity(0.2) : Color(.systemGray5))
                                    .foregroundColor(showOnlyRecruiting ? .green : .primary)
                                    .cornerRadius(15)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical, 8)
                .background(Color(.systemBackground))
                
                Divider()
                
                // Guild List
                if isLoading {
                    Spacer()
                    ProgressView("Loading guilds...")
                    Spacer()
                } else if filteredGuilds.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "flag.slash")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        Text("No guilds found")
                            .font(.headline)
                        Text("Try adjusting your filters or search terms")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                } else {
                    List(filteredGuilds) { guild in
                        GuildRowView(guild: guild)
                            .onTapGesture {
                                showingGuildDetail = guild
                            }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("Guild Browser")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if battleNetManager.isAuthenticated {
                        Button("My Guilds") {
                            // Show user's guilds from their characters
                        }
                    }
                }
            }
        }
        .onAppear {
            loadGuilds()
        }
        .sheet(item: $showingGuildDetail) { guild in
            GuildDetailView(guild: guild)
        }
    }
    
    private func loadGuilds() {
        isLoading = true
        
        Task {
            do {
                let snapshot = try await db.collection("guilds")
                    .order(by: "memberCount", descending: true)
                    .limit(to: 50)
                    .getDocuments()
                
                guilds = snapshot.documents.compactMap { document in
                    try? document.data(as: Guild.self)
                }
                
                isLoading = false
            } catch {
                print("Error loading guilds: \(error)")
                isLoading = false
            }
        }
    }
}

// MARK: - Guild Row View
struct GuildRowView: View {
    let guild: Guild
    
    var body: some View {
        HStack {
            // Faction Icon
            Image(systemName: guild.faction == "Alliance" ? "shield.fill" : "flame.fill")
                .font(.title2)
                .foregroundColor(guild.faction == "Alliance" ? .blue : .red)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(guild.name)
                        .font(.headline)
                    
                    if guild.recruitmentStatus.isRecruiting {
                        Text("RECRUITING")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(4)
                    }
                }
                
                HStack {
                    Label(guild.realmName, systemImage: "server.rack")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .foregroundColor(.secondary)
                    
                    Label("\(guild.memberCount) members", systemImage: "person.2")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let description = guild.description {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .padding(.top, 2)
                }
                
                if !guild.lookingFor.isEmpty {
                    HStack(spacing: 4) {
                        Text("Looking for:")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        ForEach(guild.lookingFor, id: \.self) { role in
                            Text(role)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(roleColor(for: role).opacity(0.2))
                                .foregroundColor(roleColor(for: role))
                                .cornerRadius(4)
                        }
                    }
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 2) {
                    Image(systemName: "trophy.fill")
                        .font(.caption)
                    Text("\(guild.achievementPoints)")
                        .font(.caption)
                }
                .foregroundColor(.orange)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func roleColor(for role: String) -> Color {
        switch role.lowercased() {
        case "tank": return .blue
        case "healer": return .green
        case "dps": return .red
        default: return .gray
        }
    }
}

// MARK: - Guild Detail View
struct GuildDetailView: View {
    let guild: Guild
    @Environment(\.dismiss) var dismiss
    @StateObject private var battleNetManager = BattleNetAPIManager.shared
    @State private var guildData: WoWGuild?
    @State private var rosterData: [WoWGuildMember] = []
    @State private var isLoadingDetails = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    HStack {
                        Image(systemName: guild.faction == "Alliance" ? "shield.fill" : "flame.fill")
                            .font(.largeTitle)
                            .foregroundColor(guild.faction == "Alliance" ? .blue : .red)
                        
                        VStack(alignment: .leading) {
                            Text(guild.name)
                                .font(.largeTitle)
                                .fontWeight(.bold)
                            
                            Text("\(guild.realmName) - \(guild.region)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if guild.recruitmentStatus.isRecruiting {
                            VStack {
                                Text("RECRUITING")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.green)
                                    .foregroundColor(.white)
                                    .cornerRadius(6)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // Stats
                    HStack(spacing: 20) {
                        StatCard(title: "Members", value: "\(guild.memberCount)", icon: "person.2.fill")
                        StatCard(title: "Achievement Points", value: "\(guild.achievementPoints)", icon: "trophy.fill")
                        if let itemLevel = guild.recruitmentStatus.requiredItemLevel {
                            StatCard(title: "Min iLvl", value: "\(itemLevel)", icon: "shield.checkerboard")
                        }
                    }
                    
                    // Description
                    if let description = guild.description {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("About")
                                .font(.headline)
                            Text(description)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    
                    // Recruitment Info
                    if guild.recruitmentStatus.isRecruiting {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Recruitment")
                                .font(.headline)
                            
                            if let message = guild.recruitmentStatus.recruitmentMessage {
                                Text(message)
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack {
                                Text("Looking for:")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                ForEach(guild.lookingFor, id: \.self) { role in
                                    Text(role)
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(roleColor(for: role).opacity(0.2))
                                        .foregroundColor(roleColor(for: role))
                                        .cornerRadius(6)
                                }
                            }
                            
                            HStack {
                                Text("Minimum Level:")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text("\(guild.recruitmentStatus.minimumLevel)")
                                    .fontWeight(.semibold)
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    
                    // Raid Schedule
                    if let schedule = guild.raidSchedule, !schedule.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Raid Schedule")
                                .font(.headline)
                            
                            ForEach(schedule, id: \.day) { raid in
                                HStack {
                                    Image(systemName: "calendar")
                                        .foregroundColor(.purple)
                                    Text(raid.day)
                                        .fontWeight(.medium)
                                    Spacer()
                                    Text("\(raid.startTime) - \(raid.endTime) \(raid.timezone)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    
                    // Contact Info
                    if let contact = guild.contactInfo {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Contact")
                                .font(.headline)
                            Text(contact)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    
                    // Apply Button
                    Button(action: applyToGuild) {
                        Text("Apply to Guild")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            if battleNetManager.isAuthenticated {
                loadGuildDetails()
            }
        }
    }
    
    private func loadGuildDetails() {
        isLoadingDetails = true
        
        Task {
            do {
                guildData = try await battleNetManager.fetchGuild(
                    realmSlug: guild.realmSlug,
                    guildName: guild.name
                )
                
                rosterData = try await battleNetManager.fetchGuildRoster(
                    realmSlug: guild.realmSlug,
                    guildName: guild.name
                )
                
                isLoadingDetails = false
            } catch {
                print("Error loading guild details: \(error)")
                isLoadingDetails = false
            }
        }
    }
    
    private func applyToGuild() {
        // Implement guild application logic
        // This would typically create an application document in Firestore
        // and notify the guild officers
    }
    
    private func roleColor(for role: String) -> Color {
        switch role.lowercased() {
        case "tank": return .blue
        case "healer": return .green
        case "dps": return .red
        default: return .gray
        }
    }
}

// MARK: - Stat Card Component
struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
            
            Text(value)
                .font(.headline)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

#Preview {
    GuildBrowserView()
}
