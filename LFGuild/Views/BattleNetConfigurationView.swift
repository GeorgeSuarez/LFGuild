//
//  BattleNetConfigurationView.swift
//  LFGuild
//
//  Created by George Suarez on 8/6/25.
//

import SwiftUI

// MARK: - Environment Configuration View (for development)
struct BattleNetConfigurationView: View {
    @StateObject private var config = BattleNetConfigurationService.shared
    
    var body: some View {
        VStack(spacing: 20) {
            if config.isConfigured {
                Label("Battle.net API Configured", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else {
                VStack(spacing: 12) {
                    Label("Battle.net API Not Configured", systemImage: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    
                    Text("Please set environment variables:")
                        .font(.caption)
                    
                    Text("BATTLENET_CLIENT_ID\nBATTLENET_CLIENT_SECRET")
                        .font(.system(.caption, design: .monospaced))
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
            }
        }
        .padding()
    }
}

#Preview {
    BattleNetConfigurationView()
}
