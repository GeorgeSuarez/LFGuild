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
    
    var body: some View {
        VStack(spacing: 8) {
            AsyncImage(url: URL(string: card.imageURL)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay {
                        Image(systemName: "photo")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                    }
            }
            .frame(height: 300)
            .clipped()
            
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
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        .onTapGesture {
            onTap()
        }
    }
}

#Preview {
    let card = CardItem(imageURL: "", title: "Some Guild Name", description: "Some Guild Description", memberCount: 32, tags: ["Rading", "Mythic +", "PvP", "Social"], requirements: "Purple Parses or 3k IO", leader: "John Pork")
    CardView(card: card, onTap: { print("Tapped!") })
}
