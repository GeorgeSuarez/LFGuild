//
//  CardDataModel.swift
//  LFGuild
//
//  Created by George Suarez on 8/2/25.
//

import Foundation

struct CardItem: Identifiable, Hashable {
    let id = UUID()
    var imageURL: String
    var title: String
    var description: String
    let memberCount: Int
    let tags: [String]
    let requirements: String
    let leader: String
    let raidDays: [String]
    let raidTime: String
    let serverRealm: String
    
    init(imageURL: String, title: String, description: String, memberCount: Int, tags: [String], requirements: String, leader: String, raidDays: [String] = [], raidTime: String = "", serverRealm: String = "") {
        self.imageURL = imageURL
        self.title = title
        self.description = description
        self.memberCount = memberCount
        self.tags = tags
        self.requirements = requirements
        self.leader = leader
        self.raidDays = raidDays
        self.raidTime = raidTime
        self.serverRealm = serverRealm
    }
}


