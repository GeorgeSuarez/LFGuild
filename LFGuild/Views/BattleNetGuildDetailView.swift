//
//  BattleNetGuildDetailView.swift
//  LFGuild
//
//  Detail view for a guild retrieved directly from the Battle.net API.
//

import SwiftUI

struct BattleNetGuildDetailView: View {
    let guild: GuildModel
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerSection

                    if let gm = guild.battleNetOfficers?.first(where: { $0.isGuildMaster }) {
                        guildMasterSection(gm)
                    }

                    Text("This guild was retrieved from Battle.net. In-app features such as applications require the guild to be imported into LFGuild.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top)
                }
                .padding()
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(guild.name)
                .font(.largeTitle)
                .fontWeight(.bold)

            HStack(spacing: 16) {
                if let faction = guild.faction {
                    Label(faction, systemImage: factionIcon(faction))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(factionColor(faction))
                }

                Label("\(guild.memberCount) members", systemImage: "person.2.fill")
                    .font(.subheadline)
                    .foregroundStyle(.blue)

                Spacer()
            }

            Text(guild.serverRealm)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func guildMasterSection(_ gm: BattleNetOfficer) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Guild Master")
                .font(.headline)
                .fontWeight(.semibold)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(gm.name)
                        .fontWeight(.medium)

                    Text("Lv. \(gm.level) \(gm.playableClass)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }

    private func factionIcon(_ faction: String) -> String {
        switch faction.lowercased() {
        case "alliance":
            return "shield.fill"
        case "horde":
            return "flame.fill"
        default:
            return "flag.fill"
        }
    }

    private func factionColor(_ faction: String) -> Color {
        switch faction.lowercased() {
        case "alliance":
            return .blue
        case "horde":
            return .red
        default:
            return .primary
        }
    }
}

#Preview {
    BattleNetGuildDetailView(
        guild: GuildModel(
            name: "Liquid",
            description: "",
            leaderId: "",
            leaderName: "",
            memberCount: 120,
            serverRealm: "Illidan - US",
            faction: "Horde",
            battleNetMemberCount: 120,
            battleNetOfficers: [
                BattleNetOfficer(name: "Max", level: 80, playableClass: "Warlock", rank: 0)
            ]
        ),
        isPresented: .constant(true)
    )
}
