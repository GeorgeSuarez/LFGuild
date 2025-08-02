//
//  RegistrationView.swift
//  LFGuild
//
//  Created by George Suarez on 7/28/25.
//

import Foundation
import SwiftUI

struct RegistrationView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authManager: AuthenticationManager
    
    @State private var name: String = ""
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var countryRegion: String = "United States"
    @State private var errorMessage: String?
    @State private var showPassword: Bool = false
    @FocusState private var focusedField: RegistrationField?
    
    enum RegistrationField {
        case name, email, password, confirmPassword
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 16) {
                        Text("Create Account")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("Join the LFGuild community")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top)
                    
                    VStack(spacing: 16) {
                        CustomFormField(
                            title: "Full Name",
                            text: $name,
                            placeholder: "Enter your full name",
                            focused: $focusedField,
                            field: .name
                        )
                        
                        CustomFormField(
                            title: "Email",
                            text: $email,
                            placeholder: "Enter your email",
                            focused: $focusedField,
                            field: .email,
                            keyboardType: .emailAddress,
                            textContentType: .emailAddress
                        )
                        
                        CustomFormField(
                            title: "Password",
                            text: $password,
                            placeholder: "Create a password",
                            focused: $focusedField,
                            field: .password,
                            textContentType: .newPassword,
                            isSecure: !showPassword,
                            showPasswordToggle: true,
                            showPassword: $showPassword
                        )
                        
                        CustomFormField(
                            title: "Confirm Password",
                            text: $confirmPassword,
                            placeholder: "Confirm your password",
                            focused: $focusedField,
                            field: .confirmPassword,
                            textContentType: .newPassword,
                            isSecure: true,
                        )
                        
                        VStack(alignment: .leading) {
                            Text("Country/Region")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Picker("Country/Region", selection: $countryRegion) {
                                Text("United States").tag("United States")
                                Text("Canada").tag("Canada")
                                Text("United Kingdom").tag("United Kingdom")
                                Text("Australia").tag("Australia")
                                Text("Germany").tag("Germany")
                                Text("France").tag("France")
                                Text("Japan").tag("Japan")
                                Text("Other").tag("Other")
                            }
                            .pickerStyle(MenuPickerStyle())
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                    }
                    
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                    }
                    
                    Button(action: {
                        Task {
                            await handleRegistration()
                        }
                    }) {
                        HStack {
                            if case .loading = authManager.authState {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            }
                            
                            Text("Create Account")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            isRegisterDisabled ? Color.gray : Color.blue
                        )
                        .cornerRadius(10)
                    }
                    .disabled(isRegisterDisabled)
                    
                    Spacer()
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var isRegisterDisabled: Bool {
        name.isEmpty || email.isEmpty || password.isEmpty ||
        confirmPassword.isEmpty || authManager.authState == .loading
    }
    
    private func handleRegistration() async {
        errorMessage = nil
        
        guard password == confirmPassword else {
            errorMessage = "Passwords do not match"
            return
        }
        
        do {
            try await authManager.register(
                name: name,
                email: email,
                password: password,
                countryRegion: countryRegion
            )
            dismiss()
        } catch {
            errorMessage = (error as? AuthenticationError)?.errorDescription ?? error.localizedDescription
        }
    }
}

#Preview {
    RegistrationView()
}
