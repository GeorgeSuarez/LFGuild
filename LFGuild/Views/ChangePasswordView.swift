//
//  ChangePasswordView.swift
//  LFGuild
//
//  Created by George Suarez on 8/2/25.
//

import SwiftUI

struct ChangePasswordView: View {
    @StateObject private var viewModel = ChangePasswordViewModel()
    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        Form {
            Section("Current Password") {
                SecureField("Enter current password", text: $viewModel.currentPassword)
            }
            
            Section("New Password") {
                SecureField("Enter new password", text: $viewModel.newPassword)
                SecureField("Confirm new password", text: $viewModel.confirmPassword)
            }
            
            Section {
                Button("Change Password") {
                    Task {
                        await viewModel.changePassword()
                    }
                }
                .disabled(!viewModel.isFormValid || viewModel.isLoading)
            }
        }
        .navigationTitle("Change Password")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Success", isPresented: $viewModel.showingSuccess) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Your password has been changed successfully.")
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
    ChangePasswordView()
}
