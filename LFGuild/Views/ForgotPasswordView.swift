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

    @FocusState private var isEmailFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    header

                    FormInputField(
                        title: "Email",
                        icon: "envelope",
                        isFocused: isEmailFocused
                    ) {
                        TextField("name@example.com", text: $email)
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($isEmailFocused)
                            .onSubmit { resetPassword() }
                    }

                    if let message = message {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(isSuccess ? .green : .red)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 8)
                    }

                    Button(action: resetPassword) {
                        HStack(spacing: 8) {
                            if isLoading {
                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(0.8)
                            }

                            Text("Send Reset Link")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .foregroundStyle(.white)
                        .background(isSubmitDisabled ? Color.gray.opacity(0.5) : Color.blue)
                        .clipShape(.rect(cornerRadius: 16))
                    }
                    .disabled(isSubmitDisabled)

                    Spacer(minLength: 24)
                }
                .padding(.horizontal, 24)
                .padding(.top, 32)
                .padding(.bottom, 24)
            }
            .navigationTitle("Reset Password")
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

    // MARK: - Subviews

    private var header: some View {
        VStack(spacing: 12) {
            Image(systemName: "envelope.circle")
                .font(.system(size: 72))
                .foregroundStyle(.blue)

            Text("Reset Password")
                .font(.title)
                .fontWeight(.bold)
                .foregroundStyle(.primary)

            Text("Enter your email address and we'll send you a link to reset your password.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Computed Properties

    private var isSubmitDisabled: Bool {
        email.isEmpty || isLoading
    }

    // MARK: - Actions

    private func resetPassword() {
        Task {
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
}

#Preview {
    ForgotPasswordView()
        .environmentObject(AuthenticationManager())
}
