//
//  LFGuildApp.swift
//  LFGuild
//
//  Created by George Suarez on 7/28/25.
//

import SwiftUI
import FirebaseCore

@main
struct LFGuildApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    init() {
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(NotificationRouter.shared)
        }
    }
}
