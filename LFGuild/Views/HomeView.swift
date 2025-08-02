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
        NavigationView {
            VStack(spacing: 20) {
                Text("Welcome to LFGuild!")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Hello, \(user.name)")
                    .font(.headline)
                
                Text("Email: \(user.email)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("Region: \(user.countryRegion)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: {
                    authManager.signOut()
                }) {
                    Text("Sign Out")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .cornerRadius(10)
                }
                .padding()
            }
            .padding()
            .navigationTitle("Dashboard")
        }
    }
}

#Preview {
}
