# LFGuild — UI & Feature Improvement Checklist

UI and product-feature improvements for LFGuild. For production-readiness, security, backend, testing, and release concerns, see [`CHECKLIST.md`](./CHECKLIST.md).

References like `File.swift:NN` point to where the relevant code lives today.

---

## Guild Leader & Application Tools

Manager code exists for all of these — the UI is missing.

- [ ] Create Guild flow (leader onboarding) — `GuildManager.createGuild` (`Managers/GuildManager.swift:226`) is unused
- [ ] Edit Guild flow (description, tags, raid schedule, requirements, needed roles) — `updateGuild` (`GuildManager.swift:266`)
- [ ] Disband / Delete Guild flow — `deleteGuild` (`GuildManager.swift:279`)
- [ ] Applications inbox for leaders (approve / decline) — `respondToApplication` (`GuildManager.swift:339`) and `startListeningForApplications` (`GuildManager.swift:373`) wired but unused
- [ ] Member roster view (members beyond Battle.net officers)
- [ ] Remove / kick member flow
- [ ] Leave Guild flow for members

## Applicant Tools

- [ ] "My Applications" tracker showing pending / approved / declined status
- [ ] Withdraw a pending application
- [ ] Notification when an application is decided
- [ ] Re-apply after a cooldown (with messaging on when re-apply is allowed)

## Search & Discovery

- [x] Free-text search over Firestore-imported guilds by name / tag / keyword (`GuildSearchView` has no `TextField`)
- [x] Filter sheet: faction, region, member-count range, raid days, needed roles, tags
- [x] Sort controls (member count, newest, match score, name)
- [x] Pagination / "Load more" (search is hard-capped at 5 today — `GuildSearchView`)
- [x] Favorites / Saved guilds (persist + revisit)
- [x] Hide / "Not interested" to dismiss a guild from matches
- [x] Swipe gestures on match cards + wire `logGuildSwipedRight/Left` (`Managers/AnalyticsManager.swift:48`) — events defined, never called

## Matching Quality

- [x] Use ALL preferred realms (only `.first` is used — `GuildManager.swift:116`)
- [x] Incorporate specializations, time-of-day, and tags into the score
- [x] Match-score breakdown / "Why You Matched" UI in `CardDetailView`
- [x] Live "N matches with these preferences" preview in `PreferencesView`

## Messaging

- [ ] Message pagination (loads entire subcollection today — `MessagingManager.swift:58`)
- [ ] Day separators + relative timestamp formatting in `ChatView`
- [ ] Typing indicators
- [ ] Read receipts / delivery status (only `isRead` exists today)
- [ ] Edit / delete a sent message
- [ ] Conversation swipe-to-archive / mute / delete
- [ ] Block / report user from a conversation
- [ ] In-conversation search
- [ ] Fix recipient-by-name collision risk (names non-unique, `limit(to:1)` — `MessagingManager.swift:108`)
- [ ] Unread badge on the Messages tab icon in `HomeView` (`HomeView.swift:29`)
- [ ] Empty-thread state ("Say hi!" etc.)
- [ ] Fix `MessageError.invalidReceipient` typo (`Models/MessageModel.swift:55`)

## Profile & Identity

- [ ] Avatar / profile photo upload
- [ ] Bio / about field
- [ ] "Public profile preview — how others see me"
- [ ] Connected Battle.net character / armory link
- [ ] "My Guilds" and "My Applications" sections on profile
- [ ] Activity / history (guilds joined, last online)
- [ ] Stop leaking `Auth.auth().currentUser?.isAnonymous` into `ProfileView` (`ProfileView.swift:137`) — move to manager

## Settings (no dedicated screen today)

- [ ] Dedicated `SettingsView` (split from `ProfileView`)
- [ ] Notification preferences (per-category toggles)
- [ ] Appearance / theme toggle
- [ ] Language / locale
- [ ] Data & privacy controls (clear cache, download my data; move Delete Account here)
- [ ] About / version / legal / Terms of Service / privacy policy
- [ ] Contact support / feedback
- [ ] Sign-out confirmation alert (currently instant `signOut()` — `ProfileView.swift:102`)

## Notifications & Deep Links

- [ ] In-app notification inbox / list
- [ ] Complete guild deep-link routing — `navigateToGuild` sets `selectedGuildId` but `GuildSearchView` never calls `consumeGuildId()` (`Managers/NotificationRouter.swift`)
- [ ] FCM token refresh guard for pre-sign-in receipt (currently dropped — `AppDelegate.swift:84`)
- [ ] Badge count management
- [ ] Universal links / URL scheme (`onOpenURL` not handled in `LFGuildApp`); share guild / profile links
- [ ] Granular category subscriptions

## Onboarding & Preferences

- [ ] Skip / "Do this later" option in onboarding (`OnboardingView`)
- [ ] Unsaved-changes guard in `PreferencesView` on swipe-back
- [ ] "Reset to defaults" in `PreferencesView`
- [ ] Re-runnable onboarding entry point
- [ ] Realm picker with search (currently 23 hardcoded, no search — `WoWRealm`)
- [ ] Live realm list from Battle.net instead of hardcoded enum
- [ ] Wire `logOnboardingCompleted` / `logPreferencesUpdated` (`Managers/AnalyticsManager.swift`)
- [ ] Validate onboarding save behavior — `OnboardingView` uses `updateData` while `PreferencesView` uses `setData(merge:)`; align and test

## Theming & Visual Consistency

- [ ] Define `AccentColor.colorset` (currently empty — `Assets.xcassets/AccentColor.colorset`)
- [ ] Color tokens / `Color` extensions (replace raw `Color.blue/green/red/purple`)
- [ ] Reusable button styles (mix of `.borderedProminent` + custom blue rects today)
- [ ] Standardize corner radii (8/10/12/16/18 scattered across views)
- [ ] Unify `NavigationStack` — retire deprecated `NavigationView` (Registration, Onboarding, Preferences, Chat, MessageGuildLeader, NewMessage, CardDetail, GuildApplicationSheet)
- [ ] Merge `CustomFormField` (coupled to `RegistrationView.RegistrationField` — `CustomFormField.swift:14`) with `FormInputField`
- [ ] Stable identity for `CardItem` (regenerates `UUID()` each `init(from:)` → sheet re-init risk)
- [ ] Guild emblems / banners (no images today)
- [ ] User avatars beyond initials-in-circle
- [ ] Launch / boot animation; animated state transitions
- [ ] Empty-state illustrations, not just text

## Accessibility

- [ ] `.accessibilityLabel` / `.accessibilityHint` on icon-only buttons (send, compose, refresh, pickers)
- [ ] Labels on selection chips (roles / specs / tags are color-only today)
- [ ] Replace color-only encoding with icons/text (faction, role differentiation)
- [ ] Dynamic Type audit across all screens
- [ ] VoiceOver labels for match cards, conversation rows, send buttons
- [ ] Reduce-motion-friendly alternatives to scroll transitions
- [ ] Sufficient contrast checks on `.opacity(0.1)` tints

## Polish Affordances

- [ ] Haptics throughout (`sensoryFeedback` on send, apply, swipe, tab switch)
- [ ] Pull-to-refresh on Conversations, GuildSearch, Profile (only Home carousel has it)
- [ ] Consistent loading / empty / error states on every fetch path (`HomeView.refreshUserPreferences` silently swallows errors — `HomeView.swift:62`)
- [ ] Unsaved-changes guards (Preferences, Onboarding, ProfileEdit, NewMessage)
- [ ] Disabled affordance on "Request to Join" when guild is full / already applied (instead of post-tap error)
- [ ] Retry UI for transient network failures
- [ ] Keyboard avoidance + "Done" / toolbar accessories on all TextFields
- [ ] Offline mode / cache indicator

## Analytics Wiring

Events defined in `AnalyticsManager` but never invoked:

- [ ] `logGuildSwipedRight` / `logGuildSwipedLeft`
- [ ] `logOnboardingCompleted`
- [ ] `logPreferencesUpdated`
- [ ] `logGuildApplicationApproved` / `logGuildApplicationDeclined`
- [ ] `logGuildCreated`
- [ ] `logConversationStarted`
- [ ] `logSearchPerformed`