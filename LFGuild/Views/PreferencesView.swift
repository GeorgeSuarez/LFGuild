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
    @State private var availableDays: Set<Day> = []
    @State private var availableStartTime = Date()
    @State private var availableEndTime = Date()
    @State private var selectedTags: Set<Tag> = []
    @State private var showingSaveAlert = false
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
        }
    }
    
    private func savePreferences() async {
        guard let currentUser = authManager.currentUser,
              let firebaseUID = currentUser.firebaseUID else { return }
        
        isSaving = true
        
        do {
            // Convert enum sets to string sets for storage
            let rolesArray = Array(selectedRoles.map { $0.rawValue })
            let daysArray = Array(availableDays.map { $0.rawValue })
            let tagsArray = Array(selectedTags.map { $0.rawValue })
            
            // Create the preferences data dictionary
            let preferencesData: [String: Any] = [
                "roles": rolesArray,
                "availableDays": daysArray,
                "availableStartTime": Timestamp(date: availableStartTime),
                "availableEndTime": Timestamp(date: availableEndTime),
                "gamingTags": tagsArray,
                "updatedAt": Timestamp(date: Date())
            ]
            
            // Save to Firestore
            try await db.collection("users").document(firebaseUID).setData([
                "preferences": preferencesData
            ], merge: true)
            
            // Also update the local user model
            currentUser.roles = Set(rolesArray)
            currentUser.availableDays = Set(daysArray)
            currentUser.availableStartTime = availableStartTime
            currentUser.availableEndTime = availableEndTime
            currentUser.gamingTags = Set(tagsArray)
            
            // Show success alert
            await MainActor.run {
                isSaving = false
                showingSaveAlert = true
            }
            
            print("Preferences saved successfully to Firestore")
            
        } catch {
            print("Error saving preferences to Firestore: \(error.localizedDescription)")
            await MainActor.run {
                isSaving = false
            }
            // TODO: Show error alert to user
        }
    }
    
    private func loadCurrentPreferences() async {
        guard let currentUser = authManager.currentUser,
              let firebaseUID = currentUser.firebaseUID else { return }
        
        do {
            // First try to load from Firestore
            let document = try await db.collection("users").document(firebaseUID).getDocument()
            
            if let data = document.data(),
               let preferencesData = data["preferences"] as? [String: Any] {
                
                await MainActor.run {
                    // Load roles
                    if let rolesArray = preferencesData["roles"] as? [String] {
                        selectedRoles = Set(rolesArray.compactMap { Role(rawValue: $0) })
                        currentUser.roles = Set(rolesArray)
                    }
                    
                    // Load available days
                    if let daysArray = preferencesData["availableDays"] as? [String] {
                        availableDays = Set(daysArray.compactMap { Day(rawValue: $0) })
                        currentUser.availableDays = Set(daysArray)
                    }
                    
                    // Load gaming tags
                    if let tagsArray = preferencesData["gamingTags"] as? [String] {
                        selectedTags = Set(tagsArray.compactMap { Tag(rawValue: $0) })
                        currentUser.gamingTags = Set(tagsArray)
                    }
                    
                    // Load time preferences
                    if let startTimeTimestamp = preferencesData["availableStartTime"] as? Timestamp {
                        availableStartTime = startTimeTimestamp.dateValue()
                        currentUser.availableStartTime = startTimeTimestamp.dateValue()
                    }
                    
                    if let endTimeTimestamp = preferencesData["availableEndTime"] as? Timestamp {
                        availableEndTime = endTimeTimestamp.dateValue()
                        currentUser.availableEndTime = endTimeTimestamp.dateValue()
                    }
                }
                
                print("Preferences loaded successfully from Firestore")
                
            } else {
                // Fallback to local user model if no Firestore data
                await MainActor.run {
                    selectedRoles = Set(currentUser.roles.compactMap { Role(rawValue: $0) })
                    availableDays = Set(currentUser.availableDays.compactMap { Day(rawValue: $0) })
                    selectedTags = Set(currentUser.gamingTags.compactMap { Tag(rawValue: $0) })
                    
                    if let startTime = currentUser.availableStartTime {
                        availableStartTime = startTime
                    }
                    if let endTime = currentUser.availableEndTime {
                        availableEndTime = endTime
                    }
                }
                
                print("No Firestore preferences found, using local user model")
            }
            
        } catch {
            print("Error loading preferences from Firestore: \(error.localizedDescription)")
            
            // Fallback to local user model on error
            await MainActor.run {
                selectedRoles = Set(currentUser.roles.compactMap { Role(rawValue: $0) })
                availableDays = Set(currentUser.availableDays.compactMap { Day(rawValue: $0) })
                selectedTags = Set(currentUser.gamingTags.compactMap { Tag(rawValue: $0) })
                
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

enum Role: String, CaseIterable {
    case dps = "DPS"
    case healer = "Healer"
    case tank = "Tank"
}

enum Day: String, CaseIterable {
    case monday = "Monday"
    case tuesday = "Tuesday"
    case wednesday = "Wednesday"
    case thursday = "Thursday"
    case friday = "Friday"
    case saturday = "Saturday"
    case sunday = "Sunday"
}

enum Tag: String, CaseIterable {
    case hardcore = "Hardcore"
    case casual = "Casual"
    case mythicPlus = "Mythic+ Focused"
    case raidFocused = "Raid Focused"
    case pvp = "PvP"
    case roleplay = "RP"
}

#Preview {
    PreferencesView()
}