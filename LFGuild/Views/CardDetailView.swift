//
//  CardDetailView.swift
//  LFGuild
//
//  Created by George Suarez on 8/2/25.
//

import SwiftUI

struct CardDetailView: View {
    let card: CardItem
    @Binding var isPresented: Bool
    @EnvironmentObject private var authManager: AuthenticationManager
    @StateObject private var messagingManager = MessagingManager()
    @State private var showingMessageComposer = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    AsyncImage(url: URL(string: card.imageURL)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .overlay {
                                Image(systemName: "photo")
                                    .font(.system(size: 40))
                                    .foregroundColor(.gray)
                            }
                    }
                    .frame(height: 250)
                    .clipped()
                    .cornerRadius(16)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text(card.title)
                                .font(.largeTitle)
                                .fontWeight(.bold)
                            
                            Spacer()
                            
                            VStack(alignment: .trailing) {
                                HStack(spacing: 4) {
                                    Image(systemName: "person.2.fill")
                                        .font(.subheadline)
                                    Text("\(card.memberCount) members")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }
                                .foregroundColor(.blue)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("About")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            Text(card.description)
                                .font(.body)
                                .foregroundColor(.primary)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Tags")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                                ForEach(card.tags, id: \.self) { tag in
                                    Text(tag)
                                        .font(.caption)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.blue.opacity(0.1))
                                        .foregroundColor(.blue)
                                        .cornerRadius(12)
                                }
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Guild Leader")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            HStack {
                                Circle()
                                    .fill(Color.blue.opacity(0.3))
                                    .frame(width: 40, height: 40)
                                    .overlay {
                                        Text(String(card.leader.prefix(1)))
                                            .font(.headline)
                                            .fontWeight(.bold)
                                            .foregroundColor(.blue)
                                    }
                                
                                Text(card.leader)
                                    .font(.body)
                                    .fontWeight(.medium)
                                
                                Spacer()
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Server / Realm")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            HStack {
                                Image(systemName: "server.rack")
                                    .foregroundColor(.blue)
                                Text(card.serverRealm)
                                    .font(.body)
                                    .fontWeight(.medium)
                                Spacer()
                            }
                        }
                        
                        if !card.raidDays.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Raid Schedule")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Image(systemName: "calendar")
                                            .foregroundColor(.blue)
                                        Text("Days:")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        Text(card.raidDays.joined(separator: ", "))
                                            .font(.subheadline)
                                        Spacer()
                                    }
                                    
                                    if !card.raidTime.isEmpty {
                                        HStack {
                                            Image(systemName: "clock")
                                                .foregroundColor(.blue)
                                            Text("Time:")
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                            Text(card.raidTime)
                                                .font(.subheadline)
                                            Spacer()
                                        }
                                    }
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.05))
                                .cornerRadius(8)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Requirements")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            Text(card.requirements)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        
                        VStack(spacing: 12) {
                            Button(action: {
                                isPresented = false
                            }) {
                                Text("Request to Join")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                                    .background(Color.blue)
                                    .cornerRadius(12)
                            }
                            
                            Button(action: {
                                showingMessageComposer = true
                            }) {
                                HStack {
                                    Image(systemName: "message.fill")
                                    Text("Message Guild Leader")
                                }
                                .font(.headline)
                                .foregroundColor(.blue)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(12)
                            }
                        }
                        .padding(.top, 20)
                    }
                    .padding(.horizontal)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
            .sheet(isPresented: $showingMessageComposer) {
                MessageGuildLeaderView(guildLeader: card.leader)
                    .environmentObject(authManager)
                    .environmentObject(messagingManager)
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
}

#Preview {
    let card = CardItem(imageURL: "", title: "Some Guild Name", description: "Some Guild Description", memberCount: 32, tags: ["Raiding", "Mythic +", "PvP", "Social"], requirements: "Purple Parses or 3k IO", leader: "John Pork", raidDays: ["Tuesday", "Thursday", "Sunday"], raidTime: "8:00 PM - 11:00 PM EST", serverRealm: "Stormrage - US")
    CardDetailView(card: card, isPresented: .constant(true))
        .environmentObject(AuthenticationManager())
        .environmentObject(MessagingManager())
}
