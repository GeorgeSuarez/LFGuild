//
//  UserModel.swift
//  LFGuild
//
//  Created by George Suarez on 7/28/25.
//

import Foundation

class UserModel: Identifiable, ObservableObject, Equatable {
    let id: UUID
    var firebaseUID: String?
    var name: String
    var email: String
    var countryRegion: String
    var roles: Set<String> = []
    var availableDays: Set<String> = []
    var availableStartTime: Date?
    var availableEndTime: Date?
    var gamingTags: Set<String> = []
    var preferredRealms: Set<String> = []
    
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
