//
//  MatchScorer.swift
//  LFGuild
//
//  Pure scoring logic that turns a user's preferences and a guild's profile
//  into a normalized 0–1 match score plus a per-factor breakdown. The
//  breakdown is reused by the matching pipeline and the "Why You Matched"
//  UI in CardDetailView so both stay in sync.
//

import Foundation

struct MatchScoreBreakdown: Equatable {
    // Weights sum to 1.0. Exposed so the UI can label each row.
    static let realmWeight: Double = 0.30
    static let roleWeight: Double  = 0.20
    static let specWeight: Double  = 0.10
    static let daysWeight: Double  = 0.20
    static let timeWeight: Double  = 0.10
    static let tagsWeight: Double  = 0.10

    var realm: Double  // 0...1 portion of the realm weight earned
    var role: Double   // 0...1 portion of the role weight earned
    var spec: Double   // 0...1 portion of the spec weight earned
    var days: Double   // 0...1 portion of the days weight earned
    var time: Double   // 0...1 portion of the time weight earned
    var tags: Double   // 0...1 portion of the tags weight earned

    /// The final 0–1 score.
    var total: Double {
        realm * Self.realmWeight
            + role * Self.roleWeight
            + spec * Self.specWeight
            + days * Self.daysWeight
            + time * Self.timeWeight
            + tags * Self.tagsWeight
    }

    /// Rows in display order, each with a label, 0–1 portion, weight, and points.
    var rows: [(label: String, portion: Double, weight: Double, points: Double)] {
        [
            ("Realm", realm, Self.realmWeight, realm * Self.realmWeight),
            ("Role", role, Self.roleWeight, role * Self.roleWeight),
            ("Specialization", spec, Self.specWeight, spec * Self.specWeight),
            ("Raid days", days, Self.daysWeight, days * Self.daysWeight),
            ("Time of day", time, Self.timeWeight, time * Self.timeWeight),
            ("Tags", tags, Self.tagsWeight, tags * Self.tagsWeight)
        ]
    }
}

enum MatchScorer {
    /// Returns a breakdown for the given user + guild. Pure function; safe to
    /// call from any actor.
    static func breakdown(user: UserModel, guild: GuildModel) -> MatchScoreBreakdown {
        // Realm: full credit if the guild's realm is among the user's preferred
        // realms; otherwise zero. Multiple preferred realms are all considered.
        let realmPortion = user.preferredRealms.contains(guild.serverRealm) ? 1.0 : 0.0

        // Role: fraction of the guild's needed roles the user can fill.
        let neededRoles = Set(guild.neededRoles)
        let userRoles = user.roles
        let rolePortion: Double
        if neededRoles.isEmpty || userRoles.isEmpty {
            rolePortion = neededRoles.isEmpty ? 1.0 : 0.0
        } else {
            rolePortion = Double(userRoles.intersection(neededRoles).count) / Double(neededRoles.count)
        }

        // Specialization: maps the user's selected specs to roles, then checks
        // how many of those roles the guild needs. Specs give finer-grained
        // credit on top of the role score.
        let specRoles = Set(user.specializations.compactMap { spec -> String? in
            Specialization(rawValue: spec)?.role.rawValue
        })
        let specPortion: Double
        if specRoles.isEmpty || neededRoles.isEmpty {
            specPortion = specRoles.isEmpty ? 0.0 : 1.0
        } else {
            specPortion = Double(specRoles.intersection(neededRoles).count) / Double(neededRoles.count)
        }

        // Days: fraction of the guild's raid days the user is available.
        let guildDays = Set(guild.raidDays)
        let userDays = user.availableDays
        let daysPortion: Double
        if guildDays.isEmpty || userDays.isEmpty {
            daysPortion = guildDays.isEmpty ? 1.0 : 0.0
        } else {
            daysPortion = Double(userDays.intersection(guildDays).count) / Double(guildDays.count)
        }

        // Time of day: overlap between the user's available window and the
        // guild's raid window. Times are stored as strings ("8:00 PM"); parse
        // to date components for comparison.
        let timePortion = timeOverlapPortion(
            userStart: user.availableStartTime,
            userEnd: user.availableEndTime,
            guildStart: guild.raidStartTime,
            guildEnd: guild.raidEndTime
        )

        // Tags: fraction of the guild's tags the user shares.
        let guildTags = Set(guild.tags)
        let userTags = user.gamingTags
        let tagsPortion: Double
        if guildTags.isEmpty || userTags.isEmpty {
            tagsPortion = guildTags.isEmpty ? 1.0 : 0.0
        } else {
            tagsPortion = Double(userTags.intersection(guildTags).count) / Double(guildTags.count)
        }

        return MatchScoreBreakdown(
            realm: realmPortion,
            role: rolePortion,
            spec: specPortion,
            days: daysPortion,
            time: timePortion,
            tags: tagsPortion
        )
    }

    // MARK: - Time overlap

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        // Support common stored formats: "8:00 PM", "20:00", "8:00 PM EST".
        formatter.timeStyle = .short
        return formatter
    }()

    /// Parses a free-form time string like "8:00 PM" into hour/minute. Returns
    /// nil when the value is empty or unparseable.
    private static func timeComponents(from string: String) -> (hours: Int, minutes: Int)? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // Strip trailing timezone tokens ("EST", "EDT", etc.) — date formatter
        // doesn't reliably parse them without a timezone context.
        let noTZ = trimmed
            .components(separatedBy: .whitespaces)
            .filter { $0.allSatisfy { $0.isNumber || $0 == ":" || $0 == "A" || $0 == "P" || $0 == "M" } }
            .joined(separator: " ")

        if let date = timeFormatter.date(from: noTZ) {
            let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
            if let h = comps.hour, let m = comps.minute {
                return (h, m)
            }
        }

        // Fallback: "HH:mm" 24-hour.
        let parts = noTZ.split(separator: ":")
        if parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]) {
            return (h, m)
        }
        return nil
    }

    private static func timeOverlapPortion(
        userStart: Date?,
        userEnd: Date?,
        guildStart: String,
        guildEnd: String
    ) -> Double {
        guard let userStart, let userEnd,
              let guildStart = timeComponents(from: guildStart),
              let guildEnd = timeComponents(from: guildEnd)
        else {
            // No window to compare; neutral — neither reward nor penalize.
            return 0.0
        }

        let cal = Calendar.current
        let now = Date()
        // Validate that the user window resolves to real hour/minute values.
        guard cal.date(bySettingHour: userStart.hourValue, minute: userStart.minuteValue, second: 0, of: now) != nil,
              cal.date(bySettingHour: userEnd.hourValue, minute: userEnd.minuteValue, second: 0, of: now) != nil
        else { return 0.0 }

        let gStartMin = guildStart.hours * 60 + guildStart.minutes
        let gEndMin = guildEnd.hours * 60 + guildEnd.minutes
        let uStartMin = userStart.hourValue * 60 + userStart.minuteValue
        let uEndMin = userEnd.hourValue * 60 + userEnd.minuteValue

        guard gEndMin > gStartMin, uEndMin > uStartMin else { return 0.0 }

        let overlap = max(0, min(uEndMin, gEndMin) - max(uStartMin, gStartMin))
        return Double(overlap) / Double(gEndMin - gStartMin)
    }
}

private extension Date {
    var hourValue: Int { Calendar.current.component(.hour, from: self) }
    var minuteValue: Int { Calendar.current.component(.minute, from: self) }
}