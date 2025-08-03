//
//  ProfileInfoRow.swift
//  LFGuild
//
//  Created by George Suarez on 8/3/25.
//

import SwiftUI

struct ProfileInfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value.isEmpty ? "Not set" : value)
                .foregroundColor(value.isEmpty ? .secondary: .primary)
        }
    }
}

#Preview {
    ProfileInfoRow(title: "Test", value: "Test Value")
}
