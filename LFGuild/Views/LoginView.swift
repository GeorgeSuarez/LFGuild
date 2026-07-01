//
//  LoginView.swift
//  LFGuild
//
//  Created by George Suarez on 7/28/25.
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var authManager: AuthenticationManager

    @State private var email: String = ""
    @State private var password: String = ""
    @State private var showPassword: Bool = false
    @State private var showRegistration = false
    @State private var showForgotPassword = false

    @FocusState private var focusedField: Field?

    private enum Field {
        case email, password
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    header

                    form

                    actions

                    Spacer(minLength: 24)
                }
                .padding(.horizontal, 24)
                .padding(.top, 48)
                .padding(.bottom, 24)
            }
            .toolbarVisibility(.hidden, for: .navigationBar)
        }
        .sheet(isPresented: $showRegistration) {
            RegistrationView()
                .environmentObject(authManager)
        }
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordView()
                .environmentObject(authManager)
        }
    }

    // MARK: - Subviews

    private var header: some View {
        VStack(spacing: 12) {
            Image("LFGuildLogo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 100, height: 100)
                .clipShape(.rect(cornerRadius: 24))

            Text("LFGuild")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundStyle(.primary)

            Text("Find your perfect guild")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var form: some View {
        VStack(spacing: 20) {
            FormInputField(
                title: "Email",
                icon: "envelope",
                isFocused: focusedField == .email
            ) {
                TextField("Enter your email", text: $email)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .email)
                    .onSubmit { focusedField = .password }
            }

            FormInputField(
                title: "Password",
                icon: "lock",
                isSecure: true,
                isSecureVisible: $showPassword,
                isFocused: focusedField == .password
            ) {
                Group {
                    if showPassword {
                        TextField("Enter your password", text: $password)
                    } else {
                        SecureField("Enter your password", text: $password)
                    }
                }
                .textContentType(.password)
                .focused($focusedField, equals: .password)
                .onSubmit { signIn() }
            }

            HStack {
                Spacer()
                Button("Forgot Password?") {
                    showForgotPassword = true
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }

            if let error = authManager.lastError {
                Text(error.errorDescription ?? "An error occurred")
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 8)
            }
        }
    }

    private var actions: some View {
        VStack(spacing: 16) {
            Button(action: signIn) {
                HStack(spacing: 8) {
                    if case .loading = authManager.authState {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.8)
                    }

                    Text("Sign In")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .foregroundStyle(.white)
                .background(isSignInDisabled ? Color.gray.opacity(0.5) : Color.blue)
                .clipShape(.rect(cornerRadius: 16))
            }
            .disabled(isSignInDisabled)

            HStack(spacing: 4) {
                Text("Don't have an account?")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Button("Create one") {
                    showRegistration = true
                }
                .font(.footnote)
                .fontWeight(.semibold)
                .foregroundStyle(.blue)
            }
        }
    }

    // MARK: - Computed Properties

    private var isSignInDisabled: Bool {
        !email.isValidEmail || password.isEmpty || authManager.authState == .loading
    }

    // MARK: - Actions

    private func signIn() {
        Task {
            do {
                try await authManager.signIn(email: email, password: password)
            } catch {
                // Error is already stored in authManager.lastError
            }
        }
    }

}

#Preview {
    LoginView()
        .environmentObject(AuthenticationManager())
}
