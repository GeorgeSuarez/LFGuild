//
//  UserModel.swift
//  LFGuild
//
//  Created by George Suarez on 7/28/25.
//

import Foundation

class UserModel: Identifiable, ObservableObject, Equatable {
    let id: UUID
    @Published var firebaseUID: String?
    @Published var name: String
    @Published var email: String
    @Published var countryRegion: String
    @Published var roles: Set<String> = []
    @Published var availableDays: Set<String> = []
    @Published var availableStartTime: Date?
    @Published var availableEndTime: Date?
    @Published var gamingTags: Set<String> = []
    @Published var preferredRealms: Set<String> = []
    
    init(id: UUID = UUID(), firebaseUID: String? = nil, name: String, email: String, countryRegion: String) {
        self.id = id
        self.firebaseUID = firebaseUID
        self.name = name
        self.email = email
        self.countryRegion = countryRegion
    }
    
    static func == (lhs: UserModel, rhs: UserModel) -> Bool {
        return lhs.id == rhs.id
    }
    
}
