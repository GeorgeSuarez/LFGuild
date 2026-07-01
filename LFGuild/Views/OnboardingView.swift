//
//  OnboardingView.swift
//  LFGuild
//
//  Created by George Suarez on 8/10/25.
//

import SwiftUI
import FirebaseFirestore

struct OnboardingView: View {
    @ObservedObject var user: UserModel
    @EnvironmentObject private var authManager: AuthenticationManager
    var onComplete: () -> Void
    
    @State private var currentStep = 0
    @State private var selectedRoles: Set<Role> = []
    @State private var selectedSpecializations: Set<Specialization> = []
    @State private var availableDays: Set<Day> = []
    @State private var availableStartTime = Date()
    @State private var availableEndTime = Date()
    @State private var selectedTags: Set<Tag> = []
    @State private var selectedRealms: Set<WoWRealm> = []
    @State private var isSaving = false
    @State private var showingError = false
    @State private var errorMessage = ""

    private let db = Firestore.firestore()
    private let totalSteps = 6
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Progress bar
                ProgressView(value: Double(currentStep + 1), total: Double(totalSteps))
                    .padding(.horizontal)
                    .padding(.top)
                
                Text("Step \(currentStep + 1) of \(totalSteps)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 8)
                
                // Step content
                ScrollView {
                    VStack(spacing: 24) {
                        switch currentStep {
                        case 0:
                            WelcomeStepView()
                        case 1:
                            RolesStepView(selectedRoles: $selectedRoles)
                        case 2:
                            SpecializationsStepView(
                                selectedSpecializations: $selectedSpecializations,
                                selectedRoles: selectedRoles
                            )
                        case 3:
                            AvailabilityStepView(
                                availableDays: $availableDays,
                                startTime: $availableStartTime,
                                endTime: $availableEndTime
                            )
                        case 4:
                            TagsStepView(selectedTags: $selectedTags)
                        case 5:
                            RealmsStepView(selectedRealms: $selectedRealms)
                        default:
                            EmptyView()
                        }
                    }
                    .padding()
                }
                
                // Bottom buttons
                VStack(spacing: 12) {
                    if currentStep > 0 {
                        Button("Previous") {
                            withAnimation {
                                currentStep -= 1
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    Button(action: handleNext) {
                        HStack {
                            if isSaving {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            }
                            Text(currentStep == totalSteps - 1 ? "Get Started" : "Next")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isNextDisabled ? Color.gray : Color.blue)
                        .cornerRadius(12)
                    }
                    .disabled(isNextDisabled || isSaving)
                }
                .padding()
                .background(.ultraThinMaterial)
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            .onChange(of: selectedRoles) { _, newRoles in
                selectedSpecializations = selectedSpecializations.filter { newRoles.contains($0.role) }
            }
        }
    }

    private var isNextDisabled: Bool {
        switch currentStep {
        case 0:
            return false
        case 1:
            return selectedRoles.isEmpty
        case 2:
            return selectedSpecializations.isEmpty
        case 3:
            return availableDays.isEmpty
        case 4:
            return selectedTags.isEmpty
        case 5:
            return selectedRealms.isEmpty
        default:
            return true
        }
    }
    
    private func handleNext() {
        if currentStep < totalSteps - 1 {
            withAnimation {
                currentStep += 1
            }
        } else {
            savePreferencesAndFinish()
        }
    }
    
    private func savePreferencesAndFinish() {
        guard let firebaseUID = user.firebaseUID else { return }

        isSaving = true

        Task {
            do {
                let rolesArray = Array(selectedRoles.map { $0.rawValue })
                let specializationsArray = Array(selectedSpecializations.map { $0.rawValue })
                let daysArray = Array(availableDays.map { $0.rawValue })
                let tagsArray = Array(selectedTags.map { $0.rawValue })
                let realmsArray = Array(selectedRealms.map { $0.rawValue })

                let publicProfileData: [String: Any] = [
                    "name": user.name,
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

                // Update local user model
                await MainActor.run {
                    user.roles = Set(rolesArray)
                    user.specializations = Set(specializationsArray)
                    user.availableDays = Set(daysArray)
                    user.availableStartTime = availableStartTime
                    user.availableEndTime = availableEndTime
                    user.gamingTags = Set(tagsArray)
                    user.preferredRealms = Set(realmsArray)

                    isSaving = false
                    onComplete()
                }

            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = "Failed to save preferences: \(error.localizedDescription)"
                    showingError = true
                }
            }
        }
    }
}

// MARK: - Step Views

struct WelcomeStepView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "person.crop.circle.badge.checkmark")
                .font(.system(size: 80))
                .foregroundColor(.blue)
            
            Text("Welcome to LFGuild!")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Let's set up your profile so we can find the perfect guild for you. This will only take a minute.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            VStack(alignment: .leading, spacing: 16) {
                OnboardingFeatureRow(icon: "gamecontroller.fill", text: "Select your preferred roles")
                OnboardingFeatureRow(icon: "calendar", text: "Set your raid availability")
                OnboardingFeatureRow(icon: "tag.fill", text: "Choose your gaming style")
                OnboardingFeatureRow(icon: "globe", text: "Pick your preferred realms")
            }
            .padding(.top)
        }
    }
}

struct OnboardingFeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .font(.title3)
            Text(text)
                .font(.body)
            Spacer()
        }
    }
}

struct RolesStepView: View {
    @Binding var selectedRoles: Set<Role>
    
    var body: some View {
        VStack(spacing: 20) {
            Text("What roles do you play?")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Select all that apply. This helps us match you with guilds that need your roles.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            VStack(spacing: 12) {
                ForEach(Role.allCases, id: \.self) { role in
                    RoleSelectionButton(
                        role: role,
                        isSelected: selectedRoles.contains(role)
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

struct RoleSelectionButton: View {
    let role: Role
    let isSelected: Bool
    let action: () -> Void
    
    var roleIcon: String {
        switch role {
        case .tank: return "shield.fill"
        case .healer: return "heart.fill"
        case .dps: return "flame.fill"
        }
    }
    
    var roleColor: Color {
        switch role {
        case .tank: return .blue
        case .healer: return .green
        case .dps: return .red
        }
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: roleIcon)
                    .font(.title2)
                    .foregroundColor(roleColor)
                    .frame(width: 40)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(role.rawValue)
                        .font(.headline)
               }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title3)
                } else {
                    Circle()
                        .stroke(Color.gray, lineWidth: 2)
                        .frame(width: 24, height: 24)
                }
            }
            .padding()
            .background(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }    
}

struct SpecializationsStepView: View {
    @Binding var selectedSpecializations: Set<Specialization>
    let selectedRoles: Set<Role>

    private var sortedSelectedRoles: [Role] {
        selectedRoles.sorted { Role.allCases.firstIndex(of: $0)! < Role.allCases.firstIndex(of: $1)! }
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("What specializations do you play?")
                .font(.title2)
                .fontWeight(.bold)

            Text("Select all that match the roles you chose.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(sortedSelectedRoles, id: \.self) { role in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(role.rawValue)
                                .font(.headline)

                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                                ForEach(Specialization.allCases.filter { $0.role == role }, id: \.self) { specialization in
                                    SpecializationSelectionButton(
                                        specialization: specialization,
                                        isSelected: selectedSpecializations.contains(specialization)
                                    ) {
                                        if selectedSpecializations.contains(specialization) {
                                            selectedSpecializations.remove(specialization)
                                        } else {
                                            selectedSpecializations.insert(specialization)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

struct SpecializationSelectionButton: View {
    let specialization: Specialization
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(specialization.rawValue)
                    .font(.subheadline)
                    .multilineTextAlignment(.leading)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(specialization.roleColor)
                        .font(.title3)
                } else {
                    Circle()
                        .stroke(Color.gray, lineWidth: 2)
                        .frame(width: 22, height: 22)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(isSelected ? specialization.roleColor.opacity(0.12) : Color(.systemGray6))
            .foregroundColor(isSelected ? specialization.roleColor : .primary)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? specialization.roleColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct AvailabilityStepView: View {
    @Binding var availableDays: Set<Day>
    @Binding var startTime: Date
    @Binding var endTime: Date

    var body: some View {
        VStack(spacing: 20) {
            Text("When are you available?")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Select the days and times you're typically available for raiding.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Available Days")
                    .font(.headline)
                
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
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Time Range")
                    .font(.headline)
                
                DatePicker("Start Time", selection: $startTime, displayedComponents: .hourAndMinute)
                DatePicker("End Time", selection: $endTime, displayedComponents: .hourAndMinute)
            }
        }
    }
}

struct TagsStepView: View {
    @Binding var selectedTags: Set<Tag>
    
    var body: some View {
        VStack(spacing: 20) {
            Text("What's your gaming style?")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Select all that describe your playstyle. This helps match you with like-minded guilds.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                ForEach(Tag.allCases, id: \.self) { tag in
                    TagSelectionButton(
                        tag: tag,
                        isSelected: selectedTags.contains(tag)
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
    }
}

struct TagSelectionButton: View {
    let tag: Tag
    let isSelected: Bool
    let action: () -> Void
    
    var tagColor: Color {
        switch tag {
        case .hardcore: return .red
        case .casual: return .green
        case .mythicPlus: return .purple
        case .raidFocused: return .orange
        case .pvp: return .blue
        case .roleplay: return .pink
        }
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(tag.rawValue)
                    .font(.headline)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .frame(maxWidth: .infinity, minHeight: 80)
            .background(isSelected ? tagColor.opacity(0.2) : Color(.systemGray6))
            .foregroundColor(isSelected ? tagColor : .primary)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? tagColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct RealmsStepView: View {
    @Binding var selectedRealms: Set<WoWRealm>
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Which realms do you play on?")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Select the realms where you're looking for a guild. You can select multiple.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                    ForEach(WoWRealm.allCases, id: \.self) { realm in
                        Button(action: {
                            if selectedRealms.contains(realm) {
                                selectedRealms.remove(realm)
                            } else {
                                selectedRealms.insert(realm)
                            }
                        }) {
                            Text(realm.rawValue)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(
                                    selectedRealms.contains(realm) ? Color.purple : Color.gray.opacity(0.2)
                                )
                                .foregroundColor(
                                    selectedRealms.contains(realm) ? .white : .primary
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

#Preview {
    let testUser = UserModel(name: "Test User", email: "test@example.com", countryRegion: "United States")
    OnboardingView(user: testUser, onComplete: {})
        .environmentObject(AuthenticationManager())
}
