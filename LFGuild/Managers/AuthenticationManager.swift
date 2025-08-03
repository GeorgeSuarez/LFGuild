//
//  AuthenticationManager.swift
//  LFGuild
//
//  Created by George Suarez on 8/1/25.
//

import Foundation
import SwiftUI
import Combine
import FirebaseAuth
import FirebaseFirestore

enum AuthenticationError: LocalizedError {
    case invalidEmail
    case weakPassword
    case networkError
    case invalidCredentials
    case wrongPassword
    case userNotFound
    case emailAlreadyExists
    case emailAlreadyInUse
    case userDisabled
    case tooManyRequests
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidEmail:
            return "Please enter a valid email address"
        case .weakPassword:
            return "Password must be at least 8 characters long"
        case .networkError:
            return "Network connection failed. Please try again"
        case .invalidCredentials, .wrongPassword:
            return "Invalid email or password"
        case .userNotFound:
            return "No account found with this email"
        case .emailAlreadyExists, .emailAlreadyInUse:
            return "An account with this email already exists"
        case .userDisabled:
            return "This account has been disabled"
        case .tooManyRequests:
            return "Too many failed attempts. Please try again later"
        case .unknown(let message):
            return message
        }
    }
    
    static func from(_ error: Error) -> AuthenticationError {
        guard let authError = error as NSError? else {
            return .unknown(error.localizedDescription)
        }
        
        switch authError.code {
        case AuthErrorCode.invalidEmail.rawValue:
            return .invalidEmail
        case AuthErrorCode.weakPassword.rawValue:
            return .weakPassword
        case AuthErrorCode.wrongPassword.rawValue, AuthErrorCode.userNotFound.rawValue:
            return .wrongPassword
        case AuthErrorCode.emailAlreadyInUse.rawValue:
            return .emailAlreadyInUse
        case AuthErrorCode.userDisabled.rawValue:
            return .userDisabled
        case AuthErrorCode.tooManyRequests.rawValue:
            return .tooManyRequests
        default:
            return .unknown(authError.localizedDescription)
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
    
    private let db = Firestore.firestore()
    private var authStateListener: AuthStateDidChangeListenerHandle?
    private let keychain = KeychainManager()
    private var cancellables: Set<AnyCancellable> = []
    
    init() {
        setupAuthStateListener()
    }
    
    deinit {
        if let listener = authStateListener {
            Auth.auth().removeStateDidChangeListener(listener)
        }
    }
    
    func signIn(email: String, password: String) async throws {
        authState = .loading
        
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            let user = try await fetchUserProfile(uid: result.user.uid, email: email)
            
            currentUser = user
            authState = .authenticated(user)
            
        } catch {
            authState = .unauthenticated
            throw AuthenticationError.from(error)
        }
    }
    
    func signOut() {
        do {
            try Auth.auth().signOut()
            currentUser = nil
            authState = .unauthenticated
        } catch {
            print("Error signing out: \(error.localizedDescription)")
        }
    }
    
    func register(name: String, email: String, password: String, countryRegion: String) async throws {
        authState = .loading
        
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            
            let userModel = UserModel(
                firebaseUID: result.user.uid,
                name: name,
                email: email,
                countryRegion: countryRegion
            )
            
            try await createUserProfile(userModel)
            
            currentUser = userModel
            authState = .authenticated(userModel)
            
        } catch {
            authState = .unauthenticated
            throw AuthenticationError.from(error)
        }
    }
    
    func resetPassword(email: String) async throws {
        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
        } catch {
            throw AuthenticationError.from(error)
        }
    }
    
    func updateProfile(name: String? = nil, countryRegion: String? = nil) async throws {
        guard let currentUser = currentUser,
              let firebaseUser = Auth.auth().currentUser else {
            throw AuthenticationError.userNotFound
        }
        
        var updates: [String: Any] = [:]
        var updatedUser = currentUser
        
        if let name = name {
            updates["name"] = name
            updatedUser.name = name
        }
        
        if let countryRegion = countryRegion {
            updates["countryRegion"] = countryRegion
            updatedUser.countryRegion = countryRegion
        }
        
        if !updates.isEmpty {
            updates["updatedAt"] = FieldValue.serverTimestamp()
            
            try await db.collection("users").document(firebaseUser.uid).updateData(updates)
            self.currentUser = updatedUser
        }
    }
    
    func changePassword(currentPassword: String, newPassword: String) async throws {
        guard let firebaseUser = Auth.auth().currentUser,
              let email = firebaseUser.email else {
            throw AuthenticationError.userNotFound
        }
        
        let credential = EmailAuthProvider.credential(withEmail: email, password: currentPassword)
        try await firebaseUser.reauthenticate(with: credential)
        
        try await firebaseUser.updatePassword(to: newPassword)
    }
    
    func changeEmail(newEmail: String, password: String) async throws {
        guard let firebaseUser = Auth.auth().currentUser,
              let currentEmail = firebaseUser.email else {
            throw AuthenticationError.userNotFound
        }
        
        let credential = EmailAuthProvider.credential(withEmail: currentEmail, password: password)
        try await firebaseUser.reauthenticate(with: credential)
        
        try await firebaseUser.sendEmailVerification(beforeUpdatingEmail: newEmail)
    }
    
    func deleteAccount() async throws {
        guard let firebaseUser = Auth.auth().currentUser else {
            throw AuthenticationError.userNotFound
        }
        
        try await db.collection("users").document(firebaseUser.uid).delete()
        
        try await firebaseUser.delete()
        
        currentUser = nil
        authState = .unauthenticated
    }
    
    private func setupAuthStateListener() {
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                guard let self = self else { return }
                
                if let user = user {
                    do {
                        let userModel = try await self.fetchUserProfile(uid: user.uid, email: user.email ?? "")
                        self.currentUser = userModel
                        self.authState = .authenticated(userModel)
                    } catch {
                        self.authState = .unauthenticated
                    }
                } else {
                    self.currentUser = nil
                    self.authState = .unauthenticated
                }
            }
        }
    }
    
    private func fetchUserProfile(uid: String, email: String) async throws -> UserModel {
        let document = try await db.collection("users").document(uid).getDocument()
        
        guard let data = document.data() else {
            throw AuthenticationError.userNotFound
        }
        
        return UserModel(
            firebaseUID: uid,
            name: data["name"] as? String ?? "",
            email: email,
            countryRegion: data["countryRegion"] as? String ?? ""
        )
    }
    
    private func createUserProfile(_ user: UserModel) async throws {
        let userData: [String: Any] = [
            "name": user.name,
            "email": user.email,
            "countryRegion": user.countryRegion,
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp(),
        ]
        
        try await db.collection("users").document(user.firebaseUID!).setData(userData)
    }
}

