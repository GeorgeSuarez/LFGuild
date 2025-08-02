//
//  LoginView.swift
//  LFGuild
//
//  Created by George Suarez on 7/28/25.
//

import SwiftUI

struct LoginView: View {
    @StateObject private var authManager = AuthenticationManager()
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var showPassword: Bool = false
    @State private var errorMessage: String?
    @State private var showRegistration = false
    @State private var showForgotPassword = false
    @FocusState private var isEmailFocused: Bool
    @FocusState private var isPasswordFocused: Bool
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    Image("LFGuildLogo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 120, height: 120)
                    
                    Text("LFGuild")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
                
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        
                        TextField("Email", text: $email)
                            .textFieldStyle(CustomTextFieldStyle())
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .autocapitalization(.none)
                            .focused($isEmailFocused)
                            .onSubmit {
                                isPasswordFocused = true
                            }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Group {
                                if showPassword {
                                    TextField("Password", text: $password)
                                } else {
                                    SecureField("Password",text: $password)
                                }
                            }
                            .textContentType(.password)
                            .focused($isPasswordFocused)
                            .onSubmit {
                                Task {
                                    await handleSignIn()
                                }
                            }
                            
                            Button(action: {
                                showPassword.toggle()
                            }) {
                                Image(systemName: showPassword ? "eye.slash" : "eye")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(24)
                        .padding()
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isPasswordFocused ? Color.blue : Color.clear, lineWidth: 2)
                        )
                    }
                }
                
                HStack {
                    Spacer()
                    Button("Forgot Password?") {
                        showForgotPassword = true
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
                
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }
                
                VStack(spacing: 12) {
                    Button(action: {
                        Task {
                            await handleSignIn()
                        }
                    }) {
                        HStack {
                            if case .loading = authManager.authState {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            }
                            
                            Text("Sign In")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            isSignInDisabled ? Color.gray : Color.blue
                        )
                        .cornerRadius(24)
                    }
                    .disabled(isSignInDisabled)
                    
                    Button(action: {
                        showRegistration.toggle()
                    }) {
                        Text("Create Account")
                            .font(.headline)
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.clear)
                            .overlay(
                                RoundedRectangle(cornerRadius: 24)
                                    .stroke(Color.blue, lineWidth: 2)
                            )
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showRegistration) {
            RegistrationView()
                .environmentObject(authManager)
        }
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordView()
                .environmentObject(authManager)
        }
        .fullScreenCover(isPresented: .constant(isAuthenticated)) {
            HomeView(user: authManager.currentUser!)
                .environmentObject(authManager)
        }
    }
    
    private var isSignInDisabled: Bool {
        email.isEmpty || password.isEmpty || authManager.authState == .loading
    }
    
    private var isAuthenticated: Bool {
        if case .authenticated = authManager.authState {
            return true
        }
        
        return false
    }
    
    private func handleSignIn() async {
        errorMessage = nil
        
        do {
            try await authManager.signIn(email: email, password: password)
        } catch {
            errorMessage = (error as? AuthenticationError)?.errorDescription ?? error.localizedDescription
        }
    }
}

struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(Color.blue.opacity(0.2))
            .cornerRadius(24)
            .padding()
    }
}

#Preview {
    LoginView()
}
