import UIKit
import FirebaseCore
import FirebaseMessaging
import UserNotifications

/// AppDelegate handles Firebase initialization and push notification setup
class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Configure Firebase
        FirebaseApp.configure()

        // Set up push notifications
        configureNotifications(application)

        // Set Firebase Messaging delegate
        Messaging.messaging().delegate = self

        return true
    }

    private func configureNotifications(_ application: UIApplication) {
        UNUserNotificationCenter.current().delegate = self

        // Request notification permissions
        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound, .criticalAlert]
        UNUserNotificationCenter.current().requestAuthorization(options: authOptions) { granted, error in
            if let error = error {
                print("Notification authorization error: \(error)")
            }
            print("Notification permission granted: \(granted)")
        }

        // Register for remote notifications
        application.registerForRemoteNotifications()
    }

    // MARK: - Remote Notification Registration

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        // Pass device token to Firebase Messaging
        Messaging.messaging().apnsToken = deviceToken

        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("APNs device token: \(tokenString)")
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("Failed to register for remote notifications: \(error)")
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension AppDelegate: UNUserNotificationCenterDelegate {

    /// Handle notification when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let userInfo = notification.request.content.userInfo
        print("Received notification in foreground: \(userInfo)")

        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }

    /// Handle notification tap
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        print("User tapped notification: \(userInfo)")

        // Handle different notification types
        if let type = userInfo["type"] as? String {
            handleNotification(type: type, userInfo: userInfo)
        }

        completionHandler()
    }

    private func handleNotification(type: String, userInfo: [AnyHashable: Any]) {
        switch type {
        case "friend_alarm":
            // Friend needs help waking up
            if let userId = userInfo["userId"] as? String {
                NotificationCenter.default.post(
                    name: .friendNeedsHelp,
                    object: nil,
                    userInfo: ["userId": userId]
                )
            }

        case "friend_request":
            // New friend request received
            NotificationCenter.default.post(
                name: .newFriendRequest,
                object: nil,
                userInfo: userInfo as? [String: Any] ?? [:]
            )

        case "friend_accepted":
            // Friend request was accepted
            NotificationCenter.default.post(
                name: .friendRequestAccepted,
                object: nil,
                userInfo: userInfo as? [String: Any] ?? [:]
            )

        default:
            print("Unknown notification type: \(type)")
        }
    }
}

// MARK: - MessagingDelegate

extension AppDelegate: MessagingDelegate {

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken = fcmToken else { return }

        print("FCM token: \(fcmToken)")

        // Store token for later use
        UserDefaults.standard.set(fcmToken, forKey: "fcmToken")

        // Post notification so AuthenticationService can update Firestore
        NotificationCenter.default.post(
            name: .fcmTokenReceived,
            object: nil,
            userInfo: ["token": fcmToken]
        )
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let fcmTokenReceived = Notification.Name("fcmTokenReceived")
    static let friendNeedsHelp = Notification.Name("friendNeedsHelp")
    static let newFriendRequest = Notification.Name("newFriendRequest")
    static let friendRequestAccepted = Notification.Name("friendRequestAccepted")
}
