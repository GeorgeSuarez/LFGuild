//
//  ProfileView.swift
//  LFGuild
//
//  Created by George Suarez on 8/2/25.
//

import SwiftUI
import FirebaseAuth
import AuthenticationServices

struct ProfileView: View {
    @StateObject private var viewModel = ProfileViewModel()
    @StateObject private var battleNetManager = BattleNetAPIManager.shared
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var showingEditProfile = false
    @State private var showingBattleNetConnect = false
    @State private var showingCharacterList = false
    
    var isSheet: Bool = false
    
    var body: some View {
        List {
            Section("Profile Information") {
                ProfileInfoRow(title: "Name", value: viewModel.name)
                ProfileInfoRow(title: "Email", value: viewModel.email)
                ProfileInfoRow(title: "Country/Region", value: viewModel.countryRegion)
            }
            
            // Battle.net Integration Section
            Section("Battle.net Account") {
                HStack {
                    Image(systemName: "gamecontroller.fill")
                        .foregroundColor(.blue)
                        .frame(width: 30)
                    
                    if battleNetManager.isAuthenticated {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Battle.net Connected")
                                .font(.headline)
                            if !battleNetManager.userCharacters.isEmpty {
                                Text("\(battleNetManager.userCharacters.count) WoW Character(s)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        Menu {
                            Button("View Characters") {
                                showingCharacterList = true
                            }
                            .disabled(battleNetManager.userCharacters.isEmpty)
                            
                            Button("Disconnect", role: .destructive) {
                                battleNetManager.disconnect()
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .foregroundColor(.blue)
                        }
                    } else {
                        Text("Battle.net")
                        
                        Spacer()
                        
                        Button("Connect") {
                            showingBattleNetConnect = true
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(.vertical, 4)
            }
            
            Section("Account Actions") {
                NavigationLink("Change Password") {
                    ChangePasswordView()
                        .environmentObject(authManager)
                }
                
                NavigationLink("Change Email") {
                    ChangeEmailView()
                        .environmentObject(authManager)
                }
            }
            
            Section("Danger Zone") {
                Button("Delete Account") {
                    viewModel.showingDeleteConfirmation = true
                }
                .foregroundColor(.red)
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Edit") {
                    showingEditProfile = true
                }
            }
        }
        .onAppear {
            viewModel.loadUserData(from: authManager.currentUser)
        }
        .sheet(isPresented: $showingEditProfile) {
            ProfileEditView(viewModel: viewModel)
                .environmentObject(authManager)
        }
        .sheet(isPresented: $showingBattleNetConnect) {
            BattleNetConnectView()
                .environmentObject(battleNetManager)
        }
        .sheet(isPresented: $showingCharacterList) {
            WoWCharacterListView()
                .environmentObject(battleNetManager)
        }
        .alert("Delete Account", isPresented: $viewModel.showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task {
                    await viewModel.deleteAccount(authManager: authManager)
                }
            }
        } message: {
            Text("Are you sure you want to delete your account? This action cannot be undone.")
        }
        .alert("Battle.net Error", isPresented: .constant(battleNetManager.error != nil)) {
            Button("OK") {
                battleNetManager.error = nil
            }
        } message: {
            if let error = battleNetManager.error {
                Text(error.localizedDescription)
            }
        }
    }
}

// MARK: - Battle.net Connect View
struct BattleNetConnectView: View {
    @EnvironmentObject var battleNetManager: BattleNetAPIManager
    @Environment(\.dismiss) var dismiss
    @State private var isConnecting = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                    .padding(.top, 40)
                
                VStack(spacing: 16) {
                    Text("Connect Battle.net")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Link your Battle.net account to import your World of Warcraft characters and guild information.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Label("View your WoW characters", systemImage: "person.3.fill")
                    Label("Access guild information", systemImage: "flag.fill")
                    Label("Find guilds matching your characters", systemImage: "magnifyingglass")
                }
                .font(.subheadline)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
                
                Spacer()
                
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }
                
                Button(action: connectBattleNet) {
                    if isConnecting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Connect with Battle.net")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
                .padding(.horizontal)
                .disabled(isConnecting)
                
                Button("Maybe Later") {
                    dismiss()
                }
                .foregroundColor(.secondary)
                .padding(.bottom, 30)
            }
            .navigationBarItems(trailing: Button("Cancel") { dismiss() })
        }
    }
    
    func connectBattleNet() {
        isConnecting = true
        errorMessage = nil
        
        Task {
            do {
                try await battleNetManager.authenticate()
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                isConnecting = false
            }
        }
    }
}

// MARK: - WoW Character List View
struct WoWCharacterListView: View {
    @EnvironmentObject var battleNetManager: BattleNetAPIManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                if battleNetManager.isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                            .padding()
                        Spacer()
                    }
                } else if battleNetManager.userCharacters.isEmpty {
                    Text("No WoW characters found")
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    ForEach(battleNetManager.userCharacters) { character in
                        WoWCharacterRow(character: character)
                    }
                }
            }
            .navigationTitle("WoW Characters")
            .navigationBarItems(trailing: Button("Done") { dismiss() })
        }
    }
}

// MARK: - WoW Character Row
struct WoWCharacterRow: View {
    let character: WoWCharacter
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(character.name)
                        .font(.headline)
                    
                    Text("Level \(character.level)")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color(.systemGray5))
                        .cornerRadius(4)
                }
                
                Text("\(character.characterClass.name) - \(character.race.name)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack {
                    Image(systemName: "server.rack")
                        .font(.caption)
                    Text(character.realm.name)
                        .font(.caption)
                    
                    if let guild = character.guild {
                        Text("•")
                            .foregroundColor(.secondary)
                        Image(systemName: "flag.fill")
                            .font(.caption)
                        Text(guild.name)
                            .font(.caption)
                    }
                }
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Faction indicator
            Image(systemName: character.faction.type == "ALLIANCE" ? "shield.fill" : "flame.fill")
                .foregroundColor(character.faction.type == "ALLIANCE" ? .blue : .red)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthenticationManager())
}
