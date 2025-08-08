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
    @State private var selectedRealms: Set<WoWRealm> = []
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
            let realmsArray = Array(selectedRealms.map { $0.rawValue })
            
            // Create the preferences data dictionary
            let preferencesData: [String: Any] = [
                "roles": rolesArray,
                "availableDays": daysArray,
                "availableStartTime": Timestamp(date: availableStartTime),
                "availableEndTime": Timestamp(date: availableEndTime),
                "gamingTags": tagsArray,
                "preferredRealms": realmsArray,
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
            currentUser.preferredRealms = Set(realmsArray)
            
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
                    
                    // Load preferred realms
                    if let realmsArray = preferencesData["preferredRealms"] as? [String] {
                        selectedRealms = Set(realmsArray.compactMap { WoWRealm(rawValue: $0) })
                        currentUser.preferredRealms = Set(realmsArray)
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
                    selectedRealms = Set(currentUser.preferredRealms.compactMap { WoWRealm(rawValue: $0) })
                    
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

struct FlowLayout: Layout {
    var spacing: CGFloat
    
    init(spacing: CGFloat = 8) {
        self.spacing = spacing
    }
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        return layout(sizes: sizes, proposal: proposal).size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let offsets = layout(sizes: sizes, proposal: proposal).offsets
        
        for (subview, offset) in zip(subviews, offsets) {
            subview.place(at: CGPoint(x: bounds.minX + offset.x, y: bounds.minY + offset.y), proposal: .unspecified)
        }
    }
    
    private func layout(sizes: [CGSize], proposal: ProposedViewSize) -> (offsets: [CGPoint], size: CGSize) {
        let containerWidth = proposal.width ?? 300
        var offsets: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        
        for size in sizes {
            if currentX + size.width > containerWidth && currentX > 0 {
                currentY += rowHeight + spacing
                totalHeight = currentY
                currentX = 0
                rowHeight = 0
            }
            
            offsets.append(CGPoint(x: currentX, y: currentY))
            currentX += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        
        totalHeight = currentY + rowHeight
        return (offsets, CGSize(width: containerWidth, height: totalHeight))
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

enum WoWRealm: String, CaseIterable {
    case stormrage = "Stormrage - US"
    case tichondrius = "Tichondrius - US"
    case area52 = "Area-52 - US"
    case malganis = "Mal'Ganis - US"
    case dalaran = "Dalaran - US"
    case illidan = "Illidan - US"
    case kiljaeden = "Kil'jaeden - US"
    case thrall = "Thrall - US"
    case zuljin = "Zul'jin - US"
    case emeraldDream = "Emerald Dream - US"
    case proudmoore = "Proudmoore - US"
    case sargeras = "Sargeras - US"
    case frostmourne = "Frostmourne - US"
    case barthilas = "Barthilas - US"
    case ragnaros = "Ragnaros - EU"
    case kazzak = "Kazzak - EU"
    case draenor = "Draenor - EU"
    case silvermoon = "Silvermoon - EU"
    case tarrenMill = "Tarren Mill - EU"
    case outland = "Outland - EU"
    
    var name: String {
        let components = self.rawValue.components(separatedBy: " - ")
        return components.first ?? self.rawValue
    }
    
    var region: String {
        let components = self.rawValue.components(separatedBy: " - ")
        return components.last ?? "US"
    }
}

#Preview {
    PreferencesView()
        .environmentObject(AuthenticationManager())
}
