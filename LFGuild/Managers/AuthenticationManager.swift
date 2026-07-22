//
//  AuthenticationManager.swift
//  LFGuild
//
//  Created by George Suarez on 8/1/25.
//

import Foundation
import SwiftUI
import FirebaseAuth
import FirebaseFirestore

enum AuthenticationError: LocalizedError {
    case invalidEmail
    case weakPassword
    case networkError
    case invalidCredentials
    case wrongPassword
    case userNotFound
    case emailAlreadyExists
    case emailAlreadyInUse
    case userDisabled
    case tooManyRequests
    case invalidProfileData
    case anonymousSignInDisabled
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .invalidEmail:
            return "Please enter a valid email address"
        case .weakPassword:
            return "Password must be at least 8 characters long"
        case .networkError:
            return "Network connection failed. Please try again"
        case .invalidCredentials, .wrongPassword:
            return "Invalid email or password"
        case .userNotFound:
            return "No account found with this email"
        case .emailAlreadyExists, .emailAlreadyInUse:
            return "An account with this email already exists"
        case .userDisabled:
            return "This account has been disabled"
        case .tooManyRequests:
            return "Too many failed attempts. Please try again later"
        case .invalidProfileData:
            return "Please enter a valid name and country/region"
        case .anonymousSignInDisabled:
            return "Guest sign-in is not available"
        case .unknown(let message):
            return message
        }
    }

    static func from(_ error: Error) -> AuthenticationError {
        guard let authError = error as NSError? else {
            return .unknown(error.localizedDescription)
        }

        switch authError.code {
        case AuthErrorCode.invalidEmail.rawValue:
            return .invalidEmail
        case AuthErrorCode.weakPassword.rawValue:
            return .weakPassword
        case AuthErrorCode.wrongPassword.rawValue, AuthErrorCode.userNotFound.rawValue:
            return .wrongPassword
        case AuthErrorCode.emailAlreadyInUse.rawValue:
            return .emailAlreadyInUse
        case AuthErrorCode.userDisabled.rawValue:
            return .userDisabled
        case AuthErrorCode.tooManyRequests.rawValue:
            return .tooManyRequests
        default:
            return .unknown(authError.localizedDescription)
        }
    }
}

enum AuthenticationState: Equatable {
    case idle
    case loading
    case authenticated(UserModel)
    case unauthenticated

    static func == (lhs: AuthenticationState, rhs: AuthenticationState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.loading, .loading), (.unauthenticated, .unauthenticated):
            return true
        case (.authenticated(let lhsUser), .authenticated(let rhsUser)):
            return lhsUser.id == rhsUser.id
        default:
            return false
        }
    }
}

@MainActor
class AuthenticationManager: ObservableObject {
    @Published var authState: AuthenticationState = .idle
    @Published var currentUser: UserModel?
    @Published var lastError: AuthenticationError?
    @Published var isEmailVerified: Bool = false
    @Published var verificationEmailSent: Bool = false

    var isProfileComplete: Bool {
        guard let user = currentUser else { return false }
        return !user.roles.isEmpty || !user.availableDays.isEmpty || !user.gamingTags.isEmpty || !user.preferredRealms.isEmpty
    }

    /// Returns true only for signed-in email/password users who have verified their email address.
    /// Anonymous users and unverified email accounts cannot create guilds or submit applications.
    var isVerifiedEmailUser: Bool {
        guard let user = Auth.auth().currentUser else { return false }
        return !user.isAnonymous && user.isEmailVerified
    }

    private let db = Firestore.firestore()
    private var authStateListener: AuthStateDidChangeListenerHandle?

    /// Whether the app was launched via `fastlane snapshot` (UI testing for screenshots).
    /// Falls back to UserDefaults to survive edge cases where launch arguments
    /// aren't available during early initialization.
    static let screenshotModeDefaultsKey = "FASTLANE_SNAPSHOT"

    private static func enableScreenshotMode() {
        UserDefaults.standard.set(true, forKey: screenshotModeDefaultsKey)
    }

    private static var isScreenshotMode: Bool {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-UITesting") || args.contains("-FASTLANE_SNAPSHOT") {
            enableScreenshotMode()
            return true
        }
        if ProcessInfo.processInfo.environment["UITESTING"] == "1" {
            enableScreenshotMode()
            return true
        }
        return UserDefaults.standard.bool(forKey: screenshotModeDefaultsKey)
    }

    init() {
        if Self.isScreenshotMode {
            let mockUser = UserModel(
                firebaseUID: nil,
                name: "Demo User",
                email: "demo@example.com",
                countryRegion: "United States"
            )
            mockUser.roles = ["DPS", "Healer"]
            mockUser.availableDays = ["Monday", "Wednesday", "Friday"]
            mockUser.gamingTags = ["Mythic+ Focused", "Casual"]
            mockUser.preferredRealms = ["Stormrage - US", "Area-52 - US"]
            mockUser.availableStartTime = Date()
            mockUser.availableEndTime = Date().addingTimeInterval(4 * 60 * 60)

            currentUser = mockUser
            isEmailVerified = true
            authState = .authenticated(mockUser)
            return
        }
        setupAuthStateListener()
    }

    deinit {
        if let listener = authStateListener {
            Auth.auth().removeStateDidChangeListener(listener)
        }
    }

    func signIn(email: String, password: String) async throws {
        authState = .loading
        lastError = nil

        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            let user = try await fetchUserProfile(uid: result.user.uid, email: email)

            currentUser = user
            isEmailVerified = result.user.isEmailVerified
            verificationEmailSent = false
            authState = .authenticated(user)

            AnalyticsManager.shared.logUserSignedIn(userId: result.user.uid)
            AnalyticsManager.shared.setUserProperties(
                userId: result.user.uid,
                roles: Array(user.roles),
                realm: user.preferredRealms.first
            )

        } catch {
            let authError = AuthenticationError.from(error)
            lastError = authError
            authState = .unauthenticated
            throw authError
        }
    }

    func signOut() {
        if let userId = currentUser?.firebaseUID {
            AnalyticsManager.shared.logUserSignedOut(userId: userId)
        }

        do {
            try Auth.auth().signOut()
            currentUser = nil
            isEmailVerified = false
            verificationEmailSent = false
            authState = .unauthenticated
        } catch {
            // Best-effort sign out; rely on auth state listener to update UI.
        }
    }

    func register(name: String, email: String, password: String, countryRegion: String) async throws {
        authState = .loading

        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)

            let userModel = UserModel(
                firebaseUID: result.user.uid,
                name: name,
                email: email,
                countryRegion: countryRegion
            )

            try await createUserProfile(userModel)
            try await result.user.sendEmailVerification()

            currentUser = userModel
            isEmailVerified = false
            verificationEmailSent = true
            authState = .authenticated(userModel)

            AnalyticsManager.shared.logUserRegistered(userId: result.user.uid)
            AnalyticsManager.shared.setUserPropertyHasCompletedOnboarding(false)

        } catch {
            authState = .unauthenticated
            throw AuthenticationError.from(error)
        }
    }

    /// Anonymous sign-in is available only in DEBUG builds.
    func signInAnonymously() async throws {
        #if !DEBUG
        throw AuthenticationError.anonymousSignInDisabled
        #endif

        authState = .loading
        lastError = nil

        do {
            let result = try await Auth.auth().signInAnonymously()
            let uid = result.user.uid

            let userModel = UserModel(
                firebaseUID: uid,
                name: "Guest User",
                email: "",
                countryRegion: "United States"
            )

            do {
                try await createAnonymousProfile(userModel)
            } catch {
                // Continue even if profile creation fails; the account exists.
            }

            currentUser = userModel
            isEmailVerified = false
            verificationEmailSent = false
            authState = .authenticated(userModel)

        } catch {
            let authError = AuthenticationError.from(error)
            lastError = authError
            authState = .unauthenticated
            throw authError
        }
    }

    func resetPassword(email: String) async throws {
        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
        } catch {
            throw AuthenticationError.from(error)
        }
    }

    func sendEmailVerification() async throws {
        guard let user = Auth.auth().currentUser else {
            throw AuthenticationError.userNotFound
        }
        do {
            try await user.sendEmailVerification()
            verificationEmailSent = true
        } catch {
            throw AuthenticationError.from(error)
        }
    }

    /// Reloads the current Firebase user and updates the published verification state.
    func reloadEmailVerificationStatus() async throws {
        guard let user = Auth.auth().currentUser else {
            throw AuthenticationError.userNotFound
        }
        do {
            try await user.reload()
            isEmailVerified = user.isEmailVerified
            if isEmailVerified {
                verificationEmailSent = false
            }
        } catch {
            throw AuthenticationError.from(error)
        }
    }

    /// Updates the user's profile. Name is stored in the public profile; country/region is private.
    func updateProfile(name: String? = nil, countryRegion: String? = nil) async throws {
        guard let currentUser = currentUser,
              let firebaseUser = Auth.auth().currentUser else {
            throw AuthenticationError.userNotFound
        }

        let updatedUser = currentUser
        let uid = firebaseUser.uid

        if let name = name {
            let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedName.isEmpty, trimmedName.count <= 100 else {
                throw AuthenticationError.invalidProfileData
            }

            try await db.collection("publicProfiles").document(uid).setData([
                "name": trimmedName,
                "updatedAt": FieldValue.serverTimestamp()
            ], merge: true)

            updatedUser.name = trimmedName
        }

        if let countryRegion = countryRegion {
            let trimmedRegion = countryRegion.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedRegion.isEmpty, trimmedRegion.count <= 100 else {
                throw AuthenticationError.invalidProfileData
            }

            try await db.collection("users").document(uid).updateData([
                "countryRegion": trimmedRegion,
                "updatedAt": FieldValue.serverTimestamp()
            ])

            updatedUser.countryRegion = trimmedRegion
        }

        self.currentUser = updatedUser
    }

    func changePassword(currentPassword: String, newPassword: String) async throws {
        guard let firebaseUser = Auth.auth().currentUser,
              let email = firebaseUser.email else {
            throw AuthenticationError.userNotFound
        }

        let credential = EmailAuthProvider.credential(withEmail: email, password: currentPassword)
        try await firebaseUser.reauthenticate(with: credential)

        try await firebaseUser.updatePassword(to: newPassword)
    }

    func changeEmail(newEmail: String, password: String) async throws {
        guard let firebaseUser = Auth.auth().currentUser,
              let currentEmail = firebaseUser.email else {
            throw AuthenticationError.userNotFound
        }

        let credential = EmailAuthProvider.credential(withEmail: currentEmail, password: password)
        try await firebaseUser.reauthenticate(with: credential)

        try await firebaseUser.sendEmailVerification(beforeUpdatingEmail: newEmail)
    }

    func deleteAccount() async throws {
        guard let firebaseUser = Auth.auth().currentUser else {
            throw AuthenticationError.userNotFound
        }

        let userId = firebaseUser.uid

        // Best-effort cleanup of related Firestore data.
        // A Cloud Function should perform authoritative cleanup on Auth delete.
        try await cleanupUserData(userId: userId)

        try await firebaseUser.delete()

        currentUser = nil
        authState = .unauthenticated
    }

    private func cleanupUserData(userId: String) async throws {
        // 1. Delete pending applications submitted by the user.
        let applicationsSnapshot = try await db.collectionGroup("applications")
            .whereField("userId", isEqualTo: userId)
            .getDocuments()

        for doc in applicationsSnapshot.documents {
            try await doc.reference.delete()
        }

        // 2. Remove user from guild memberships and decrement member counts.
        let membershipsSnapshot = try await db.collectionGroup("members")
            .whereField("userId", isEqualTo: userId)
            .getDocuments()

        for doc in membershipsSnapshot.documents {
            guard let guildRef = doc.reference.parent.parent else { continue }
            _ = try await db.runTransaction { transaction, _ in
                transaction.deleteDocument(doc.reference)
                transaction.updateData([
                    "memberCount": FieldValue.increment(Int64(-1)),
                    "updatedAt": FieldValue.serverTimestamp()
                ], forDocument: guildRef)
                return nil
            }
        }

        // 3. Mark guilds led by the user as inactive so they stop appearing in search/matching.
        let ledGuildsSnapshot = try await db.collection("guilds")
            .whereField("leaderId", isEqualTo: userId)
            .getDocuments()

        for doc in ledGuildsSnapshot.documents {
            try await doc.reference.updateData([
                "isActive": false,
                "updatedAt": FieldValue.serverTimestamp()
            ])
        }

        // 4. Delete the user's private and public profile documents.
        try await db.collection("users").document(userId).delete()
        try await db.collection("publicProfiles").document(userId).delete()
    }

    private func setupAuthStateListener() {
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                guard let self = self else { return }

                // Don't interfere with manual sign-in flow
                if self.authState == .loading {
                    return
                }

                // Don't override if already authenticated with the same user
                if case .authenticated(let currentUser) = self.authState {
                    if let user = user, user.uid == currentUser.firebaseUID {
                        return
                    }
                }

                if let user = user {
                    do {
                        let userModel = try await self.fetchUserProfile(uid: user.uid, email: user.email ?? "")
                        self.currentUser = userModel
                        self.isEmailVerified = user.isEmailVerified
                        self.authState = .authenticated(userModel)
                    } catch {
                        self.authState = .unauthenticated
                    }
                } else {
                    self.currentUser = nil
                    self.isEmailVerified = false
                    self.verificationEmailSent = false
                    self.authState = .unauthenticated
                }
            }
        }
    }

    private func fetchUserProfile(uid: String, email: String) async throws -> UserModel {
        async let privateDoc = db.collection("users").document(uid).getDocument()
        async let publicDoc = db.collection("publicProfiles").document(uid).getDocument()

        let privateData = try await privateDoc.data() ?? [:]
        let publicData = try await publicDoc.data() ?? [:]

        // If neither document exists, create defaults for legacy/edge cases.
        if privateData.isEmpty && publicData.isEmpty {
            let defaultUser = UserModel(
                firebaseUID: uid,
                name: email.components(separatedBy: "@").first ?? "User",
                email: email,
                countryRegion: "United States"
            )
            try await createUserProfile(defaultUser)
            return defaultUser
        }

        // Prefer public profile for name/preferences; fall back to legacy private users data.
        let name = publicData["name"] as? String ?? privateData["name"] as? String ?? ""
        let countryRegion = privateData["countryRegion"] as? String ?? ""

        let user = UserModel(
            firebaseUID: uid,
            name: name,
            email: privateData["email"] as? String ?? email,
            countryRegion: countryRegion
        )

        // Load preferences from public profile (flattened), with legacy fallback to users/{uid}/preferences.
        let legacyPreferencesData = privateData["preferences"] as? [String: Any] ?? [:]

        if let rolesArray = publicData["roles"] as? [String] ?? legacyPreferencesData["roles"] as? [String] {
            user.roles = Set(rolesArray)
        }
        if let specializationsArray = publicData["specializations"] as? [String] ?? legacyPreferencesData["specializations"] as? [String] {
            user.specializations = Set(specializationsArray)
        }
        if let daysArray = publicData["availableDays"] as? [String] ?? legacyPreferencesData["availableDays"] as? [String] {
            user.availableDays = Set(daysArray)
        }
        if let tagsArray = publicData["gamingTags"] as? [String] ?? legacyPreferencesData["gamingTags"] as? [String] {
            user.gamingTags = Set(tagsArray)
        }
        if let realmsArray = publicData["preferredRealms"] as? [String] ?? legacyPreferencesData["preferredRealms"] as? [String] {
            user.preferredRealms = Set(realmsArray)
        }
        if let startTimeTimestamp = publicData["availableStartTime"] as? Timestamp ?? legacyPreferencesData["availableStartTime"] as? Timestamp {
            user.availableStartTime = startTimeTimestamp.dateValue()
        }
        if let endTimeTimestamp = publicData["availableEndTime"] as? Timestamp ?? legacyPreferencesData["availableEndTime"] as? Timestamp {
            user.availableEndTime = endTimeTimestamp.dateValue()
        }

        return user
    }

    private func createUserProfile(_ user: UserModel) async throws {
        let name = user.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let countryRegion = user.countryRegion.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !name.isEmpty, name.count <= 100,
              !countryRegion.isEmpty, countryRegion.count <= 100 else {
            throw AuthenticationError.invalidProfileData
        }

        guard let uid = user.firebaseUID else {
            throw AuthenticationError.userNotFound
        }

        let privateData: [String: Any] = [
            "email": user.email,
            "countryRegion": countryRegion,
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ]

        let publicData: [String: Any] = [
            "name": name,
            "updatedAt": FieldValue.serverTimestamp()
        ]

        try await db.collection("users").document(uid).setData(privateData)
        try await db.collection("publicProfiles").document(uid).setData(publicData)
    }

    /// Creates a minimal public profile for anonymous DEBUG users so they can browse the app.
    private func createAnonymousProfile(_ user: UserModel) async throws {
        let name = user.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.count <= 100 else {
            throw AuthenticationError.invalidProfileData
        }

        guard let uid = user.firebaseUID else {
            throw AuthenticationError.userNotFound
        }

        let publicData: [String: Any] = [
            "name": name,
            "updatedAt": FieldValue.serverTimestamp()
        ]

        try await db.collection("publicProfiles").document(uid).setData(publicData)
    }
}

extension String {
    /// A conservative RFC 5322-ish email validation suitable for client-side UX checks.
    var isValidEmail: Bool {
        let regex = "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        return range(of: regex, options: .regularExpression) != nil
    }
}
