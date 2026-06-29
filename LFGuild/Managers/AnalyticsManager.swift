//
//  AnalyticsManager.swift
//  LFGuild
//
//  Created by George Suarez on 8/10/25.
//

import Foundation
import FirebaseAnalytics

class AnalyticsManager {
    static let shared = AnalyticsManager()
    
    private init() {}
    
    // MARK: - User Events
    
    func logUserRegistered(userId: String) {
        Analytics.logEvent(AnalyticsEventSignUp, parameters: [
            AnalyticsParameterMethod: "email",
            "user_id": userId
        ])
    }
    
    func logUserSignedIn(userId: String) {
        Analytics.logEvent(AnalyticsEventLogin, parameters: [
            AnalyticsParameterMethod: "email",
            "user_id": userId
        ])
    }
    
    func logUserSignedOut(userId: String) {
        Analytics.logEvent("user_signed_out", parameters: [
            "user_id": userId
        ])
    }
    
    // MARK: - Guild Events
    
    func logGuildViewed(guildId: String, guildName: String, source: String) {
        Analytics.logEvent("guild_viewed", parameters: [
            "guild_id": guildId,
            "guild_name": guildName,
            "source": source
        ])
    }
    
    func logGuildSwipedRight(guildId: String, guildName: String, matchScore: Double) {
        Analytics.logEvent("guild_swiped_right", parameters: [
            "guild_id": guildId,
            "guild_name": guildName,
            "match_score": matchScore
        ])
    }
    
    func logGuildSwipedLeft(guildId: String, guildName: String, matchScore: Double) {
        Analytics.logEvent("guild_swiped_left", parameters: [
            "guild_id": guildId,
            "guild_name": guildName,
            "match_score": matchScore
        ])
    }
    
    func logGuildApplicationSubmitted(guildId: String, guildName: String) {
        Analytics.logEvent("guild_application_submitted", parameters: [
            "guild_id": guildId,
            "guild_name": guildName
        ])
    }
    
    func logGuildApplicationApproved(guildId: String, guildName: String, userId: String) {
        Analytics.logEvent("guild_application_approved", parameters: [
            "guild_id": guildId,
            "guild_name": guildName,
            "user_id": userId
        ])
    }
    
    func logGuildApplicationDeclined(guildId: String, guildName: String, userId: String) {
        Analytics.logEvent("guild_application_declined", parameters: [
            "guild_id": guildId,
            "guild_name": guildName,
            "user_id": userId
        ])
    }
    
    func logGuildCreated(guildId: String, guildName: String) {
        Analytics.logEvent("guild_created", parameters: [
            "guild_id": guildId,
            "guild_name": guildName
        ])
    }
    
    // MARK: - Message Events
    
    func logMessageSent(conversationId: String, recipientId: String) {
        Analytics.logEvent("message_sent", parameters: [
            "conversation_id": conversationId,
            "recipient_id": recipientId
        ])
    }
    
    func logConversationStarted(conversationId: String, otherUserId: String) {
        Analytics.logEvent("conversation_started", parameters: [
            "conversation_id": conversationId,
            "other_user_id": otherUserId
        ])
    }
    
    // MARK: - Preference Events
    
    func logPreferencesUpdated(hasRoles: Bool, hasDays: Bool, hasTags: Bool, hasRealms: Bool) {
        Analytics.logEvent("preferences_updated", parameters: [
            "has_roles": hasRoles,
            "has_days": hasDays,
            "has_tags": hasTags,
            "has_realms": hasRealms
        ])
    }
    
    func logOnboardingCompleted() {
        Analytics.logEvent("onboarding_completed", parameters: [:])
    }
    
    // MARK: - Search Events
    
    func logSearchPerformed(query: String, resultCount: Int) {
        Analytics.logEvent(AnalyticsEventSearch, parameters: [
            AnalyticsParameterSearchTerm: query,
            "result_count": resultCount
        ])
    }
    
    // MARK: - User Properties
    
    func setUserProperties(userId: String, roles: [String], realm: String?) {
        Analytics.setUserID(userId)
        Analytics.setUserProperty(roles.joined(separator: ","), forName: "user_roles")
        Analytics.setUserProperty(realm, forName: "preferred_realm")
    }
    
    func setUserPropertyHasCompletedOnboarding(_ completed: Bool) {
        Analytics.setUserProperty(completed ? "true" : "false", forName: "completed_onboarding")
    }
}
