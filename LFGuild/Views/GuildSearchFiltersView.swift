//
//  GuildSearchFiltersView.swift
//  LFGuild
//
//  Filter + sort sheet presented from GuildSearchView.
//

import SwiftUI

struct GuildSearchFiltersView: View {
    @Binding var filters: GuildSearchFilters
    @Environment(\.dismiss) private var dismiss

    private let factions = ["Alliance", "Horde"]
    private let regions = ["US", "OCE", "EU"]
    private let roles = Role.allCases.map { $0.rawValue }
    private let days = Day.allCases.map { $0.rawValue }
    private let tags = Tag.allCases.map { $0.rawValue }

    var body: some View {
        NavigationStack {
            Form {
                Section("Sort by") {
                    Picker("Sort", selection: $filters.sort) {
                        ForEach(GuildSearchSortOption.allCases) { option in
                            Text(option.label).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("Faction") {
                    ChipRow(options: factions, selected: $filters.factions)
                }

                Section("Region") {
                    ChipRow(options: regions, selected: $filters.regions)
                }

                Section("Member count") {
                    HStack {
                        TextField("Min", value: $filters.minMemberCount, format: .number)
                            .keyboardType(.numberPad)
                        TextField("Max", value: $filters.maxMemberCount, format: .number)
                            .keyboardType(.numberPad)
                    }
                }

                Section("Roles needed") {
                    ChipRow(options: roles, selected: $filters.neededRoles)
                }

                Section("Raid days") {
                    ChipRow(options: days, selected: $filters.raidDays)
                }

                Section("Tags") {
                    ChipRow(options: tags, selected: $filters.tags)
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Reset") { filters.clear() }
                        .disabled(filters.isDefault && filters.sort == .memberCount)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

/// A reusable horizontal chip row bound to a Set<String> selection.
private struct ChipRow: View {
    let options: [String]
    @Binding var selected: Set<String>

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(options, id: \.self) { option in
                let isSelected = selected.contains(option)
                Button {
                    if isSelected {
                        selected.remove(option)
                    } else {
                        selected.insert(option)
                    }
                } label: {
                    Text(option)
                        .font(.subheadline)
                        .fontWeight(isSelected ? .semibold : .regular)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(isSelected ? Color.blue.opacity(0.15) : Color(.systemGray6))
                        .foregroundStyle(isSelected ? .blue : .primary)
                        .clipShape(.rect(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            }
        }
    }
}

#Preview {
    GuildSearchFiltersView(filters: .constant(.empty))
}