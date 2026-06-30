//
//  MatchingGuildsCarousel.swift
//  LFGuild
//
//  Created by George Suarez on 6/29/26.
//

import SwiftUI

struct MatchingGuildsCarousel: View {
    @EnvironmentObject private var authManager: AuthenticationManager
    @StateObject private var guildManager = GuildManager()

    @State private var cards: [CardItem] = []
    @State private var selectedCard: CardItem?
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let cardWidth: CGFloat = 300
    private let cardHeight: CGFloat = 380

    /// Optional closure invoked before reloading cards, e.g. to refresh the user's profile.
    var onRefresh: (() async -> Void)?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                header
                content
            }
        }
        .refreshable {
            await onRefresh?()
            await loadCards()
        }
        .task(id: authManager.currentUser?.firebaseUID) {
            await loadCards()
        }
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
                    CardView(card: card) {
                        selectedCard = card
                    }
                    .frame(width: cardWidth, height: cardHeight)
                    .scrollTransition(.interactive, axis: .horizontal) { effect, phase in
                        effect
                            .scaleEffect(phase.isIdentity ? 1.0 : 0.92)
                            .opacity(phase.isIdentity ? 1.0 : 0.6)
                    }
                }
            }
            .scrollTargetLayout()
        }
        .contentMargins(.horizontal, 16, for: .scrollContent)
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

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Finding guilds for you...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(height: cardHeight)
        .frame(maxWidth: .infinity)
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
        .frame(height: cardHeight)
        .frame(maxWidth: .infinity)
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
        .frame(height: cardHeight)
        .frame(maxWidth: .infinity)
    }

    private func loadCards() async {
        guard let user = authManager.currentUser else { return }

        isLoading = true
        errorMessage = nil

        let matchingGuilds = await guildManager.fetchMatchingGuilds(for: user)

        isLoading = false

        if matchingGuilds.isEmpty, guildManager.error != nil {
            errorMessage = "Unable to load guilds. Please try again."
        } else {
            cards = matchingGuilds.map(CardItem.init(from:))
        }
    }
}

#Preview {
    MatchingGuildsCarousel()
        .environmentObject(AuthenticationManager())
}
