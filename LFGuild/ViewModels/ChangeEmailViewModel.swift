//
//  ChangeEmailViewModel.swift
//  LFGuild
//
//  Created by George Suarez on 8/2/25.
//

import Foundation
import FirebaseAuth

@MainActor
class ChangeEmailViewModel: ObservableObject {
    @Published var newEmail = ""
    @Published var password = ""
    @Published var isLoading = false
    @Published var showingError = false
    @Published var showingSuccess = false
    @Published var errorMessage = ""
    
    var isFormValid: Bool {
        !newEmail.isEmpty &&
        !password.isEmpty &&
        newEmail.contains("@") &&
        newEmail.contains(".")
    }
    
    func changeEmail(authManager: AuthenticationManager) async {
        guard isFormValid else { return }
        
        isLoading = true
        
        do {
            guard let user = Auth.auth().currentUser,
                  let currentEmail = user.email else {
                throw AuthenticationError.userNotFound
            }
            
            // Re-authenticate the user
            let credential = EmailAuthProvider.credential(withEmail: currentEmail, password: password)
            try await user.reauthenticate(with: credential)
            
            // Send verification email to new address
            try await user.sendEmailVerification(beforeUpdatingEmail: newEmail)
            
            showingSuccess = true
            
        } catch {
            errorMessage = AuthenticationError.from(error).localizedDescription
            showingError = true
        }
        
        isLoading = false
    }
}
