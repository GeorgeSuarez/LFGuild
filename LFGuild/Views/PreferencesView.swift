//
//  PreferencesView.swift
//  LFGuild
//
//  Created by George Suarez on 8/8/25.
//

import SwiftUI
import FirebaseFirestore

struct PreferencesView: View {
    @EnvironmentObject private var authManager: AuthenticationManager
    @State private var selectedRoles: Set<Role> = []
    @State private var selectedSpecializations: Set<Specialization> = []
    @State private var availableDays: Set<Day> = []
    @State private var availableStartTime = Date()
    @State private var availableEndTime = Date()
    @State private var selectedTags: Set<Tag> = []
    @State private var selectedRealms: Set<WoWRealm> = []
    @State private var showingSaveAlert = false
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    @State private var isSaving = false
    
    private let db = Firestore.firestore()
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Roles")) {
                    ForEach(Role.allCases, id: \.self) { role in
                        HStack {
                            Text(role.rawValue)
                            Spacer()
                            if selectedRoles.contains(role) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if selectedRoles.contains(role) {
                                selectedRoles.remove(role)
                            } else {
                                selectedRoles.insert(role)
                            }
                        }
                    }
                }
                
                Section(header: Text("Specializations")) {
                    if selectedRoles.isEmpty {
                        Text("Select one or more roles above to choose specializations.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        VStack(alignment: .leading, spacing: 16) {
                            ForEach(selectedRoles.sorted { Role.allCases.firstIndex(of: $0)! < Role.allCases.firstIndex(of: $1)! }, id: \.self) { role in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(role.rawValue)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)

                                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                                        ForEach(Specialization.allCases.filter { $0.role == role }, id: \.self) { specialization in
                                            Button(action: {
                                                if selectedSpecializations.contains(specialization) {
                                                    selectedSpecializations.remove(specialization)
                                                } else {
                                                    selectedSpecializations.insert(specialization)
                                                }
                                            }) {
                                                HStack {
                                                    Text(specialization.rawValue)
                                                        .font(.caption)
                                                    Spacer()
                                                    if selectedSpecializations.contains(specialization) {
                                                        Image(systemName: "checkmark")
                                                            .foregroundColor(specialization.roleColor)
                                                    }
                                                }
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 6)
                                                .background(
                                                    selectedSpecializations.contains(specialization)
                                                        ? specialization.roleColor.opacity(0.15)
                                                        : Color.gray.opacity(0.2)
                                                )
                                                .foregroundColor(
                                                    selectedSpecializations.contains(specialization)
                                                        ? specialization.roleColor
                                                        : .primary
                                                )
                                                .cornerRadius(16)
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Section(header: Text("Raid Availability")) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Available Days")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                            ForEach(Day.allCases, id: \.self) { day in
                                Button(action: {
                                    if availableDays.contains(day) {
                                        availableDays.remove(day)
                                    } else {
                                        availableDays.insert(day)
                                    }
                                }) {
                                    Text(day.rawValue)
                                        .font(.caption)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(
                                            availableDays.contains(day) ? Color.blue : Color.gray.opacity(0.2)
                                        )
                                        .foregroundColor(
                                            availableDays.contains(day) ? .white : .primary
                                        )
                                        .cornerRadius(16)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    
                    DatePicker("Start Time", selection: $availableStartTime, displayedComponents: .hourAndMinute)
                    DatePicker("End Time", selection: $availableEndTime, displayedComponents: .hourAndMinute)
                }
                
                Section(header: Text("Gaming Tags")) {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                        ForEach(Tag.allCases, id: \.self) { tag in
                            Button(action: {
                                if selectedTags.contains(tag) {
                                    selectedTags.remove(tag)
                                } else {
                                    selectedTags.insert(tag)
                                }
                            }) {
                                Text(tag.rawValue)
                                    .font(.caption)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        selectedTags.contains(tag) ? Color.green : Color.gray.opacity(0.2)
                                    )
                                    .foregroundColor(
                                        selectedTags.contains(tag) ? .white : .primary
                                    )
                                    .cornerRadius(16)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                Section(header: Text("Preferred WoW Realms")) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Select your preferred realms for guild matching")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Menu {
                            ForEach(WoWRealm.allCases, id: \.self) { realm in
                                Button(action: {
                                    if selectedRealms.contains(realm) {
                                        selectedRealms.remove(realm)
                                    } else {
                                        selectedRealms.insert(realm)
                                    }
                                }) {
                                    HStack {
                                        Text("\(realm.name) (\(realm.region))")
                                        Spacer()
                                        if selectedRealms.contains(realm) {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(.blue)
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                Text(selectedRealms.isEmpty ? "Select Realms" : "\(selectedRealms.count) realm\(selectedRealms.count == 1 ? "" : "s") selected")
                                    .foregroundColor(selectedRealms.isEmpty ? .secondary : .primary)
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                        
                        if !selectedRealms.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Selected Realms:")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)
                                
                                FlowLayout(spacing: 6) {
                                    ForEach(Array(selectedRealms), id: \.self) { realm in
                                        HStack(spacing: 4) {
                                            Text(realm.rawValue)
                                                .font(.caption)
                                            Button(action: {
                                                selectedRealms.remove(realm)
                                            }) {
                                                Image(systemName: "xmark.circle.fill")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.purple.opacity(0.1))
                                        .foregroundColor(.purple)
                                        .cornerRadius(12)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("Preferences")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            await savePreferences()
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(isSaving)
                }
            }
            .onAppear {
                Task {
                    await loadCurrentPreferences()
                }
            }
            .alert("Preferences Saved", isPresented: $showingSaveAlert) {
                Button("OK") { }
            } message: {
                Text("Your preferences have been saved successfully.")
            }
            .alert("Save Failed", isPresented: $showingErrorAlert) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            .onChange(of: selectedRoles) { _, newRoles in
                selectedSpecializations = selectedSpecializations.filter { newRoles.contains($0.role) }
            }
        }
    }

    private func savePreferences() async {
        guard let currentUser = authManager.currentUser,
              let firebaseUID = currentUser.firebaseUID else { return }

        isSaving = true

        do {
            let rolesArray = Array(selectedRoles.map { $0.rawValue })
            let specializationsArray = Array(selectedSpecializations.map { $0.rawValue })
            let daysArray = Array(availableDays.map { $0.rawValue })
            let tagsArray = Array(selectedTags.map { $0.rawValue })
            let realmsArray = Array(selectedRealms.map { $0.rawValue })

            let publicProfileData: [String: Any] = [
                "name": currentUser.name,
                "roles": rolesArray,
                "specializations": specializationsArray,
                "availableDays": daysArray,
                "availableStartTime": Timestamp(date: availableStartTime),
                "availableEndTime": Timestamp(date: availableEndTime),
                "gamingTags": tagsArray,
                "preferredRealms": realmsArray,
                "updatedAt": Timestamp(date: Date())
            ]

            try await db.collection("publicProfiles").document(firebaseUID).setData(
                publicProfileData,
                merge: true
            )

            currentUser.roles = Set(rolesArray)
            currentUser.specializations = Set(specializationsArray)
            currentUser.availableDays = Set(daysArray)
            currentUser.availableStartTime = availableStartTime
            currentUser.availableEndTime = availableEndTime
            currentUser.gamingTags = Set(tagsArray)
            currentUser.preferredRealms = Set(realmsArray)

            await MainActor.run {
                isSaving = false
                showingSaveAlert = true
            }

        } catch {
            await MainActor.run {
                isSaving = false
                errorMessage = "Failed to save preferences: \(error.localizedDescription)"
                showingErrorAlert = true
            }
        }
    }

    private func loadCurrentPreferences() async {
        guard let currentUser = authManager.currentUser,
              let firebaseUID = currentUser.firebaseUID else { return }

        do {
            let document = try await db.collection("publicProfiles").document(firebaseUID).getDocument()

            if let data = document.data() {
                await MainActor.run {
                    if let rolesArray = data["roles"] as? [String] {
                        selectedRoles = Set(rolesArray.compactMap { Role(rawValue: $0) })
                        currentUser.roles = Set(rolesArray)
                    }

                    if let specializationsArray = data["specializations"] as? [String] {
                        selectedSpecializations = Set(specializationsArray.compactMap { Specialization(rawValue: $0) })
                        currentUser.specializations = Set(specializationsArray)
                    }

                    if let daysArray = data["availableDays"] as? [String] {
                        availableDays = Set(daysArray.compactMap { Day(rawValue: $0) })
                        currentUser.availableDays = Set(daysArray)
                    }

                    if let tagsArray = data["gamingTags"] as? [String] {
                        selectedTags = Set(tagsArray.compactMap { Tag(rawValue: $0) })
                        currentUser.gamingTags = Set(tagsArray)
                    }

                    if let realmsArray = data["preferredRealms"] as? [String] {
                        selectedRealms = Set(realmsArray.compactMap { WoWRealm(rawValue: $0) })
                        currentUser.preferredRealms = Set(realmsArray)
                    }

                    if let startTimeTimestamp = data["availableStartTime"] as? Timestamp {
                        availableStartTime = startTimeTimestamp.dateValue()
                        currentUser.availableStartTime = startTimeTimestamp.dateValue()
                    }

                    if let endTimeTimestamp = data["availableEndTime"] as? Timestamp {
                        availableEndTime = endTimeTimestamp.dateValue()
                        currentUser.availableEndTime = endTimeTimestamp.dateValue()
                    }
                }
            } else {
                await MainActor.run {
                    selectedRoles = Set(currentUser.roles.compactMap { Role(rawValue: $0) })
                    selectedSpecializations = Set(currentUser.specializations.compactMap { Specialization(rawValue: $0) })
                    availableDays = Set(currentUser.availableDays.compactMap { Day(rawValue: $0) })
                    selectedTags = Set(currentUser.gamingTags.compactMap { Tag(rawValue: $0) })
                    selectedRealms = Set(currentUser.preferredRealms.compactMap { WoWRealm(rawValue: $0) })

                    if let startTime = currentUser.availableStartTime {
                        availableStartTime = startTime
                    }
                    if let endTime = currentUser.availableEndTime {
                        availableEndTime = endTime
                    }
                }
            }

        } catch {
            await MainActor.run {
                selectedRoles = Set(currentUser.roles.compactMap { Role(rawValue: $0) })
                selectedSpecializations = Set(currentUser.specializations.compactMap { Specialization(rawValue: $0) })
                availableDays = Set(currentUser.availableDays.compactMap { Day(rawValue: $0) })
                selectedTags = Set(currentUser.gamingTags.compactMap { Tag(rawValue: $0) })
                selectedRealms = Set(currentUser.preferredRealms.compactMap { WoWRealm(rawValue: $0) })

                if let startTime = currentUser.availableStartTime {
                    availableStartTime = startTime
                }
                if let endTime = currentUser.availableEndTime {
                    availableEndTime = endTime
                }
            }
        }
    }
}

#Preview {
    PreferencesView()
        .environmentObject(AuthenticationManager())
}
