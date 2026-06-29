//
//  SwipeableCardsView.swift
//  LFGuild
//
//  Created by George Suarez on 8/2/25.
//

import SwiftUI

struct SwipeableCardsView: View {
    @EnvironmentObject private var authManager: AuthenticationManager
    @StateObject private var guildManager = GuildManager()
    @State private var cards: [CardItem] = []
    @State private var offset = CGSize.zero
    @State private var selectedCard: CardItem?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showEmptyState = false
    
    private let swipeThreshold: CGFloat = 100
    private let rotationMultiplier: CGFloat = 0.1
    
    var body: some View {
        VStack(spacing: 16) {
            if isLoading && cards.isEmpty {
                LoadingView()
            } else if showEmptyState || cards.isEmpty {
                EmptyStateView(
                    onRefresh: loadGuilds,
                    onResetPreferences: {
                        // Navigate to preferences would be handled by parent
                    }
                )
            } else {
                HStack {
                    Text("Discover")
                        .font(.title)
                        .fontWeight(.semibold)
                    Spacer()
                    
                    if cards.count > 0 {
                        Text("\(cards.count) guilds")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: 320)
                
                if let topCard = cards.first {
                    MatchScoreBadge(score: topCard.matchScore)
                        .frame(maxWidth: 320, alignment: .leading)
                }
                
                ZStack {
                    ForEach(Array(cards.prefix(3).enumerated()), id: \.element) { index, card in
                        CardView(
                            card: card,
                            onTap: {
                                if index == 0 {
                                    selectedCard = card
                                }
                            },
                            dragOffset: index == 0 ? offset : .zero
                        )
                        .scaleEffect(1.0 - CGFloat(index) * 0.05)
                        .offset(y: CGFloat(index) * 6)
                        .opacity(index == 0 ? 1.0 : 0.6)
                        .zIndex(Double(cards.count - index))
                        .allowsHitTesting(index == 0)
                        .offset(index == 0 ? offset : .zero)
                        .rotationEffect(index == 0 ? .degrees(Double(offset.width) * rotationMultiplier) : .zero)
                    }
                }
                .frame(maxWidth: 320, maxHeight: 400)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            withAnimation(.interactiveSpring()) {
                                offset = value.translation
                            }
                        }
                        .onEnded { value in
                            handleSwipeEnd(translation: value.translation)
                        }
                )
                
                Spacer()
            }
            
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .sheet(item: $selectedCard) { card in
            CardDetailView(card: card, isPresented: .init(
                get: { selectedCard != nil },
                set: { if !$0 { selectedCard = nil } }
            ))
        }
        .onAppear {
            if cards.isEmpty {
                loadGuilds()
            }
        }
    }
    
    private func loadGuilds() {
        guard let user = authManager.currentUser else { return }
        
        isLoading = true
        errorMessage = nil
        showEmptyState = false
        
        Task {
            let matchingGuilds = await guildManager.fetchMatchingGuilds(for: user)
            
            await MainActor.run {
                isLoading = false
                cards = matchingGuilds.map { CardItem(from: $0) }
                showEmptyState = cards.isEmpty
            }
        }
    }
    
    private func handleSwipeEnd(translation: CGSize) {
        let swipeDistance = abs(translation.width)
        let swipeDirection: SwipeDirection = translation.width > 0 ? .right : .left
        
        if swipeDistance > swipeThreshold {
            swipeCard(direction: swipeDirection)
        } else {
            withAnimation(.spring()) {
                offset = .zero
            }
        }
    }
    
    private func swipeCard(direction: SwipeDirection) {
        withAnimation(.easeInOut(duration: 0.3)) {
            offset = CGSize(
                width: direction == .right ? 500 : -500,
                height: 0
            )
        }
        
        // Track the swipe for analytics / learning
        if let topCard = cards.first {
            trackSwipe(card: topCard, direction: direction)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            cards.removeFirst()
            offset = .zero
            
            if cards.isEmpty {
                showEmptyState = true
            }
        }
    }
    
    private func trackSwipe(card: CardItem, direction: SwipeDirection) {
        let guildId = card.guildId ?? "unknown"
        if direction == .right {
            AnalyticsManager.shared.logGuildSwipedRight(
                guildId: guildId,
                guildName: card.title,
                matchScore: card.matchScore
            )
        } else {
            AnalyticsManager.shared.logGuildSwipedLeft(
                guildId: guildId,
                guildName: card.title,
                matchScore: card.matchScore
            )
        }
    }
}

struct MatchScoreBadge: View {
    let score: Double
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "star.fill")
                .font(.caption2)
            Text("\(Int(score * 100))% Match")
                .font(.caption)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(score > 0.7 ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
        .foregroundColor(score > 0.7 ? .green : .orange)
        .cornerRadius(12)
    }
}

struct LoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Finding guilds for you...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(height: 300)
    }
}

struct EmptyStateView: View {
    let onRefresh: () -> Void
    let onResetPreferences: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass.circle")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Matching Guilds")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text("Try adjusting your preferences or check back later for new guilds.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            VStack(spacing: 8) {
                Button("Refresh") {
                    onRefresh()
                }
                .buttonStyle(.borderedProminent)
                
                Button("Edit Preferences") {
                    onResetPreferences()
                }
                .buttonStyle(.bordered)
            }
            .padding(.top)
        }
        .padding()
        .frame(height: 300)
    }
}

enum SwipeDirection {
    case left, right
}

#Preview {
    SwipeableCardsView()
        .environmentObject(AuthenticationManager())
}
