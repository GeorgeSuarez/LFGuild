//
//  ChangeEmailView.swift
//  LFGuild
//
//  Created by George Suarez on 8/2/25.
//

import SwiftUI
import FirebaseAuth

struct ChangeEmailView: View {
    @StateObject private var viewModel = ChangeEmailViewModel()
    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        Form {
            Section("Current Email") {
                Text(authManager.currentUser?.email ?? "")
                    .foregroundColor(.secondary)
            }
            
            Section("Authentication") {
                SecureField("Enter your password", text: $viewModel.password)
            }
            
            Section("New Email") {
                TextField("Enter new email", text: $viewModel.newEmail)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
            }
            
            Section {
                Button("Change Email") {
                    Task {
                        await viewModel.changeEmail(authManager: authManager)
                    }
                }
                .disabled(!viewModel.isFormValid || viewModel.isLoading)
            }
            
            Section {
                Text("A verification email will be sent to your new email address. You'll need to verify it before the change takes effect.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Change Email")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Success", isPresented: $viewModel.showingSuccess) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("A verification email has been sent to your new email address. Please verify it to complete the change.")
        }
        .alert("Error", isPresented: $viewModel.showingError) {
            Button("OK") { }
        } message: {
            Text(viewModel.errorMessage)
        }
        .overlay {
            if viewModel.isLoading {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                
                ProgressView()
                    .scaleEffect(1.5)
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            }
        }
    }
}

#Preview {
    ChangeEmailView()
}
