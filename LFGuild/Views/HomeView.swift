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
                    VStack(spacing: 16) {
                        AsyncImage(url: URL(string: "https://via.placeholder.com/100")) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                                .overlay {
                                    Text(String(user.name.prefix(1)))
                                        .font(.largeTitle)
                                        .fontWeight(.bold)
                                        .foregroundColor(.blue)
                                }
                            
                        }
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())
                        
                        Text("Welcome, \(user.name)!")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        VStack(spacing: 8) {
                            Text(user.email)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Text(user.countryRegion)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    
                    Spacer()
                    
                    VStack(spacing: 12) {
                        Button("Find Guild") {
                            // TODO: Navigate guilds
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        
                        Button("Create Guild") {
                            // TODO: Navigate to guild creation
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    }
                    
                    Spacer()
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
}
