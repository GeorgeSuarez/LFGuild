//
//  ProfileView.swift
//  LFGuild
//
//  Created by George Suarez on 8/2/25.
//

import SwiftUI
import FirebaseAuth

struct ProfileView: View {
    @StateObject private var viewModel = ProfileViewModel()
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var showingEditProfile = false
    
    var isSheet: Bool = false
    
    var body: some View {
        List {
            Section("Profile Information") {
                ProfileInfoRow(title: "Name", value: viewModel.name)
                ProfileInfoRow(title: "Email", value: viewModel.email)
                ProfileInfoRow(title: "Country/Region", value: viewModel.countryRegion)
                
                NavigationLink("Preferences") {
                    PreferencesView()
                        .environmentObject(authManager)
                }
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
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthenticationManager())
}
