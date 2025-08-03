//
//  ProfileEditView.swift
//  LFGuild
//
//  Created by George Suarez on 8/3/25.
//

import SwiftUI

struct ProfileEditView: View {
    @ObservedObject var viewModel: ProfileViewModel
    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Profile Information") {
                    HStack {
                        Text("Name")
                        Spacer()
                        TextField("Enter your name", text: $viewModel.name)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Text("Email")
                        Spacer()
                        Text(viewModel.email)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Country/Region")
                        Spacer()
                        TextField("Enter country/region", text: $viewModel.countryRegion)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        viewModel.discardChanges()
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            await viewModel.saveProfile(authManager: authManager)
                            if !viewModel.showingError {
                                dismiss()
                            }
                        }
                    }
                    .disabled(!viewModel.hasChanges || viewModel.isLoading)
                    .fontWeight(.semibold)
                }
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
}

#Preview {
    ProfileEditView(viewModel: ProfileViewModel())
        .environmentObject(AuthenticationManager())
}
