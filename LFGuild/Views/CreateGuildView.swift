//
//  CreateGuildView.swift
//  LFGuild
//
//  Created by George Suarez on 6/29/26.
//

import SwiftUI

struct CreateGuildView: View {
    @EnvironmentObject private var authManager: AuthenticationManager
    @Environment(\.dismiss) private var dismiss
    @StateObject private var guildManager = GuildManager()

    // Battle.net import
    @State private var importRealm = ""
    @State private var importGuildName = ""
    @State private var isImporting = false
    @State private var importError: String?

    // Guild details
    @State private var name = ""
    @State private var serverRealm = ""
    @State private var description = ""
    @State private var requirements = ""
    @State private var selectedRaidDays: Set<String> = []
    @State private var raidStartTime = ""
    @State private var raidEndTime = ""
    @State private var selectedTags: Set<String> = []
    @State private var selectedRoles: Set<String> = []
    @State private var maxMembers = 50

    // Battle.net enriched data
    @State private var battleNetGuildId: Int?
    @State private var faction: String?
    @State private var battleNetMemberCount: Int?
    @State private var battleNetOfficers: [BattleNetOfficer]?
    @State private var battleNetLastSyncedAt: Date?

    @State private var isSubmitting = false
    @State private var submitError: String?
    @State private var showSubmitError = false

    private let availableRealms = WoWRealm.allCases.filter { $0.region == "US" }.map(\.rawValue)
    private let availableTags = Tag.allCases.map(\.rawValue)
    private let availableRoles = Role.allCases.map(\.rawValue)
    private let availableDays = Day.allCases.map(\.rawValue)

    var body: some View {
        NavigationStack {
            Form {
                battleNetImportSection

                if let faction = faction {
                    importedDataSection(faction: faction)
                }

                basicDetailsSection
                scheduleSection
                preferencesSection
            }
            .navigationTitle("Create Guild")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        Task { await submitGuild() }
                    }
                    .disabled(!canSubmit || isSubmitting)
                    .fontWeight(.semibold)
                }
            }
            .alert("Error", isPresented: $showSubmitError) {
                Button("OK") { }
            } message: {
                Text(submitError ?? "An unknown error occurred.")
            }
        }
    }

    // MARK: - Sections

    private var battleNetImportSection: some View {
        Section {
            Picker("Realm", selection: $importRealm) {
                Text("Select a realm").tag("")
                ForEach(availableRealms, id: \.self) { realm in
                    Text(realm).tag(realm)
                }
            }

            TextField("Guild Name", text: $importGuildName)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()

            if isImporting {
                ProgressView("Importing from Battle.net...")
            } else {
                Button("Import from Battle.net") {
                    Task { await importFromBattleNet() }
                }
                .disabled(importRealm.isEmpty || importGuildName.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            if let importError = importError {
                Text(importError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        } header: {
            Text("Battle.net Import")
        } footer: {
            Text("Importing will fill in the guild name, realm, member count, faction, and officers.")
        }
    }

    @ViewBuilder
    private func importedDataSection(faction: String) -> some View {
        Section("Imported from Battle.net") {
            HStack {
                Text("Faction")
                Spacer()
                Text(faction)
                    .fontWeight(.semibold)
                    .foregroundStyle(factionColor(faction))
            }

            if let memberCount = battleNetMemberCount {
                HStack {
                    Text("Member Count")
                    Spacer()
                    Text("\(memberCount)")
                        .fontWeight(.semibold)
                }
            }

            if let officers = battleNetOfficers, !officers.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Leadership")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    ForEach(officers, id: \.self) { officer in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(officer.name)
                                    .fontWeight(.medium)
                                Text("\(officer.displayTitle) · Lv. \(officer.level) \(officer.playableClass)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                    }
                }
            }

            if let lastSynced = battleNetLastSyncedAt {
                Text("Last synced: \(lastSynced, formatter: dateFormatter)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var basicDetailsSection: some View {
        Section("Guild Details") {
            TextField("Guild Name", text: $name)
                .textInputAutocapitalization(.words)

            Picker("Realm", selection: $serverRealm) {
                Text("Select a realm").tag("")
                ForEach(availableRealms, id: \.self) { realm in
                    Text(realm).tag(realm)
                }
            }

            TextEditor(text: $description)
                .frame(minHeight: 80)
                .overlay(alignment: .topLeading) {
                    if description.isEmpty {
                        Text("Description")
                            .foregroundStyle(.secondary)
                            .padding(.top, 8)
                            .padding(.leading, 4)
                    }
                }

            TextEditor(text: $requirements)
                .frame(minHeight: 80)
                .overlay(alignment: .topLeading) {
                    if requirements.isEmpty {
                        Text("Requirements")
                            .foregroundStyle(.secondary)
                            .padding(.top, 8)
                            .padding(.leading, 4)
                    }
                }

            Stepper("Max Members: \(maxMembers)", value: $maxMembers, in: 1...1000)
        }
    }

    private var scheduleSection: some View {
        Section("Raid Schedule") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Raid Days")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                FlowLayout(spacing: 8) {
                    ForEach(availableDays, id: \.self) { day in
                        FilterChip(
                            text: day,
                            isSelected: selectedRaidDays.contains(day),
                            color: .green
                        ) {
                            if selectedRaidDays.contains(day) {
                                selectedRaidDays.remove(day)
                            } else {
                                selectedRaidDays.insert(day)
                            }
                        }
                    }
                }
            }

            HStack {
                TextField("Start Time", text: $raidStartTime)
                    .textInputAutocapitalization(.never)
                Text("–")
                TextField("End Time", text: $raidEndTime)
                    .textInputAutocapitalization(.never)
            }
        }
    }

    private var preferencesSection: some View {
        Section("Preferences") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Tags")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                FlowLayout(spacing: 8) {
                    ForEach(availableTags, id: \.self) { tag in
                        FilterChip(
                            text: tag,
                            isSelected: selectedTags.contains(tag),
                            color: .blue
                        ) {
                            if selectedTags.contains(tag) {
                                selectedTags.remove(tag)
                            } else {
                                selectedTags.insert(tag)
                            }
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Needed Roles")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                FlowLayout(spacing: 8) {
                    ForEach(availableRoles, id: \.self) { role in
                        FilterChip(
                            text: role,
                            isSelected: selectedRoles.contains(role),
                            color: .orange
                        ) {
                            if selectedRoles.contains(role) {
                                selectedRoles.remove(role)
                            } else {
                                selectedRoles.insert(role)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func importFromBattleNet() async {
        isImporting = true
        importError = nil

        do {
            let tempGuild = GuildModel(
                name: importGuildName.trimmingCharacters(in: .whitespacesAndNewlines),
                description: "",
                leaderId: "",
                leaderName: "",
                serverRealm: importRealm,
                region: "US"
            )

            let enriched = try await guildManager.enrichFromBattleNet(tempGuild)

            name = enriched.name
            serverRealm = enriched.serverRealm
            battleNetGuildId = enriched.battleNetGuildId
            faction = enriched.faction
            battleNetMemberCount = enriched.battleNetMemberCount
            battleNetOfficers = enriched.battleNetOfficers
            battleNetLastSyncedAt = enriched.battleNetLastSyncedAt
        } catch let error as BattleNetError {
            importError = error.localizedDescription
        } catch {
            importError = error.localizedDescription
        }

        isImporting = false
    }

    private func submitGuild() async {
        guard let user = authManager.currentUser,
              let userId = user.firebaseUID else {
            submitError = "You must be signed in to create a guild."
            showSubmitError = true
            return
        }

        isSubmitting = true

        var guild = GuildModel(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            description: description.trimmingCharacters(in: .whitespacesAndNewlines),
            leaderId: userId,
            leaderName: user.name.trimmingCharacters(in: .whitespacesAndNewlines),
            memberCount: battleNetMemberCount ?? 1,
            maxMembers: maxMembers,
            tags: Array(selectedTags),
            requirements: requirements.trimmingCharacters(in: .whitespacesAndNewlines),
            raidDays: Array(selectedRaidDays),
            raidStartTime: raidStartTime,
            raidEndTime: raidEndTime,
            serverRealm: serverRealm,
            region: "US",
            neededRoles: Array(selectedRoles),
            battleNetGuildId: battleNetGuildId,
            faction: faction,
            battleNetMemberCount: battleNetMemberCount,
            battleNetOfficers: battleNetOfficers,
            battleNetLastSyncedAt: battleNetLastSyncedAt
        )

        // Enrich again at submit time if the user edited the name/realm after importing.
        if !name.isEmpty && !serverRealm.isEmpty && battleNetGuildId == nil {
            do {
                guild = try await guildManager.enrichFromBattleNet(guild)
                faction = guild.faction
                battleNetMemberCount = guild.battleNetMemberCount
                battleNetOfficers = guild.battleNetOfficers
                battleNetLastSyncedAt = guild.battleNetLastSyncedAt
            } catch {
                // Non-fatal; allow manual creation without Battle.net data.
            }
        }

        do {
            try await guildManager.createGuild(guild)
            await MainActor.run {
                isSubmitting = false
                dismiss()
            }
        } catch {
            await MainActor.run {
                isSubmitting = false
                submitError = error.localizedDescription
                showSubmitError = true
            }
        }
    }

    // MARK: - Helpers

    private var canSubmit: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !serverRealm.isEmpty
        && !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }
}

#Preview {
    CreateGuildView()
        .environmentObject(AuthenticationManager())
}
