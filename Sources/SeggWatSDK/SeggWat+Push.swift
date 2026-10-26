import UIKit
import UserNotifications

/// Push notifications for chat replies, sent with the customer's own APNs key
/// configured in the SeggWat dashboard.
extension SeggWat {

    /// Turn on push notifications for support chat replies.
    ///
    /// The SDK asks the user for notification permission after they send their
    /// first chat message, never at launch. Your app delegate passes the device
    /// token to `setPushToken(_:)` and notification taps to
    /// `handleNotification(_:)`. Requires the Push Notifications capability and
    /// an APNs key in the project's settings.
    public static func enablePushNotifications() {
        shared.pushEnabled = true
        // Already allowed earlier: refresh the device token on every launch.
        Task { await shared.registerForRemoteNotificationsIfAuthorized() }
    }

    /// Pass the APNs device token from
    /// `application(_:didRegisterForRemoteNotificationsWithDeviceToken:)`.
    public static func setPushToken(_ deviceToken: Data) {
        shared.pushDeviceToken = deviceToken.map { String(format: "%02x", $0) }.joined()
        Task { await shared.syncPushRegistration() }
    }

    /// Handle a notification the user tapped. Opens the support chat and
    /// returns `true` if it was a SeggWat chat notification; returns `false`
    /// for your app's own notifications.
    @discardableResult
    public static func handleNotification(_ userInfo: [AnyHashable: Any]) -> Bool {
        guard isSeggWatNotification(userInfo) else { return false }
        presentChat()
        Task { await shared.refreshUnreadCount() }
        return true
    }

    /// Whether a notification payload was sent by SeggWat.
    public static func isSeggWatNotification(_ userInfo: [AnyHashable: Any]) -> Bool {
        userInfo["seggwat"] != nil
    }

    // MARK: - Internal

    func requestPushPermissionIfNeeded() async {
        guard pushEnabled else { return }
        let center = UNUserNotificationCenter.current()
        switch await center.notificationSettings().authorizationStatus {
        case .notDetermined:
            let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
            guard granted else { return }
        case .authorized, .provisional, .ephemeral:
            break
        default:
            return
        }
        UIApplication.shared.registerForRemoteNotifications()
    }

    func registerForRemoteNotificationsIfAuthorized() async {
        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        if [.authorized, .provisional, .ephemeral].contains(status) {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }

    /// Bring the server's registration in line with the current device token
    /// and chat identity: move it when the identity changes, drop it on
    /// sign-out. Best-effort; retried on the next token or identity change.
    func syncPushRegistration() async {
        let current = pushDeviceToken.flatMap { device in
            chatToken.map { PushRegistration(deviceToken: device, chatToken: $0) }
        }
        if let registered = registeredPush, registered != current {
            try? await apiClient?.unregisterPush(registered.payload(projectKey: projectKey))
            registeredPush = nil
        }
        guard let current, registeredPush == nil else { return }
        do {
            // The chat token is the current one, so this also runs App Attest
            // first if the project requires it.
            try await withChat { api, _ in
                try await api.registerPush(current.payload(projectKey: self.projectKey))
            }
            registeredPush = current
        } catch {}
    }

    /// Debug builds get sandbox device tokens from APNs; TestFlight and App
    /// Store builds get production ones.
    nonisolated static var apnsEnvironment: String {
        #if DEBUG
        "sandbox"
        #else
        "production"
        #endif
    }
}

/// A device token registered for a chat identity.
struct PushRegistration: Equatable {
    let deviceToken: String
    let chatToken: String

    func payload(projectKey: String) -> PushTokenPayload {
        PushTokenPayload(
            projectKey: projectKey,
            token: chatToken,
            deviceToken: deviceToken,
            environment: SeggWat.apnsEnvironment
        )
    }
}
