//
//  CardView.swift
//  LFGuild
//
//  Created by George Suarez on 8/1/25.
//

import SwiftUI

struct CardView: View {
    let card: CardItem
    let onTap: () -> Void
    var dragOffset: CGSize = .zero
    
    private var likeOpacity: Double {
        let threshold: CGFloat = 30
        return dragOffset.width > threshold ? Double(min(1, (dragOffset.width - threshold) / 100)) : 0
    }
    
    private var passOpacity: Double {
        let threshold: CGFloat = -30
        return dragOffset.width < threshold ? Double(min(1, abs(dragOffset.width + threshold) / 100 )) : 0
    }
    
    var body: some View {
        VStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(card.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Image(systemName: "person.2.fill")
                            .font(.caption)
                        Text("\(card.memberCount)")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(12)
                }
                
                Text(card.description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                
                HStack {
                    ForEach(card.tags.prefix(2), id: \.self) { tag in
                        Text(tag)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(6)
                    }
                    Spacer()
                    
                    Text("Tap for details")
                        .font(.caption2)
                        .foregroundColor(.blue)
                        .opacity(0.7)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .overlay(
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.green, lineWidth: 4)
                    .opacity(likeOpacity)
                
                VStack {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "heart.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.green)
                            Text("LIKE")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                        }
                        .padding(20)
                        .background(
                            Color.white.opacity(0.9)
                                .cornerRadius(12)
                        )
                        .rotationEffect(.degrees(15))
                        .opacity(likeOpacity)
                        .scaleEffect(likeOpacity > 0 ? 1 : 0.8)
                        .animation(.spring(response: 0.3), value: likeOpacity)
                        Spacer()
                    }
                    .padding(.top, 40)
                    Spacer()
                }
            }
        )
        .overlay(
            // Pass indicator overlay
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.red, lineWidth: 4)
                    .opacity(passOpacity)
                
                VStack {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.red)
                            Text("PASS")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.red)
                        }
                        .padding(20)
                        .background(
                            Color.white.opacity(0.9)
                                .cornerRadius(12)
                        )
                        .rotationEffect(.degrees(-15))
                        .opacity(passOpacity)
                        .scaleEffect(passOpacity > 0 ? 1 : 0.8)
                        .animation(.spring(response: 0.3), value: passOpacity)
                        Spacer()
                    }
                    .padding(.top, 40)
                    Spacer()
                }
            }
        )
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        .onTapGesture {
            onTap()
        }
    }
}

#Preview {
    let card = CardItem(title: "Some Guild Name", description: "Some Guild Description", memberCount: 32, tags: ["Rading", "Mythic +", "PvP", "Social"], requirements: "Purple Parses or 3k IO", leader: "John Pork")
    CardView(card: card, onTap: {})
}
