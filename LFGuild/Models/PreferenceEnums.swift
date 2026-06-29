//
//  PreferenceEnums.swift
//  LFGuild
//
//  Created by George Suarez on 8/10/25.
//

import SwiftUI

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
