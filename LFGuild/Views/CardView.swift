//
//  CardView.swift
//  LFGuild
//
//  Created by George Suarez on 8/1/25.
//

import SwiftUI

struct CardView: View {
    let card: CardItem
    let onViewMoreInfo: () -> Void

    var body: some View {
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
                .foregroundStyle(.blue)
                .clipShape(.rect(cornerRadius: 12))
            }

            if card.matchScore > 0 {
                MatchScoreBadge(score: card.matchScore)
            }

            Text(card.description)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
                .lineLimit(3)

            HStack {
                ForEach(card.tags.prefix(2), id: \.self) { tag in
                    Text(tag)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.gray.opacity(0.2))
                        .clipShape(.rect(cornerRadius: 6))
                }

                Spacer()
            }

            Spacer()

            Button("View More Info") {
                onViewMoreInfo()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .frame(maxWidth: .infinity)
            .accessibilityLabel("View more info for \(card.title)")
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(.systemBackground))
        .clipShape(.rect(cornerRadius: 16))
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        .accessibilityElement(children: .contain)
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
        .foregroundStyle(score > 0.7 ? .green : .orange)
        .clipShape(.rect(cornerRadius: 12))
    }
}

#Preview {
    let card = CardItem(
        title: "Some Guild Name",
        description: "Some Guild Description",
        memberCount: 32,
        tags: ["Raiding", "Mythic +", "PvP", "Social"],
        requirements: "Purple Parses or 3k IO",
        leader: "John Pork",
        matchScore: 0.85
    )

    CardView(card: card, onViewMoreInfo: {})
        .frame(width: 300, height: 380)
        .padding()
}
