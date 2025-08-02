//
//  ForgotPasswordView.swift
//  LFGuild
//
//  Created by George Suarez on 8/1/25.
//

import SwiftUI

struct ForgotPasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authManager: AuthenticationManager
    
    @State private var email: String = ""
    @State private var message: String?
    @State private var isLoading: Bool = false
    @State private var isSuccess: Bool = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    Image(systemName: "envelope.circle")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("Reset Password")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Enter your email address and we'll send you a link to reset your password.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Email")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextField("Enter your email", text: $email)
                        .textFieldStyle(CustomTextFieldStyle())
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)
                }
                
                if let message = message {
                    Text(message)
                        .font(.caption)
                        .foregroundColor(isSuccess ? .green : .red)
                        .multilineTextAlignment(.center)
                }
                
                Button(action: {
                    Task {
                        await handlePasswordReset()
                    }
                }) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        }
                        
                        Text("Send Reset Link")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(email.isEmpty || isLoading ? Color.gray : Color.blue)
                    .cornerRadius(10)
                }
                .disabled(email.isEmpty || isLoading)
                
                Spacer()
            }
            .padding()
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
    
    private func handlePasswordReset() async {
        message = nil
        isLoading = true
        
        do {
            try await authManager.resetPassword(email: email)
            message = "Password reset link sent to your email"
            isSuccess = true
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                dismiss()
            }
        } catch {
            message = (error as? AuthenticationError)?.errorDescription ?? error.localizedDescription
            isSuccess = false
        }
        
        isLoading = false
    }
}

#Preview {
    ForgotPasswordView()
}
