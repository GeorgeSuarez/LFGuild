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
    
    var body: some View {
        TabView {
            NavigationView {
                VStack(spacing: 20) {
                   
                    SwipeableCardsView()
                    
                    Button("Create Guild") {
                        // TODO: Navigate to guild creation
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .padding(.bottom, 20)
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
            
            NavigationView {
                VStack {
                    Text("Profile settings coming soon...")
                        .foregroundColor(.secondary)
                }
                .navigationTitle("Profile")
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
}
