//
//  ChangePasswordViewModel.swift
//  LFGuild
//
//  Created by George Suarez on 8/2/25.
//

import Foundation
import FirebaseAuth

@MainActor
class ChangePasswordViewModel: ObservableObject {
    @Published var currentPassword = ""
    @Published var newPassword = ""
    @Published var confirmPassword = ""
    @Published var isLoading = false
    @Published var showingError = false
    @Published var showingSuccess = false
    @Published var errorMessage = ""
    
    var isFormValid: Bool {
        !currentPassword.isEmpty &&
        !newPassword.isEmpty &&
        !confirmPassword.isEmpty &&
        newPassword == confirmPassword &&
        newPassword.count >= 8
    }
    
    func changePassword() async {
        guard isFormValid else { return }
        
        isLoading = true
        
        do {
            guard let user = Auth.auth().currentUser,
                  let email = user.email else {
                throw AuthenticationError.userNotFound
            }
            
            let credential = EmailAuthProvider.credential(withEmail: email, password: currentPassword)
            try await user.reauthenticate(with: credential)
            
            try await user.updatePassword(to: newPassword)
            
        } catch {
            errorMessage = AuthenticationError.from(error).localizedDescription
            showingError = true
        }
        
        isLoading = false
    }
}
