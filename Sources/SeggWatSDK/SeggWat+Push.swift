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
    /// for your app's own notifications. On a cold launch the chat opens once
    /// the app sets the chat identity.
    @discardableResult
    public static func handleNotification(_ userInfo: [AnyHashable: Any]) -> Bool {
        guard isSeggWatNotification(userInfo) else { return false }
        if shared.isChatAvailable {
            shared.isChatPresented = true
        } else {
            shared.pendingChatOpen = true
        }
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
    /// sign-out. Runs one pass at a time, again if something changed
    /// meanwhile, and retries a failed pass after a minute.
    func syncPushRegistration() async {
        pushSyncNeeded = true
        guard !pushSyncRunning else { return }
        pushSyncRunning = true
        defer { pushSyncRunning = false }
        while pushSyncNeeded {
            pushSyncNeeded = false
            do {
                try await reconcilePush()
            } catch {
                Task {
                    try? await Task.sleep(nanoseconds: 60_000_000_000)
                    await self.syncPushRegistration()
                }
                return
            }
        }
    }

    /// One reconciliation pass. The device token the server may hold is kept
    /// in `UserDefaults`, so a sign-out whose unregister failed, or happened
    /// in a later launch, still removes it.
    private func reconcilePush() async throws {
        guard let apiClient else { return }
        let desired = pushDeviceToken.flatMap { device in
            chatToken.map { PushRegistration(deviceToken: device, chatToken: $0) }
        }
        let stored = UserDefaults.standard.string(forKey: Self.registeredDeviceKey)
        // Without a device token yet (early in launch) there is nothing to
        // compare against, unless the user signed out.
        if let stored, pushDeviceToken != nil || chatToken == nil,
           stored != desired?.deviceToken {
            try await apiClient.unregisterPush(
                PushUnregisterPayload(projectKey: projectKey, deviceToken: stored)
            )
            UserDefaults.standard.removeObject(forKey: Self.registeredDeviceKey)
            registeredPush = nil
        }
        guard let desired, desired != registeredPush else { return }
        // Registering moves the device to the new identity on the server. The
        // chat token is the current one, so this also runs App Attest first if
        // the project requires it.
        try await withChat { api, _ in
            try await api.registerPush(desired.payload(projectKey: self.projectKey))
        }
        registeredPush = desired
        UserDefaults.standard.set(desired.deviceToken, forKey: Self.registeredDeviceKey)
    }

    private static let registeredDeviceKey = "com.seggwat.sdk.pushDevice"

    /// The APNs environment this build's device tokens belong to. Read from
    /// the `aps-environment` entitlement in the embedded provisioning profile:
    /// Xcode builds are signed for development (sandbox); App Store and
    /// TestFlight builds have no embedded profile and use production.
    nonisolated static let apnsEnvironment: String = {
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let data = try? Data(contentsOf: url) else {
            return "production"
        }
        return apsEnvironment(inProvisioningProfile: data) == "development" ? "sandbox" : "production"
    }()

    /// The `aps-environment` entitlement of a provisioning profile (a signed
    /// CMS blob around a plain-text plist).
    nonisolated static func apsEnvironment(inProvisioningProfile data: Data) -> String? {
        guard let text = String(data: data, encoding: .isoLatin1),
              let start = text.range(of: "<?xml"),
              let end = text.range(of: "</plist>", range: start.lowerBound..<text.endIndex),
              let plist = try? PropertyListSerialization.propertyList(
                  from: Data(text[start.lowerBound..<end.upperBound].utf8), format: nil
              ) as? [String: Any],
              let entitlements = plist["Entitlements"] as? [String: Any] else {
            return nil
        }
        return entitlements["aps-environment"] as? String
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
