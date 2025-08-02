//
//  AuthenticationManager.swift
//  LFGuild
//
//  Created by George Suarez on 8/1/25.
//

import Foundation
import SwiftUI
import Combine

enum AuthenticationError: LocalizedError {
    case invalidEmail
    case weakPassword
    case networkError
    case invalidCredentials
    case userNotFound
    case emailAlreadyExists
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidEmail:
            return "Please enter a valid email address"
        case .weakPassword:
            return "Password must be at least 8 characters long"
        case .networkError:
            return "Network connection failed. Please try again"
        case .invalidCredentials:
            return "Invalid email or password"
        case .userNotFound:
            return "No account found with this email"
        case .emailAlreadyExists:
            return "An account with this email already exists"
        case .unknown(let message):
            return message
        }
    }
}

enum AuthenticationState: Equatable {
    case idle
    case loading
    case authenticated(UserModel)
    case unauthenticated
    
    static func == (lhs: AuthenticationState, rhs: AuthenticationState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.loading, .loading), (.unauthenticated, .unauthenticated):
            return true
        case (.authenticated(let lhsUser), .authenticated(let rhsUser)):
            return lhsUser.id == rhsUser.id
        default:
            return false
        }
    }
}

@MainActor
class AuthenticationManager: ObservableObject {
    @Published var authState: AuthenticationState = .idle
    @Published var currentUser: UserModel?
    
    private let keychain = KeychainManager()
    private var cancellables: Set<AnyCancellable> = []
    
    init() {
        checkAuthenticationStatus()
    }
    
    func signIn(email: String, password: String) async throws {
        authState = .loading
        
        try validateEmail(email)
        try validatePassword(password)
        
        do {
            let user = try await performSignIn(email: email, password: password)
            
            try keychain.store(email: email, password: password)
            
            currentUser = user
            authState = .authenticated(user)
        } catch {
            authState = .unauthenticated
            throw error
        }
    }
    
    func signOut() {
        keychain.deleteCrendentials()
        currentUser = nil
        authState = .unauthenticated
    }
    
    func register(name: String, email: String, password: String, countryRegion: String) async throws {
        authState = .loading
        
        try validateEmail(email)
        try validatePassword(password)
        try validateName(name)
        
        do {
            let user = try await performRegistration(
                name: name,
                email: email,
                password: password,
                countryRegion: countryRegion
            )
            
            try keychain.store(email: email, password: password)
            
            currentUser = user
            authState = .authenticated(user)
            
        } catch {
            authState = .unauthenticated
            throw error
        }
    }
    
    private func checkAuthenticationStatus() {
        if let credentials = keychain.getCredentials() {
            Task {
                do {
                    let user = try await performSignIn(
                        email: credentials.email,
                        password: credentials.password
                    )
                    currentUser = user
                    authState = .authenticated(user)
                } catch {
                    authState = .unauthenticated
                }
            }
        } else {
            authState = .unauthenticated
        }
    }
    
    private func validateEmail(_ email: String) throws {
        let emailRegex = "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        
        if !emailPredicate.evaluate(with: email) {
            throw AuthenticationError.invalidEmail
        }
    }
    
    private func validatePassword(_ password: String) throws {
        if password.count < 8 {
            throw AuthenticationError.weakPassword
        }
    }
    
    private func validateName(_ name: String) throws {
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw AuthenticationError.unknown("Name cannot be empty")
        }
    }
    
    private func performSignIn(email: String, password: String) async throws -> UserModel {
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        if email == "test@example.com" && password == "password123" {
            return UserModel(
                name: "Test User",
                email: email,
                countryRegion: "US"
            )
        } else {
            throw AuthenticationError.invalidCredentials
        }
    }
    
    private func performRegistration(name: String, email: String, password: String, countryRegion: String) async throws -> UserModel {
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        return UserModel(
            name: name,
            email: email,
            countryRegion: countryRegion
        )
    }
}

