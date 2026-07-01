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
    @State private var selectedTab: HomeTab = .home

    private let db = Firestore.firestore()

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Home", systemImage: "house", value: HomeTab.home) {
                NavigationStack {
                    MatchingGuildsCarousel {
                        await refreshUserPreferences()
                    }
                }
            }

            Tab("Messages", systemImage: "message", value: HomeTab.messages) {
                NavigationStack {
                    ConversationsView()
                        .environmentObject(authManager)
                }
            }

            Tab("Search", systemImage: "magnifyingglass", value: HomeTab.search) {
                NavigationStack {
                    GuildSearchView()
                        .environmentObject(authManager)
                }
            }

            Tab("Profile", systemImage: "person", value: HomeTab.profile) {
                NavigationStack {
                    ProfileView()
                        .environmentObject(authManager)
                }
            }
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

        do {
            let document = try await db.collection("publicProfiles").document(firebaseUID).getDocument()

            if let data = document.data() {
                await MainActor.run {
                    if let rolesArray = data["roles"] as? [String] {
                        currentUser.roles = Set(rolesArray)
                    }

                    if let specializationsArray = data["specializations"] as? [String] {
                        currentUser.specializations = Set(specializationsArray)
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
                }
            }
        } catch {
            // Non-fatal; cached preferences remain in place.
        }
    }
}

#Preview {
    let testUser = UserModel(name: "Test User", email: "test@example.com", countryRegion: "United States")
    
    return HomeView(user: testUser)
        .environmentObject(AuthenticationManager())
        .environmentObject(NotificationRouter())
        .onAppear {
            testUser.roles = ["DPS", "Healer"]
            testUser.availableDays = ["Monday", "Tuesday", "Friday"]
            testUser.gamingTags = ["Hardcore", "Mythic+ Focused"]
            testUser.preferredRealms = ["Stormrage - US", "Area-52 - US"]
        }
}
