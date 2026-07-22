//
//  MatchingGuildsCarousel.swift
//  LFGuild
//
//  Created by George Suarez on 6/29/26.
//

import SwiftUI

struct MatchingGuildsCarousel: View {
    @EnvironmentObject private var authManager: AuthenticationManager
    @EnvironmentObject private var lists: UserGuildListsManager
    @StateObject private var guildManager = GuildManager()

    @State private var cards: [CardItem] = []
    @State private var favoriteCards: [CardItem] = []
    @State private var selectedCard: CardItem?
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let cardWidth: CGFloat = 300
    /// Horizontal distance a card must be dragged to trigger an action.
    private let swipeThreshold: CGFloat = 110

    /// Optional closure invoked before reloading cards, e.g. to refresh the user's profile.
    var onRefresh: (() async -> Void)?

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    if !favoriteCards.isEmpty {
                        savedGuildsStrip
                    }
                    header
                        .padding(.vertical, 12)
                    content
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(minWidth: geometry.size.width, minHeight: geometry.size.height)
            }
            .refreshable {
                await onRefresh?()
                await loadCards()
                await loadFavorites()
            }
            .task(id: authManager.currentUser?.firebaseUID) {
                await loadCards()
                await loadFavorites()
            }
            .onChange(of: lists.favoriteGuildIds) { _, _ in
                Task { await loadFavorites() }
            }
        }
    }

    // MARK: - Saved guilds strip

    private var savedGuildsStrip: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "heart.fill")
                    .foregroundStyle(.pink)
                Text("Saved Guilds")
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer()

                Text("\(favoriteCards.count)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(favoriteCards) { card in
                        SavedGuildCard(
                            card: card,
                            onTap: { selectedCard = card },
                            onUnsave: { Task { await lists.toggleFavorite(guildId: card.guildId ?? "") } }
                        )
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 4)
            }
        }
        .padding(.vertical, 12)
        .background(Color.pink.opacity(0.04))
    }

    private var header: some View {
        ZStack(alignment: .trailing) {
            VStack(alignment: .center, spacing: 4) {
                Text("Your Matches")
                    .font(.title3)
                    .fontWeight(.bold)

                if !cards.isEmpty {
                    Text("\(cards.count) match\(cards.count == 1 ? "" : "es") found")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)

            if isLoading {
                ProgressView()
            }
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private var content: some View {
        if isLoading && cards.isEmpty {
            loadingView
        } else if let errorMessage = errorMessage, cards.isEmpty {
            errorView(message: errorMessage)
        } else if cards.isEmpty {
            emptyView
        } else {
            carousel
        }
    }

    private var carousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 16) {
                ForEach(cards) { card in
                    SwipeableCard(
                        card: card,
                        swipeThreshold: swipeThreshold,
                        onTap: { selectedCard = card },
                        onSwipeRight: { handleSwipeRight(card) },
                        onSwipeLeft: { handleSwipeLeft(card) }
                    )
                    .frame(width: cardWidth)
                    .frame(maxHeight: .infinity)
                    .scrollTransition(.interactive, axis: .horizontal) { effect, phase in
                        effect
                            .scaleEffect(phase.isIdentity ? 1.0 : 0.92)
                            .opacity(phase.isIdentity ? 1.0 : 0.6)
                    }
                }
            }
            .frame(maxHeight: .infinity)
            .scrollTargetLayout()
        }
        .contentMargins(16, for: .scrollContent)
        .scrollTargetBehavior(.viewAligned)
        .sheet(item: $selectedCard) { card in
            CardDetailView(
                card: card,
                isPresented: Binding(
                    get: { selectedCard != nil },
                    set: { if !$0 { selectedCard = nil } }
                )
            )
            .environmentObject(authManager)
        }
    }

    private func handleSwipeRight(_ card: CardItem) {
        guard let guildId = card.guildId else { return }
        let willFavorite = !card.isFavorite
        Task {
            await lists.toggleFavorite(guildId: guildId)
            await MainActor.run {
                cards = cards.map { c in
                    var updated = c
                    if c.id == card.id { updated.isFavorite = willFavorite }
                    return updated
                }
            }
        }
        AnalyticsManager.shared.logGuildSwipedRight(
            guildId: guildId,
            guildName: card.title,
            matchScore: card.matchScore
        )
    }

    private func handleSwipeLeft(_ card: CardItem) {
        guard let guildId = card.guildId else { return }
        // Optimistically remove so the carousel advances to the next card.
        cards.removeAll { $0.id == card.id }
        Task { await lists.hideGuild(guildId: guildId) }
        AnalyticsManager.shared.logGuildSwipedLeft(
            guildId: guildId,
            guildName: card.title,
            matchScore: card.matchScore
        )
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Finding guilds for you...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass.circle")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("No Matching Guilds")
                .font(.headline)
                .fontWeight(.semibold)

            Text("Try adjusting your preferences or check back later for new guilds.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Refresh") {
                Task { await loadCards() }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundStyle(.orange)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Try Again") {
                Task { await loadCards() }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func loadCards() async {
        guard let user = authManager.currentUser else { return }

        if ProcessInfo.processInfo.arguments.contains("-UITesting") ||
           ProcessInfo.processInfo.arguments.contains("-FASTLANE_SNAPSHOT") {
            cards = Self.mockCards
            return
        }

        isLoading = true
        errorMessage = nil

        let hidden = lists.hiddenGuildIds
        let matchingGuilds = await guildManager.fetchMatchingGuilds(for: user, excludingHidden: hidden)

        isLoading = false

        if matchingGuilds.isEmpty, guildManager.error != nil {
            errorMessage = "Unable to load guilds. Please try again."
        } else {
            cards = matchingGuilds.map { CardItem(from: $0, isFavorite: lists.isFavorite($0.id)) }
        }
    }

    private static let mockCards: [CardItem] = [
        CardItem(
            title: "Midnight Reapers",
            description: "Hardcore mythic raiding guild looking for dedicated DPS and healers for our core roster. 8/8M current tier.",
            memberCount: 48,
            tags: ["Raiding", "Mythic+"],
            requirements: "3k IO, mythic raid experience",
            leader: "Shadowstrike",
            raidDays: ["Wednesday", "Thursday"],
            raidTime: "8:00 PM - 11:00 PM",
            serverRealm: "Stormrage - US",
            matchScore: 0.92,
            isFavorite: false
        ),
        CardItem(
            title: "Dawnbringers",
            description: "Casual-friendly guild with a focus on heroic raiding and mythic+. New and returning players welcome!",
            memberCount: 35,
            tags: ["Casual", "Raiding", "Social"],
            requirements: "Be chill, have fun",
            leader: "Luminara",
            raidDays: ["Friday", "Saturday"],
            raidTime: "7:00 PM - 10:00 PM",
            serverRealm: "Area-52 - US",
            matchScore: 0.88,
            isFavorite: true
        ),
        CardItem(
            title: "Frostmourne Hunters",
            description: "Weekend raiding guild on a tight schedule. Currently building our heroic roster for the new tier.",
            memberCount: 22,
            tags: ["Raiding", "Weekend"],
            requirements: "Heroic dungeon gear",
            leader: "Arthas",
            raidDays: ["Saturday", "Sunday"],
            raidTime: "3:00 PM - 6:00 PM",
            serverRealm: "Illidan - US",
            matchScore: 0.75,
            isFavorite: false
        ),
        CardItem(
            title: "The Unbroken",
            description: "PvP-focused guild grinding rated battlegrounds and arena. Push rating with a coordinated team.",
            memberCount: 18,
            tags: ["PvP", "Competitive"],
            requirements: "1.8k+ rating in any bracket",
            leader: "Warmaster",
            raidDays: ["Tuesday", "Thursday"],
            raidTime: "9:00 PM - 12:00 AM",
            serverRealm: "Tichondrius - US",
            matchScore: 0.71,
            isFavorite: false
        ),
    ]

    private func loadFavorites() async {
        let ids = Array(lists.favoriteGuildIds)
        guard !ids.isEmpty else {
            await MainActor.run { favoriteCards = [] }
            return
        }
        let guilds = await guildManager.fetchGuilds(byIds: ids)
        await MainActor.run {
            favoriteCards = guilds
                .filter { $0.isActive }
                .sorted { $0.matchScore > $1.matchScore }
                .map { CardItem(from: $0, isFavorite: true) }
        }
    }
}

// MARK: - Saved guild card (compact strip card)

private struct SavedGuildCard: View {
    let card: CardItem
    let onTap: () -> Void
    let onUnsave: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(card.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                Spacer()
                Button {
                    onUnsave()
                } label: {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(.pink)
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Unsave \(card.title)")
            }

            if card.matchScore > 0 {
                Text("\(Int(card.matchScore * 100))% match")
                    .font(.caption2)
                    .foregroundStyle(.green)
            }

            HStack(spacing: 4) {
                Image(systemName: "person.2.fill")
                    .font(.caption2)
                Text("\(card.memberCount)")
                    .font(.caption2)
            }
            .foregroundStyle(.secondary)

            Text(card.serverRealm)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(10)
        .frame(width: 140, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(.rect(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.pink.opacity(0.2), lineWidth: 1)
        )
        .onTapGesture { onTap() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Saved guild \(card.title). \(card.memberCount) members on \(card.serverRealm).")
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Swipeable card wrapper

private struct SwipeableCard: View {
    let card: CardItem
    let swipeThreshold: CGFloat
    let onTap: () -> Void
    let onSwipeRight: () -> Void
    let onSwipeLeft: () -> Void

    @State private var offset: CGFloat = 0

    var body: some View {
        CardView(card: card, onTap: onTapCall)
            .overlay(alignment: .leading) {
                swipeHint("heart.fill", color: .pink, opacity: swipeRightProgress)
            }
            .overlay(alignment: .trailing) {
                swipeHint("hand.thumbsdown.fill", color: .red, opacity: swipeLeftProgress)
            }
            .offset(x: offset)
            .rotationEffect(.degrees(offset / 30))
            .simultaneousGesture(
                DragGesture(minimumDistance: 8)
                    .onChanged { value in
                        offset = value.translation.width
                    }
                    .onEnded { value in
                        let width = value.translation.width
                        if width > swipeThreshold {
                            onSwipeRight()
                        } else if width < -swipeThreshold {
                            onSwipeLeft()
                        }
                        withAnimation(.spring) { offset = 0 }
                    }
            )
            .accessibilityAction(named: "Save") { onSwipeRight() }
            .accessibilityAction(named: "Not Interested") { onSwipeLeft() }
    }

    private func onTapCall() { onTap() }

    private var swipeRightProgress: Double {
        guard offset > 0 else { return 0 }
        return min(1.0, Double(offset / swipeThreshold))
    }

    private var swipeLeftProgress: Double {
        guard offset < 0 else { return 0 }
        return min(1.0, Double(-offset / swipeThreshold))
    }

    @ViewBuilder
    private func swipeHint(_ symbol: String, color: Color, opacity: Double) -> some View {
        if opacity > 0 {
            Image(systemName: symbol)
                .font(.system(size: 44))
                .foregroundStyle(color)
                .opacity(opacity)
                .padding()
        }
    }
}

#Preview {
    MatchingGuildsCarousel()
        .environmentObject(AuthenticationManager())
        .environmentObject(UserGuildListsManager.shared)
}
