//
//  UserModel.swift
//  LFGuild
//
//  Created by George Suarez on 7/28/25.
//

import Foundation

class UserModel: Identifiable, ObservableObject {
    let id: UUID
    var name: String
    var email: String
    var countryRegion: String
    
    init(id: UUID = UUID(), name: String, email: String, countryRegion: String) {
        self.id = id
        self.name = name
        self.email = email
        self.countryRegion = countryRegion
    }
    
}
