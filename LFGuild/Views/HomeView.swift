//
//  HomeView.swift
//  LFGuild
//
//  Created by George Suarez on 7/28/25.
//

import SwiftUI
import FirebaseFirestore

struct HomeView: View {
    @ObservedObject var user: UserModel
    @EnvironmentObject private var authManager: AuthenticationManager
    @EnvironmentObject private var notificationRouter: NotificationRouter
    @State private var showingProfile = false
    @State private var isRefreshing = false
    @State private var selectedTab: HomeTab = .home

    private let db = Firestore.firestore()

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationView {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        WelcomeHeaderView(user: user)

                        UserPreferencesCard(user: user)

                        HStack {
                            Spacer()
                            SwipeableCardsView()
                            Spacer()
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
                .refreshable {
                    await refreshUserPreferences()
                }
                .navigationTitle("Your Dashboard")
                .navigationBarTitleDisplayMode(.large)
            }
            .tabItem {
                Image(systemName: "house")
                Text("Home")
            }
            .tag(HomeTab.home)

            NavigationStack {
                ConversationsView()
                    .environmentObject(authManager)
            }
            .tabItem {
                Image(systemName: "message")
                Text("Messages")
            }
            .tag(HomeTab.messages)

            NavigationStack {
                GuildSearchView()
                    .environmentObject(authManager)
            }
            .tabItem {
                Image(systemName: "magnifyingglass")
                Text("Search")
            }
            .tag(HomeTab.search)

            NavigationStack {
                ProfileView()
                    .environmentObject(authManager)
            }
            .tabItem {
                Image(systemName: "person")
                Text("Profile")
            }
            .tag(HomeTab.profile)
        }
        .onChange(of: notificationRouter.requestedTab) { _, newTab in
            if let newTab = newTab {
                selectedTab = newTab
            }
        }
    }
    
    private func refreshUserPreferences() async {
        guard let currentUser = authManager.currentUser,
              let firebaseUID = currentUser.firebaseUID else { return }

        isRefreshing = true

        do {
            let document = try await db.collection("publicProfiles").document(firebaseUID).getDocument()

            if let data = document.data() {
                await MainActor.run {
                    if let rolesArray = data["roles"] as? [String] {
                        currentUser.roles = Set(rolesArray)
                    }

                    if let daysArray = data["availableDays"] as? [String] {
                        currentUser.availableDays = Set(daysArray)
                    }

                    if let tagsArray = data["gamingTags"] as? [String] {
                        currentUser.gamingTags = Set(tagsArray)
                    }

                    if let realmsArray = data["preferredRealms"] as? [String] {
                        currentUser.preferredRealms = Set(realmsArray)
                    }

                    if let startTimeTimestamp = data["availableStartTime"] as? Timestamp {
                        currentUser.availableStartTime = startTimeTimestamp.dateValue()
                    }

                    if let endTimeTimestamp = data["availableEndTime"] as? Timestamp {
                        currentUser.availableEndTime = endTimeTimestamp.dateValue()
                    }

                    isRefreshing = false
                }
            } else {
                await MainActor.run {
                    isRefreshing = false
                }
            }

        } catch {
            await MainActor.run {
                isRefreshing = false
            }
        }
    }
}

struct WelcomeHeaderView: View {
    @ObservedObject var user: UserModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Welcome back,")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(user.name)
                        .font(.title2)
                        .fontWeight(.bold)
                }
                
                Spacer()
                
                Circle()
                    .fill(Color.blue.gradient)
                    .frame(width: 50, height: 50)
                    .overlay {
                        Text(String(user.name.prefix(1)).uppercased())
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    }
            }
        }
    }
}

struct UserPreferencesCard: View {
    @ObservedObject var user: UserModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "person.crop.circle.badge.checkmark")
                    .foregroundColor(.blue)
                    .font(.title3)
                
                Text("Your Profile")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            VStack(spacing: 12) {
                if !user.roles.isEmpty {
                    PreferenceRowView(
                        icon: "gamecontroller.fill",
                        title: "Roles",
                        items: Array(user.roles),
                        color: .purple
                    )
                }
                
                if !user.availableDays.isEmpty {
                    PreferenceRowView(
                        icon: "calendar",
                        title: "Available Days",
                        items: Array(user.availableDays),
                        color: .green
                    )
                }
                
                if let startTime = user.availableStartTime,
                   let endTime = user.availableEndTime {
                    HStack {
                        Image(systemName: "clock.fill")
                            .foregroundColor(.orange)
                            .frame(width: 20)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Raid Times")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Text("\(startTime, formatter: timeFormatter) - \(endTime, formatter: timeFormatter)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                }
                
                if !user.gamingTags.isEmpty {
                    PreferenceRowView(
                        icon: "tag.fill",
                        title: "Gaming Style",
                        items: Array(user.gamingTags),
                        color: .blue
                    )
                }
                
                if !user.preferredRealms.isEmpty {
                    PreferenceRowView(
                        icon: "globe",
                        title: "Preferred Realms",
                        items: Array(user.preferredRealms),
                        color: .indigo
                    )
                }
            }
            
            if user.roles.isEmpty && user.availableDays.isEmpty && user.gamingTags.isEmpty && user.preferredRealms.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "person.badge.plus")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    
                    Text("Complete Your Profile")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("Set your preferences in the Profile tab to get better guild matches")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .stroke(Color(.systemGray5), lineWidth: 1)
        }
    }
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }
}

struct PreferenceRowView: View {
    let icon: String
    let title: String
    let items: [String]
    let color: Color
    
    var body: some View {
        HStack(alignment: .top) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                FlowLayout(spacing: 6) {
                    ForEach(items.prefix(3), id: \.self) { item in
                        Text(item)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background {
                                Capsule()
                                    .fill(color.opacity(0.1))
                                    .stroke(color.opacity(0.3), lineWidth: 0.5)
                            }
                            .foregroundColor(color)
                    }
                    
                    if items.count > 3 {
                        Text("+\(items.count - 3)")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background {
                                Capsule()
                                    .fill(Color.secondary.opacity(0.1))
                            }
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
        }
    }
}

#Preview {
    let testUser = UserModel(name: "Test User", email: "test@example.com", countryRegion: "United States")
    
    return HomeView(user: testUser)
        .environmentObject(AuthenticationManager())
        .onAppear {
            testUser.roles = ["DPS", "Healer"]
            testUser.availableDays = ["Monday", "Tuesday", "Friday"]
            testUser.gamingTags = ["Hardcore", "Mythic+ Focused"]
            testUser.preferredRealms = ["Stormrage - US", "Area-52 - US"]
        }
}
