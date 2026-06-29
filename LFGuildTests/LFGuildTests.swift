//
//  LFGuildTests.swift
//  LFGuildTests
//
//  Created by George Suarez on 7/28/25.
//

import Testing
import Foundation
@testable import LFGuild

// MARK: - Authentication Error Tests

struct AuthenticationErrorTests {
    
    @Test func testInvalidEmailError() {
        let error = AuthenticationError.invalidEmail
        #expect(error.errorDescription == "Please enter a valid email address")
    }
    
    @Test func testWeakPasswordError() {
        let error = AuthenticationError.weakPassword
        #expect(error.errorDescription == "Password must be at least 8 characters long")
    }
    
    @Test func testUnknownError() {
        let error = AuthenticationError.unknown("Something went wrong")
        #expect(error.errorDescription == "Something went wrong")
    }
    
    @Test func testNetworkError() {
        let error = AuthenticationError.networkError
        #expect(error.errorDescription == "Network connection failed. Please try again")
    }
    
    @Test func testEmailAlreadyInUse() {
        let error = AuthenticationError.emailAlreadyInUse
        #expect(error.errorDescription == "An account with this email already exists")
    }

    @Test func testInvalidProfileDataError() {
        let error = AuthenticationError.invalidProfileData
        #expect(error.errorDescription == "Please enter a valid name and country/region")
    }

    @Test func testValidEmail() {
        #expect("user@example.com".isValidEmail == true)
        #expect("name+tag@domain.co.uk".isValidEmail == true)
    }

    @Test func testInvalidEmail() {
        #expect("notanemail".isValidEmail == false)
        #expect("@nodomain".isValidEmail == false)
        #expect("missing@tld".isValidEmail == false)
        #expect("".isValidEmail == false)
    }
}

// MARK: - User Model Tests

struct UserModelTests {
    
    @Test func testUserModelInitialization() {
        let user = UserModel(name: "Test User", email: "test@example.com", countryRegion: "United States")
        #expect(user.name == "Test User")
        #expect(user.email == "test@example.com")
        #expect(user.countryRegion == "United States")
        #expect(user.firebaseUID == nil)
    }
    
    @Test func testUserModelEquality() {
        let user1 = UserModel(id: UUID(), name: "Test", email: "test@example.com", countryRegion: "US")
        let user2 = UserModel(id: user1.id, name: "Different", email: "different@example.com", countryRegion: "UK")
        #expect(user1 == user2)
    }
    
    @Test func testUserModelInequality() {
        let user1 = UserModel(name: "Test1", email: "test1@example.com", countryRegion: "US")
        let user2 = UserModel(name: "Test2", email: "test2@example.com", countryRegion: "UK")
        #expect(user1 != user2)
    }
    
    @Test func testUserModelPreferences() {
        let user = UserModel(name: "Test", email: "test@example.com", countryRegion: "US")
        user.roles = ["DPS", "Healer"]
        user.availableDays = ["Monday", "Tuesday"]
        user.gamingTags = ["Hardcore"]
        user.preferredRealms = ["Stormrage - US"]
        
        #expect(user.roles.count == 2)
        #expect(user.availableDays.count == 2)
        #expect(user.gamingTags.count == 1)
        #expect(user.preferredRealms.count == 1)
    }
}

// MARK: - Guild Model Tests

struct GuildModelTests {
    
    @Test func testGuildModelInitialization() {
        let guild = GuildModel(
            name: "Test Guild",
            description: "A test guild",
            leaderId: "user123",
            leaderName: "TestLeader",
            memberCount: 10,
            maxMembers: 50,
            serverRealm: "Stormrage - US"
        )
        
        #expect(guild.name == "Test Guild")
        #expect(guild.memberCount == 10)
        #expect(guild.maxMembers == 50)
        #expect(guild.isFull == false)
    }
    
    @Test func testGuildIsFull() {
        let guild = GuildModel(
            name: "Full Guild",
            description: "A full guild",
            leaderId: "user123",
            leaderName: "Leader",
            memberCount: 50,
            maxMembers: 50,
            serverRealm: "Stormrage - US"
        )
        
        #expect(guild.isFull == true)
    }
    
    @Test func testGuildRaidTimeDisplay() {
        let guild = GuildModel(
            name: "Test Guild",
            description: "Test",
            leaderId: "user123",
            leaderName: "Leader",
            raidStartTime: "8:00 PM",
            raidEndTime: "11:00 PM",
            serverRealm: "Stormrage - US"
        )
        
        #expect(guild.raidTimeDisplay == "8:00 PM - 11:00 PM")
    }
    
    @Test func testGuildRaidTimeDisplayNotSet() {
        let guild = GuildModel(
            name: "Test Guild",
            description: "Test",
            leaderId: "user123",
            leaderName: "Leader",
            serverRealm: "Stormrage - US"
        )
        
        #expect(guild.raidTimeDisplay == "Not set")
    }
    
    @Test func testGuildApplicationStatus() {
        let app = GuildApplication(
            userId: "user123",
            userName: "TestUser",
            message: "Hello",
            status: .pending
        )
        
        #expect(app.status == .pending)
    }
    
    @Test func testGuildMemberStatus() {
        let member = GuildMember(
            id: "user123",
            userId: "user123",
            name: "TestUser",
            role: "Member",
            joinDate: Date(),
            status: .active
        )
        
        #expect(member.status == .active)
    }
}

// MARK: - Card Item Tests

struct CardItemTests {
    
    @Test func testCardItemFromGuildModel() {
        let guild = GuildModel(
            id: "guild123",
            name: "Test Guild",
            description: "A test guild",
            leaderId: "user123",
            leaderName: "TestLeader",
            memberCount: 25,
            tags: ["Raid", "Hardcore"],
            requirements: "Level 60",
            raidDays: ["Tuesday", "Thursday"],
            raidStartTime: "8:00 PM",
            raidEndTime: "11:00 PM",
            serverRealm: "Stormrage - US",
            matchScore: 0.85
        )
        
        let card = CardItem(from: guild)
        
        #expect(card.title == "Test Guild")
        #expect(card.memberCount == 25)
        #expect(card.guildId == "guild123")
        #expect(card.matchScore == 0.85)
        #expect(card.leader == "TestLeader")
    }
    
    @Test func testCardItemDefaultMatchScore() {
        let card = CardItem(
            title: "Test",
            description: "Test",
            memberCount: 10,
            tags: [],
            requirements: "",
            leader: "Leader"
        )

        #expect(card.matchScore == 0)
    }
}

// MARK: - Keychain Manager Tests

struct KeychainManagerTests {

    private func makeManager() -> KeychainManager {
        // Each test gets its own keychain service namespace so parallel tests
        // cannot interfere with one another.
        KeychainManager(service: "LFGuild-\(UUID().uuidString)")
    }

    @Test func testStoreAndRetrieveEmail() throws {
        let manager = makeManager()
        let testEmail = "test@example.com"

        try manager.store(email: testEmail)

        let storedEmail = manager.getEmail()
        #expect(storedEmail == testEmail)

        manager.deleteEmail()
    }

    @Test func testDeleteEmail() throws {
        let manager = makeManager()

        try manager.store(email: "test@example.com")
        manager.deleteEmail()

        let storedEmail = manager.getEmail()
        #expect(storedEmail == nil)
    }

    @Test func testGetEmailWhenEmpty() {
        let manager = makeManager()

        let storedEmail = manager.getEmail()
        #expect(storedEmail == nil)
    }

    @Test func testStoreUpdatesDuplicateEmail() throws {
        let manager = makeManager()

        try manager.store(email: "first@example.com")
        try manager.store(email: "second@example.com")

        let storedEmail = manager.getEmail()
        #expect(storedEmail == "second@example.com")

        manager.deleteEmail()
    }
}

// MARK: - Authentication State Tests

struct AuthenticationStateTests {
    
    @Test func testIdleStateEquality() {
        let state1: AuthenticationState = .idle
        let state2: AuthenticationState = .idle
        #expect(state1 == state2)
    }
    
    @Test func testLoadingStateEquality() {
        let state1: AuthenticationState = .loading
        let state2: AuthenticationState = .loading
        #expect(state1 == state2)
    }
    
    @Test func testUnauthenticatedStateEquality() {
        let state1: AuthenticationState = .unauthenticated
        let state2: AuthenticationState = .unauthenticated
        #expect(state1 == state2)
    }
    
    @Test func testAuthenticatedStateEquality() {
        let user = UserModel(name: "Test", email: "test@example.com", countryRegion: "US")
        let state1: AuthenticationState = .authenticated(user)
        let state2: AuthenticationState = .authenticated(user)
        #expect(state1 == state2)
    }
    
    @Test func testAuthenticatedStateInequality() {
        let user1 = UserModel(name: "Test1", email: "test1@example.com", countryRegion: "US")
        let user2 = UserModel(name: "Test2", email: "test2@example.com", countryRegion: "US")
        let state1: AuthenticationState = .authenticated(user1)
        let state2: AuthenticationState = .authenticated(user2)
        #expect(state1 != state2)
    }
    
    @Test func testDifferentStateInequality() {
        let state1: AuthenticationState = .idle
        let state2: AuthenticationState = .loading
        #expect(state1 != state2)
    }
}

// MARK: - Message Model Tests

struct MessageModelTests {
    
    @Test func testMessageInitialization() {
        let message = Message(
            senderId: "user1",
            senderName: "Alice",
            recipientName: "Bob",
            recipientId: "user2",
            content: "Hello!"
        )
        
        #expect(message.senderId == "user1")
        #expect(message.recipientId == "user2")
        #expect(message.content == "Hello!")
        #expect(message.isRead == false)
    }
    
    @Test func testConversationLastMessageTime() {
        let message = Message(
            senderId: "user1",
            senderName: "Alice",
            recipientName: "Bob",
            recipientId: "user2",
            content: "Hello!"
        )
        
        let conversation = Conversation(
            id: "conv1",
            participantId: "user2",
            participantName: "Bob",
            lastMessage: message,
            unreadCount: 0
        )
        
        #expect(conversation.lastMessageTime == message.timestamp)
    }
    
    @Test func testConversationLastMessageTimeWithNoMessage() {
        let conversation = Conversation(
            id: "conv1",
            participantId: "user2",
            participantName: "Bob",
            lastMessage: nil,
            unreadCount: 0
        )
        
        #expect(conversation.lastMessageTime == Date.distantPast)
    }
}

// MARK: - Preference Enums Tests

struct PreferenceEnumsTests {
    
    @Test func testRoleRawValues() {
        #expect(Role.dps.rawValue == "DPS")
        #expect(Role.healer.rawValue == "Healer")
        #expect(Role.tank.rawValue == "Tank")
    }
    
    @Test func testDayRawValues() {
        #expect(Day.monday.rawValue == "Monday")
        #expect(Day.sunday.rawValue == "Sunday")
    }
    
    @Test func testTagRawValues() {
        #expect(Tag.hardcore.rawValue == "Hardcore")
        #expect(Tag.casual.rawValue == "Casual")
    }
    
    @Test func testWoWRealmName() {
        let realm = WoWRealm.stormrage
        #expect(realm.name == "Stormrage")
        #expect(realm.region == "US")
    }
    
    @Test func testWoWRealmEU() {
        let realm = WoWRealm.ragnaros
        #expect(realm.region == "EU")
    }
}

// MARK: - Analytics Manager Tests

struct AnalyticsManagerTests {
    
    @Test func testAnalyticsManagerSingleton() {
        let instance1 = AnalyticsManager.shared
        let instance2 = AnalyticsManager.shared
        #expect(instance1 === instance2)
    }
}

// MARK: - Guild Error Tests

struct GuildErrorTests {
    
    @Test func testGuildNotFoundError() {
        let error = GuildError.notFound
        #expect(error.localizedDescription == "Guild not found")
    }
    
    @Test func testGuildFullError() {
        let error = GuildError.guildFull
        #expect(error.localizedDescription == "This guild is currently full")
    }
    
    @Test func testAlreadyMemberError() {
        let error = GuildError.alreadyMember
        #expect(error.localizedDescription == "You are already a member of this guild")
    }
    
    @Test func testAlreadyAppliedError() {
        let error = GuildError.alreadyApplied
        #expect(error.localizedDescription == "You have already applied to this guild")
    }
    
    @Test func testUnauthorizedError() {
        let error = GuildError.unauthorized
        #expect(error.localizedDescription == "You are not authorized to perform this action")
    }

    @Test func testEmailNotVerifiedError() {
        let error = GuildError.emailNotVerified
        #expect(error.localizedDescription == "Please verify your email address before applying to a guild")
    }
}

// MARK: - Profile View Model Tests

@MainActor
struct ProfileViewModelTests {
    
    @Test func testHasChanges() {
        let viewModel = ProfileViewModel()
        let user = UserModel(name: "New Name", email: "test@example.com", countryRegion: "United States")
        
        viewModel.loadUserData(from: user)
        
        #expect(viewModel.hasChanges == false)
        
        viewModel.name = "Different Name"
        #expect(viewModel.hasChanges == true)
    }
    
    @Test func testDiscardChanges() {
        let viewModel = ProfileViewModel()
        let user = UserModel(name: "Original", email: "test@example.com", countryRegion: "US")
        
        viewModel.loadUserData(from: user)
        viewModel.name = "Changed"
        
        #expect(viewModel.hasChanges == true)
        
        viewModel.discardChanges()
        
        #expect(viewModel.name == "Original")
        #expect(viewModel.hasChanges == false)
    }
}

// MARK: - Change Password View Model Tests

@MainActor
struct ChangePasswordViewModelTests {
    
    @Test func testFormValid() {
        let viewModel = ChangePasswordViewModel()
        viewModel.currentPassword = "oldpass123"
        viewModel.newPassword = "newpass123"
        viewModel.confirmPassword = "newpass123"
        
        #expect(viewModel.isFormValid == true)
    }
    
    @Test func testFormInvalidShortPassword() {
        let viewModel = ChangePasswordViewModel()
        viewModel.currentPassword = "oldpass123"
        viewModel.newPassword = "short"
        viewModel.confirmPassword = "short"
        
        #expect(viewModel.isFormValid == false)
    }
    
    @Test func testFormInvalidMismatch() {
        let viewModel = ChangePasswordViewModel()
        viewModel.currentPassword = "oldpass123"
        viewModel.newPassword = "newpass123"
        viewModel.confirmPassword = "different123"
        
        #expect(viewModel.isFormValid == false)
    }
    
    @Test func testFormInvalidEmptyFields() {
        let viewModel = ChangePasswordViewModel()
        #expect(viewModel.isFormValid == false)
    }
}

// MARK: - Change Email View Model Tests

@MainActor
struct ChangeEmailViewModelTests {
    
    @Test func testFormValid() {
        let viewModel = ChangeEmailViewModel()
        viewModel.newEmail = "new@example.com"
        viewModel.password = "password123"
        
        #expect(viewModel.isFormValid == true)
    }
    
    @Test func testFormInvalidNoEmail() {
        let viewModel = ChangeEmailViewModel()
        viewModel.newEmail = ""
        viewModel.password = "password123"
        
        #expect(viewModel.isFormValid == false)
    }
    
    @Test func testFormInvalidInvalidEmail() {
        let viewModel = ChangeEmailViewModel()
        viewModel.newEmail = "invalid"
        viewModel.password = "password123"
        
        #expect(viewModel.isFormValid == false)
    }
    
    @Test func testFormInvalidNoPassword() {
        let viewModel = ChangeEmailViewModel()
        viewModel.newEmail = "new@example.com"
        viewModel.password = ""
        
        #expect(viewModel.isFormValid == false)
    }
}
