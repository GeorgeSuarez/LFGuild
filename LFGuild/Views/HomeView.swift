//
//  HomeView.swift
//  LFGuild
//
//  Created by George Suarez on 7/28/25.
//

import SwiftUI

struct HomeView: View {
    var body: some View {
        VStack(alignment: .leading) {
            Text("Hello User!")
                .font(.largeTitle)
                .fontWeight(.bold)
        }
        .padding()
    }
}

#Preview {
    HomeView()
}
