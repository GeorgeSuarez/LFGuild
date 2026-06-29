//
//  NotificationRouter.swift
//  LFGuild
//
//  Created by George Suarez on 6/28/26.
//

import Foundation

enum HomeTab: Hashable {
    case home, messages, search, profile
}

/// Routes the user to specific screens when a push notification is tapped.
/// Used by `AppDelegate` (UIKit) and observed by SwiftUI views.
@MainActor
final class NotificationRouter: ObservableObject {
    static let shared = NotificationRouter()

    @Published private(set) var requestedTab: HomeTab?
    @Published private(set) var selectedConversationId: String?
    @Published private(set) var selectedGuildId: String?

    private init() {}

    func navigateToConversation(id: String) {
        requestedTab = .messages
        selectedConversationId = id
    }

    func navigateToGuild(id: String) {
        requestedTab = .search
        selectedGuildId = id
    }

    func consumeTabRequest() -> HomeTab? {
        let tab = requestedTab
        requestedTab = nil
        return tab
    }

    func consumeConversationId() -> String? {
        let id = selectedConversationId
        selectedConversationId = nil
        return id
    }

    func consumeGuildId() -> String? {
        let id = selectedGuildId
        selectedGuildId = nil
        return id
    }
}
