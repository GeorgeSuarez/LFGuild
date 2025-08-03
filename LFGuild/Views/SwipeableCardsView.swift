//
//  SwipeableCardsView.swift
//  LFGuild
//
//  Created by George Suarez on 8/2/25.
//

import SwiftUI

struct SwipeableCardsView: View {
    @State private var cards: [CardItem] = [
        CardItem(imageURL: "https://via.placeholder.com/400x300/FF6B6B/FFFFFF?text=Guild+1",
                 title: "Adventure Seekers",
                 description: "Join us for epic quests and dungeon crawling adventures in the realm of fantasy gaming. We explore mysterious dungeons, fight legendary monsters, and discover ancient treasures together.",
                 memberCount: 42,
                 tags: ["RPG", "Adventure", "Dungeons", "Fantasy"],
                 requirements: "Level 10+ characters preferred",
                 leader: "DragonSlayer99"),
        CardItem(imageURL: "https://via.placeholder.com/400x300/4ECDC4/FFFFFF?text=Guild+2",
                 title: "Strategy Masters",
                 description: "Tactical gameplay and strategic thinking. Perfect for players who love chess-like challenges and complex battle formations.",
                 memberCount: 28,
                 tags: ["Strategy", "Tactics", "Competitive", "Chess"],
                 requirements: "Must pass strategy test",
                 leader: "TacticalGenius"),
        CardItem(imageURL: "https://via.placeholder.com/400x300/45B7D1/FFFFFF?text=Guild+3",
                 title: "Casual Gamers",
                 description: "Relaxed gaming environment for those who want to have fun without the pressure. Family-friendly community.",
                 memberCount: 67,
                 tags: ["Casual", "Family", "Fun", "Relaxed"],
                 requirements: "Just be friendly!",
                 leader: "ChillPlayer"),
        CardItem(imageURL: "https://via.placeholder.com/400x300/96CEB4/FFFFFF?text=Guild+4",
                 title: "Competitive Arena",
                 description: "High-stakes competitive gaming for serious players looking to climb the ranks and dominate tournaments.",
                 memberCount: 35,
                 tags: ["Competitive", "PvP", "Tournaments", "Pro"],
                 requirements: "Rank Gold or higher",
                 leader: "ChampionMaster"),
        CardItem(imageURL: "https://via.placeholder.com/400x300/FFEAA7/333333?text=Guild+5",
                 title: "Social Hub",
                 description: "Community-focused guild where friendships are formed and memories are made. Regular events and social activities.",
                 memberCount: 89,
                 tags: ["Social", "Events", "Community", "Friends"],
                 requirements: "Active participation required",
                 leader: "SocialButterfly")
    ]
    
    @State private var offset = CGSize.zero
    @State private var isSwipeComplete = false
    @State private var selectedCard: CardItem?
    @State private var showingDetail = false
    
    private let swipeThreshold: CGFloat = 100
    private let rotationMultiplier: CGFloat = 0.1
    
    var body: some View {
        VStack(spacing: 16) {
            if cards.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    
                    Text("No more guilds")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("You've seen all available guilds")
                        .foregroundColor(.secondary)
                    
                    Button("Reset") {
                        resetCards()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                .frame(height: 300)
            } else {
                ZStack {
                    ForEach(Array(cards.prefix(3).enumerated()), id: \.element) { index, card in
                        CardView(card: card) {
                            if index == 0 {
                                selectedCard = card
                                showingDetail = true
                            }
                        }
                        .scaleEffect(1.0 - CGFloat(index) * 0.05)
                        .offset(y: CGFloat(index) * 6)
                        .opacity(index == 0 ? 1.0 : 0.6)
                        .zIndex(Double(cards.count - index))
                        .allowsHitTesting(index == 0)
                    }
                }
                .frame(maxWidth: 320, maxHeight: 400)
                .offset(offset)
                .rotationEffect(.degrees(Double(offset.width) * rotationMultiplier))
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
                
                HStack(spacing: 30) {
                    VStack(spacing: 4) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.red)
                        Text("Pass")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    .opacity(offset.width < -30 ? 1.0 : 0.3)
                    
                    VStack(spacing: 4) {
                        Image(systemName: "heart.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.green)
                        Text("Like")
                            .font(.caption2)
                            .foregroundColor(.green)
                    }
                    .opacity(offset.width > 20 ? 1.0 : 0.3)
                }
                
                
                HStack(spacing: 25) {
                    Button(action: { swipeCard(direction: .left ) }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.red)
                            .frame(width: 40, height: 40)
                            .background(Color(.systemBackground))
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.1), radius: 3)
                    }
                    
                    Button(action: { swipeCard(direction: .right) }) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.green)
                            .frame(width: 40, height: 40)
                            .background(Color(.systemBackground))
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.1), radius: 3)
                    }
                }
            }
        }
        .sheet(isPresented: $showingDetail) {
            if let selectedCard = selectedCard {
                CardDetailView(card: selectedCard, isPresented: $showingDetail)
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
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            cards.removeFirst()
            offset = .zero
        }
    }
    
    private func resetCards() {
        cards = [
            CardItem(imageURL: "https://via.placeholder.com/400x300/FF6B6B/FFFFFF?text=Guild+1",
                     title: "Adventure Seekers",
                     description: "Join us for epic quests and dungeon crawling adventures in the realm of fantasy gaming. We explore mysterious dungeons, fight legendary monsters, and discover ancient treasures together.",
                     memberCount: 42,
                     tags: ["RPG", "Adventure", "Dungeons", "Fantasy"],
                     requirements: "Level 10+ characters preferred",
                     leader: "DragonSlayer99"),
            CardItem(imageURL: "https://via.placeholder.com/400x300/4ECDC4/FFFFFF?text=Guild+2",
                     title: "Strategy Masters",
                     description: "Tactical gameplay and strategic thinking. Perfect for players who love chess-like challenges and complex battle formations.",
                     memberCount: 28,
                     tags: ["Strategy", "Tactics", "Competitive", "Chess"],
                     requirements: "Must pass strategy test",
                     leader: "TacticalGenius"),
            CardItem(imageURL: "https://via.placeholder.com/400x300/45B7D1/FFFFFF?text=Guild+3",
                     title: "Casual Gamers",
                     description: "Relaxed gaming environment for those who want to have fun without the pressure. Family-friendly community.",
                     memberCount: 67,
                     tags: ["Casual", "Family", "Fun", "Relaxed"],
                     requirements: "Just be friendly!",
                     leader: "ChillPlayer"),
            CardItem(imageURL: "https://via.placeholder.com/400x300/96CEB4/FFFFFF?text=Guild+4",
                     title: "Competitive Arena",
                     description: "High-stakes competitive gaming for serious players looking to climb the ranks and dominate tournaments.",
                     memberCount: 35,
                     tags: ["Competitive", "PvP", "Tournaments", "Pro"],
                     requirements: "Rank Gold or higher",
                     leader: "ChampionMaster"),
            CardItem(imageURL: "https://via.placeholder.com/400x300/FFEAA7/333333?text=Guild+5",
                     title: "Social Hub",
                     description: "Community-focused guild where friendships are formed and memories are made. Regular events and social activities.",
                     memberCount: 89,
                     tags: ["Social", "Events", "Community", "Friends"],
                     requirements: "Active participation required",
                     leader: "SocialButterfly")
        ]
    }
}

enum SwipeDirection {
    case left, right
}

#Preview {
    SwipeableCardsView()
}
