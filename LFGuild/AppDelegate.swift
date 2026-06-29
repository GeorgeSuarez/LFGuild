//
//  AppDelegate.swift
//  LFGuild
//
//  Created by George Suarez on 8/10/25.
//

import Foundation
import UIKit
import FirebaseAppCheck
import FirebaseAuth
import FirebaseFirestore
import FirebaseMessaging
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {

        configureAppCheck()

        // Register for remote notifications
        UNUserNotificationCenter.current().delegate = self

        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
        UNUserNotificationCenter.current().requestAuthorization(
            options: authOptions,
            completionHandler: { _, _ in }
        )

        application.registerForRemoteNotifications()

        Messaging.messaging().delegate = self

        return true
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

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // Remote notification registration failures are non-fatal.
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show notification while app is in foreground
        completionHandler([[.banner, .badge, .sound]])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo

        // Handle notification tap
        if let conversationId = userInfo["conversationId"] as? String {
            Task { @MainActor in
                NotificationRouter.shared.navigateToConversation(id: conversationId)
            }
        }

        if let guildId = userInfo["guildId"] as? String {
            Task { @MainActor in
                NotificationRouter.shared.navigateToGuild(id: guildId)
            }
        }

        completionHandler()
    }

    // MARK: - MessagingDelegate

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken = fcmToken else { return }
        storeFCMToken(fcmToken)
    }

    private func storeFCMToken(_ token: String) {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        let db = Firestore.firestore()
        db.collection("users").document(userId).updateData([
            "fcmToken": token,
            "tokenUpdatedAt": FieldValue.serverTimestamp()
        ]) { _ in }
    }
}
