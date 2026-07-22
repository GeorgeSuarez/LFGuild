# LFGuild

<p align="center">
  <img src="fastlane/screenshots/en-US/iPhone-17-Pro-01Home.png" width="200" alt="Home" />
  <img src="fastlane/screenshots/en-US/iPhone-17-Pro-02Search.png" width="200" alt="Search" />
  <img src="fastlane/screenshots/en-US/iPhone-17-Pro-03Messages.png" width="200" alt="Messages" />
  <img src="fastlane/screenshots/en-US/iPhone-17-Pro-04Profile.png" width="200" alt="Profile" />
</p>

<p align="center">
  <em>Home &middot; Search &middot; Messages &middot; Profile</em>
</p>

LFGuild ("Looking-For-Guild") is an iOS app that helps **World of Warcraft** players find and join guilds that fit their playstyle, schedule, role, and realm. It pairs a Tinder-style swipe-to-match carousel with traditional guild search, in-app messaging, and live Battle.net guild-data enrichment.

> Built with SwiftUI + Firebase, targeting players across US, OCE, and EU realms.

## Features

### Matching

- A swipeable card carousel (`MatchingGuildsCarousel`) surfaces guilds scored against the user's preferences.
- `MatchScorer` computes a normalized **0–1 score** as a weighted sum of six factors:

  | Factor         | Weight | Notes                                         |
  | -------------- | ------ | --------------------------------------------- |
  | Realm          | 0.30   | Match against preferred realms                |
  | Role           | 0.20   | Fraction of needed roles the user can fill    |
  | Specialization | 0.10   | Class/spec → role coverage                    |
  | Raid days      | 0.20   | Overlap of availability with guild raid days  |
  | Time of day    | 0.10   | Minute-overlap of availability vs raid window |
  | Tags           | 0.10   | Shared playstyle tags                         |

- A **"Why You Matched"** breakdown explains each score in `CardDetailView`.
- Users can favorite or hide guilds; saved guilds appear in a horizontal strip on the Home tab.

### Onboarding & Preferences

- A six-step onboarding (Welcome → Roles → Specializations → Availability → Tags → Realms) runs for first-time users and writes to `publicProfiles/{uid}`.
- `PreferencesView` lets users edit preferences later and shows a live, debounced **Match preview** count.

### Guild Discovery & Search

- **LFGuild (Firestore) search:** keyword + `GuildSearchFilters` (factions, regions, member-count range, raid days, needed roles, tags) with sort options and cursor-based pagination.
- **Battle.net search:** a curated `BattleNetGuildCatalog` compensates for the lack of a Blizzard guild-search endpoint, importing real guild profiles and rosters on demand (`BattleNetGuildDetailView`).
- `GuildDiscoveryManager` auto-imports curated popular guilds into Firestore (24h throttle) so new users have real content to match against.

### Messaging

- Real-time conversations and messages via Firestore listeners.
- Deterministic conversation IDs (sorted UIDs), per-user unread counts, read receipts, and 2000-char message cap.
- `NewMessageView` starts conversations by recipient name lookup in `publicProfiles`.

### Authentication

- Email/password sign-up with **mandatory email verification** before guild creation or applications.
- Password reset, password change (with reauth), email change (with verification), and account deletion with best-effort Firestore cleanup.
- Anonymous sign-in is gated to DEBUG builds only.

### Notifications & Analytics

- FCM/APNs push tokens are registered and stored on `users/{uid}`.
- `NotificationRouter` deep-links incoming pushes to the Messages or Search tab.
- `AnalyticsManager` tracks sign-up/in/out, guild views and swipes (with match score), applications, messages, searches, and onboarding completion; user properties include roles, preferred realm, and onboarding status.

## Tech Stack

- **SwiftUI** (iOS) — `@main App` + `UIApplicationDelegateAdaptor`
- **Firebase** — Auth, Cloud Firestore, Cloud Messaging (FCM), Analytics, App Check
- **Battle.net WoW Profile & Data APIs** — client-credentials OAuth via `BattleNetAPIClient` (actor), credentials injected through `BattleNetSecrets.xcconfig` → Info.plist

## Architecture

An MVVM-style layout:

```
LFGuild/
├── LFGuildApp.swift          # Firebase + App Check setup, NotificationRouter injection
├── AppDelegate.swift         # APNs / FCM token registration & handling
├── Views/                    # SwiftUI screens (auth, home, carousel, search, chat, profile)
├── ViewModels/               # ProfileViewModel, ChangePasswordViewModel, ChangeEmailViewModel
├── Managers/                 # Auth, Guild, Messaging, BattleNet, Analytics, Discovery, etc.
└── Models/                   # Guild, User, Message, MatchScorer, PreferenceEnums, DTOs
```

`@MainActor` `ObservableObject` managers (`AuthenticationManager`, `GuildManager`, `MessagingManager`) are injected as `@StateObject`/`@EnvironmentObject` and back the views.

## Firestore Data Model

```
users/{uid}                           # private (owner-only): email, countryRegion, fcmToken
  favorites/{guildId}                 # saved guild IDs
  hiddenGuilds/{guildId}              # dismissed guild IDs
publicProfiles/{uid}                  # public: name, roles[], specs[], availability, tags, realms[]
guilds/{guildId}                      # guild details, Battle.net enrichment, neededRoles, raidDays
  members/{memberId}                 # active members
  applications/{applicationId}        # pending / approved / declined join applications
messages/{conversationId}             # 2 participants, lastMessage, unreadCount
  messages/{messageId}                # senderId, content (≤2000), timestamp, isRead
```

Security rules enforce verified-email requirements for guild creation and applications, leader-only guild mutations, participant-only message access, and reject guild documents containing an `imageURL` (guild images are not currently supported).

## Game Concepts

Defined in `Models/PreferenceEnums.swift`:

- **Roles** — `DPS` (red), `Healer` (green), `Tank` (blue)
- **Specializations** — the full WoW class/spec matrix across 13 classes, each mapping to a `Role`
- **Days** — Monday through Sunday
- **Tags** (playstyle) — `Hardcore`, `Casual`, `Mythic+ Focused`, `Raid Focused`, `PvP`, `RP`
- **Realms** — 23 curated realms spanning US, EU, and OCE regions

## Getting Started

1. Clone the repository.
2. Create a Firebase project and download `GoogleService-Info.plist` into `LFGuild/` (see `GoogleService-Info.plist.example`).
3. Provide Battle.net credentials via `BattleNetSecrets.xcconfig` (referenced by the project's Info.plist keys `BNET_CLIENT_ID` / `BNET_CLIENT_SECRET`).
4. Deploy Firestore rules: `firebase deploy --only firestore:rules`.
5. Open `LFGuild.xcodeproj` in Xcode and run on an iOS 18.5+ simulator or device.

## Project Status

LFGuild is under active development. See [`CHECKLIST.md`](CHECKLIST.md) for the production-readiness roadmap (security, Cloud Functions, pagination, server-side scoring, tests, CI/CD, App Store compliance) and [`UI_IMPROVEMENTS.md`](UI_IMPROVEMENTS.md) for design notes.
