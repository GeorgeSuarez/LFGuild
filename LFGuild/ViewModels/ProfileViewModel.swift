//
//  ProfileViewModel.swift
//  LFGuild
//
//  Created by George Suarez on 8/2/25.
//

import SwiftUI

@MainActor
class ProfileViewModel: ObservableObject {
    @Published var name = ""
    @Published var email = ""
    @Published var countryRegion = ""
    @Published var isLoading = false
    @Published var showingError = false
    @Published var showingDeleteConfirmation = false
    @Published var errorMessage = ""
    
    private var originalName = ""
    private var originalCountryRegion = ""
    
    var hasChanges: Bool {
        name != originalName || countryRegion != originalCountryRegion
    }
    
    func loadUserData(from user: UserModel?) {
        guard let user = user else { return }
        
        name = user.name
        email = user.email
        countryRegion = user.countryRegion
        
        originalName = user.name
        originalCountryRegion = user.countryRegion
    }
    
    func discardChanges() {
        name = originalName
        countryRegion = originalCountryRegion
    }
    
    func saveProfile(authManager: AuthenticationManager) async {
        guard hasChanges else { return }
        
        isLoading = true
        
        do {
            let nameUpdate = name != originalName ? name : nil
            let regionUpdate = countryRegion != originalCountryRegion ? countryRegion : nil
            
            try await authManager.updateProfile(
                name: nameUpdate,
                countryRegion: regionUpdate
            )
            
            originalName = name
            originalCountryRegion = countryRegion
            
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
    
    func deleteAccount(authManager: AuthenticationManager) async {
        isLoading = true
        
        do {
            try await authManager.deleteAccount()
            
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
            isLoading = false
        }
    }
}

