//
//  CardView.swift
//  LFGuild
//
//  Created by George Suarez on 8/1/25.
//

import SwiftUI

struct CardItem: Identifiable, Hashable {
   let id = UUID()
   let imageURL: String
   let title: String
   let description: String
}

struct CardView: View {
    let card: CardItem
    
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
                Text(card.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.leading)
                
                Text(card.description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

#Preview {
    let card = CardItem(imageURL: "", title: "Some Guild Name", description: "Some Guild Description")
    CardView(card: card)
}
