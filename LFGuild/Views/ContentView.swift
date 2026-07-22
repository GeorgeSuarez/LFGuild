//
//  ContentView.swift
//  LFGuild
//
//  Created by George Suarez on 8/1/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var authManager = AuthenticationManager()
    @State private var showOnboarding = false
        
    var body: some View {
        Group {
            switch authManager.authState {
            case .idle:
                // Show loading screen while checking auth state
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
                
            case .loading:
                // Show loading during authentication
                ProgressView("Signing in...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
                
            case .authenticated(let user):
                // User is signed in, check if profile is complete
                if showOnboarding {
                    OnboardingView(user: user) {
                        showOnboarding = false
                    }
                    .environmentObject(authManager)
                } else {
                    HomeView(user: user)
                        .environmentObject(authManager)
                }
                
            case .unauthenticated:
                // User is not signed in, show login
                LoginView()
                    .environmentObject(authManager)
            }
        }
        .environmentObject(UserGuildListsManager.shared)
        .onChange(of: authManager.authState) { _, newState in
            if case .authenticated = newState {
                // Check if profile is complete when auth state changes
                showOnboarding = !authManager.isProfileComplete
            } else {
                showOnboarding = false
            }
        }
        .task(id: authManager.currentUser?.firebaseUID) {
            await UserGuildListsManager.shared.configure(for: authManager.currentUser?.firebaseUID)
            await GuildDiscoveryManager.shared.importPopularGuildsIfNeeded()
        }
    }
}

#Preview {
    ContentView()
}
