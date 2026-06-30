//
//  LFGuildApp.swift
//  LFGuild
//
//  Created by George Suarez on 7/28/25.
//

import SwiftUI
import FirebaseAppCheck
import FirebaseCore

@main
struct LFGuildApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    init() {
        configureAppCheck()
        FirebaseApp.configure()
    }
    
    /// Configures Firebase App Check. In DEBUG builds the debug provider is used so simulators
    /// and development devices can obtain App Check tokens. In release builds the default
    /// provider (DeviceCheck / App Attest) is used. App Check is not enforced in Firestore rules
    /// yet; this step only enables instrumentation and token generation.
    private func configureAppCheck() {
        #if DEBUG
        let providerFactory = AppCheckDebugProviderFactory()
        AppCheck.setAppCheckProviderFactory(providerFactory)
        #endif
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(NotificationRouter.shared)
        }
    }
}
