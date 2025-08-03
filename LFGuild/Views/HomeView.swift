//
//  HomeView.swift
//  LFGuild
//
//  Created by George Suarez on 7/28/25.
//

import SwiftUI

struct HomeView: View {
    let user: UserModel
    @EnvironmentObject private var authManager: AuthenticationManager
    @State private var showingProfile = false
    
    var body: some View {
        TabView {
            NavigationView {
                VStack(alignment: .leading, spacing: 20) {
                    SwipeableCardsView()
                }
                .padding()
                .navigationTitle("Dashboard")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Sign Out") {
                            authManager.signOut()
                        }
                        .foregroundColor(.red)
                    }
                }
            }
            .tabItem {
                Image(systemName: "house")
                Text("Home")
            }
                
            NavigationStack {
                ConversationsView()
                    .environmentObject(authManager)
            }
            .tabItem {
                Image(systemName: "message")
                Text("Messages")
            }
            
            NavigationStack {
                ProfileView()
                    .environmentObject(authManager)
            }
            .tabItem {
                Image(systemName: "person")
                Text("Profile")
            }
        }
    }
}
#Preview {
    let testUser = UserModel(name: "Test User", email: "test@example.com", countryRegion: "United States")
    HomeView(user: testUser)
        .environmentObject(AuthenticationManager())
}
