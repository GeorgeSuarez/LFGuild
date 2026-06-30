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
    @State private var verificationMessage: String?
    @State private var isVerificationLoading = false
    #if DEBUG
    @State private var showingSeedData = false
    #endif

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
            
            if !isAnonymous {
                Section("Email Verification") {
                    HStack {
                        Image(systemName: authManager.isEmailVerified ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                            .foregroundColor(authManager.isEmailVerified ? .green : .orange)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(authManager.isEmailVerified ? "Verified" : "Not Verified")
                                .font(.subheadline)
                                .fontWeight(.medium)

                            Text(authManager.isEmailVerified
                                 ? "Your email address is verified."
                                 : "Verify your email to create guilds and submit applications.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                    }

                    if !authManager.isEmailVerified {
                        Button(action: resendVerificationEmail) {
                            HStack {
                                if isVerificationLoading {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                }
                                Text("Resend Verification Email")
                            }
                        }
                        .disabled(isVerificationLoading)

                        Button("I've Verified My Email") {
                            Task {
                                await checkVerificationStatus()
                            }
                        }
                        .disabled(isVerificationLoading)
                    }

                    if let verificationMessage = verificationMessage {
                        Text(verificationMessage)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Section("Account Actions") {
                if !isAnonymous {
                    NavigationLink("Change Password") {
                        ChangePasswordView()
                            .environmentObject(authManager)
                    }

                    NavigationLink("Change Email") {
                        ChangeEmailView()
                            .environmentObject(authManager)
                    }
                }

                Button("Delete Account") {
                    viewModel.showingDeleteConfirmation = true
                }
                .foregroundColor(.red)
            }

            #if DEBUG
            Section("Debug") {
                Button("Seed Sample Data") {
                    showingSeedData = true
                }
                .foregroundColor(.green)
            }
            #endif

            Section {
                Button("Sign Out") {
                    authManager.signOut()
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
        #if DEBUG
        .sheet(isPresented: $showingSeedData) {
            SeedDataView()
                .environmentObject(authManager)
        }
        #endif
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

    private var isAnonymous: Bool {
        Auth.auth().currentUser?.isAnonymous == true
    }

    private func resendVerificationEmail() {
        isVerificationLoading = true
        verificationMessage = nil

        Task {
            do {
                try await authManager.sendEmailVerification()
                verificationMessage = "Verification email sent. Check your inbox."
            } catch {
                verificationMessage = (error as? AuthenticationError)?.errorDescription ?? error.localizedDescription
            }
            isVerificationLoading = false
        }
    }

    private func checkVerificationStatus() async {
        isVerificationLoading = true
        verificationMessage = nil

        do {
            try await authManager.reloadEmailVerificationStatus()
            if authManager.isEmailVerified {
                verificationMessage = "Your email is now verified."
            } else {
                verificationMessage = "Your email is still not verified. Please check your inbox and tap the verification link."
            }
        } catch {
            verificationMessage = (error as? AuthenticationError)?.errorDescription ?? error.localizedDescription
        }

        isVerificationLoading = false
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthenticationManager())
}
