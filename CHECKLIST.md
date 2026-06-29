## LFGuild Production-Readiness Checklist

1. Security & Privacy

   - Remove GoogleService-Info.plist from Git history — it is currently tracked despite being in .gitignore. Rotate the Firebase API key and any other exposed credentials immediately.
   - Split public vs. private user data — the comment in firestore.rules already flags this. Store email in a private subcollection or at least restrict read access.
   - Reconsider storing passwords in Keychain — KeychainManager stores raw passwords. Prefer relying on Firebase Auth’s secure token storage and delete credential persistence.
   - Add App Check / App Attestation to prevent abuse of Firebase Auth and Firestore endpoints.
   - Add input sanitization for guild names, descriptions, messages, and applications before persistence.
   - Add a privacy manifest (PrivacyInfo.xcprivacy) documenting collected data types (email, device token, analytics, crash reports).
   - Add terms of service and privacy policy URLs before App Store submission, especially because the app has user-to-user messaging.

2. Firebase Backend & Infrastructure

   - Deploy Cloud Functions for:
   - Sending FCM push notifications on new messages and guild applications.
   - Authoritative cleanup when a user deletes their account (the client-side cleanup in AuthenticationManager is best-effort only).
   - Server-side guild matching/scoring instead of fetching all guilds and filtering client-side.
   - Set up composite Firestore indexes for queries like guilds.where(isActive == true).orderBy(memberCount) and messages ordered by lastMessageTime.
   - Add Firestore Security Rules tests using the Firebase emulator to verify rules for users, guilds, applications, and messages.
   - Configure Firebase Remote Config for feature flags (e.g., enabling/disabling anonymous sign-in).
   - Set up separate Firebase projects for dev, staging, and production, with environment-specific GoogleService-Info.plist files selected by build configuration.
   - Add Firebase Storage rules if guild images are uploaded.

3. Architecture & Code Quality

   - Introduce dependency injection instead of singletons/shared managers everywhere (e.g., AnalyticsManager.shared, NotificationRouter.shared).
   - Convert UserModel to a Codable struct and stop passing mutable @Published model objects through the view hierarchy.
   - Move Firestore access out of views (HomeView, OnboardingView, PreferencesView all create Firestore.firestore() directly).
   - Replace most print() statements with a proper logging abstraction that can be disabled in release.
   - Remove debug “Guest” mode or gate it behind a debug build flag before production.
   - Unify navigation — the app mixes NavigationView and NavigationStack.
   - Consolidate hardcoded strings (realms, days, tags, roles) into a single source of truth.
   - Avoid try? silent failures in GuildManager, MessagingManager, and HomeView; surface recoverable errors to users.

4. Performance & Scalability

   - Paginate Firestore queries — fetchAllGuilds, fetchMatchingGuilds, and conversation listeners load everything into memory.
   - Move guild matching to the server or at least use Firestore composite queries; client-side scoring does not scale.
   - Add image caching and optimization — AsyncImage has no cache/placeholder strategy and may load large images.
   - Add lazy loading / pagination to the guild search results list.
   - Scope snapshot listeners and remove them aggressively to avoid unnecessary reads/billing.

5. Messaging
   - Implement server-side push notifications — the app registers for FCM and stores tokens, but nothing sends notifications.
   - Add message pagination in ChatView to avoid loading entire conversation histories.
   - Handle message send failures / retries and optimistic UI updates.
   - Add typing indicators, read receipts, and message timestamps formatting for production chat UX.
   - Add moderation/reporting/blocking capabilities for user-generated messages.

6. Error Handling & Reliability
   - Add a global error presentation mechanism instead of per-view alerts.
   - Add retry logic for transient network failures in authentication and Firestore calls.
   - Handle anonymous user edge cases — anonymous users can currently message and view guilds but cannot apply; verify this is intentional.
   - Add loading, empty, and error states consistently across all screens.
   - Validate onboarding save behavior — OnboardingView uses updateData while PreferencesView uses setData(merge:); align and test.

7. Testing
   - Write real UI tests — current LFGuildUITests is empty.
   - Add unit tests for managers (AuthenticationManager, GuildManager, MessagingManager) using mocked dependencies.
   - Add Firestore rules unit tests with the Firebase emulator.
   - Add performance tests for guild matching and chat loading.
   - Run tests in CI on every PR.

8. Build, CI/CD & Release
   - Set up Xcode Cloud, GitHub Actions, or another CI to build and test the app.
   - Add Fastlane for screenshots, beta distribution, and App Store submission.
   - Configure build configurations (Debug/Staging/Release) with separate bundle IDs and Firebase plists.
   - Remove .DS_Store from the repo and ensure it stays ignored.
   - Commit Package.resolved if it exists, or regenerate and pin dependency versions.
   - Add a build script to upload dSYMs to Firebase Crashlytics.
9. App Store & Compliance
   - Lower the deployment target from iOS 18.5 if possible, or justify the limited audience.
   - Add app icons, launch screen, and App Store screenshots.
   - Configure Sign in with Apple if required for apps with third-party login (Firebase Auth email/password may be exempt, but verify App Store guidelines).
   - Add accessibility labels and hints throughout the UI.
   - Localize copy if targeting multiple regions.
   - Add haptics, keyboard avoidance, and dark-mode polish.
   - Prepare App Review metadata including demo account credentials.

10. Analytics & Monitoring
    - Ensure Firebase Analytics and Crashlytics are enabled in the plist (IS_ANALYTICS_ENABLED is currently false).
    - Add custom key Crashlytics logs around critical user actions.
    - Add non-fatal error reporting for Firestore/network failures.
    - Add an analytics opt-out toggle for GDPR/CCPA compliance.
