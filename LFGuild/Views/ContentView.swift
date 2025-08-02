//
//  ContentView.swift
//  LFGuild
//
//  Created by George Suarez on 8/1/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var authManager = AuthenticationManager()
        
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
                    // User is signed in, show main app
                    HomeView(user: user)
                        .environmentObject(authManager)
                    
                case .unauthenticated:
                    // User is not signed in, show login
                    LoginView()
                        .environmentObject(authManager)
                }
            }
        }
}

#Preview {
    ContentView()
}
