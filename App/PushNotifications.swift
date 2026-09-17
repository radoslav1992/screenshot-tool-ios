import SwiftUI
import UserNotifications
import UIKit

struct PushAvailability: Decodable { let available: Bool }
@MainActor final class PushNotifications: ObservableObject {
    static let shared = PushNotifications()
    @Published var enabled = false
    @Published var busy = false
    @Published var status = "Enable alerts for changes to your monitored pages."
    @Published var targetWatchID: String?
    private weak var store: AppStore?
    private var token: String?
    private var registration: String?
    private var wanted: Bool {
        get { UserDefaults.standard.bool(forKey: "pushOptIn") }
        set { UserDefaults.standard.set(newValue, forKey: "pushOptIn") }
    }
    func connect(_ store: AppStore) { self.store = store }
    func enable() async {
        guard let store, store.signedIn else { return }
        busy = true; defer { busy = false }
        do {
            let availability: PushAvailability = try await store.api.request("/api/mobile/push")
            guard availability.available else { status = "Push delivery is not configured on the server yet."; return }
            let allowed = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            guard allowed else { status = "Notifications are off in iOS Settings."; return }
            wanted = true; status = "Registering this device…"
            UIApplication.shared.registerForRemoteNotifications()
        } catch { status = error.localizedDescription }
    }
    func refresh() async {
        guard let store, store.signedIn else { return }
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        let allowed = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
        if !allowed && wanted {
            do { let _: Acknowledgment = try await store.api.request("/api/mobile/push", method: "DELETE") }
            catch { status = "Notifications are off. Server cleanup will be retried when you reconnect."; return }
            stopLocal(); status = "Notifications are off in iOS Settings."
        } else if wanted && allowed { UIApplication.shared.registerForRemoteNotifications() }
    }
    func received(_ data: Data) async {
        token = data.map { String(format: "%02x", $0) }.joined()
        guard wanted, let token, let store, store.signedIn, let session = SessionVault.read() else { return }
        let marker = session + token
        guard registration != marker else { return }
        #if DEBUG
        let environment = "sandbox"
        #else
        let environment = "production"
        #endif
        do {
            let _: Acknowledgment = try await store.api.request("/api/mobile/push", method: "POST", body: ["token": token, "environment": environment])
            guard store.signedIn, SessionVault.read() == session, wanted else { return }
            registration = marker; enabled = true; status = "Change alerts are enabled on this device."
        } catch { enabled = false; status = error.localizedDescription }
    }
    func disable() async {
        guard let store else { return }; busy = true; defer { busy = false }
        do { let _: Acknowledgment = try await store.api.request("/api/mobile/push", method: "DELETE"); stopLocal(); status = "Push notifications are off." }
        catch { status = "Could not update the server. Try again when connected, or turn notifications off in iOS Settings." }
    }
    func stopLocal() {
        wanted = false; enabled = false; token = nil; registration = nil; targetWatchID = nil
        UIApplication.shared.unregisterForRemoteNotifications()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }
    func failedRegistration() { enabled = false; status = "Apple could not register this device. Check signing and connectivity, then try again." }
}
final class PushAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self; return true
    }
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Task { @MainActor in await PushNotifications.shared.received(deviceToken) }
    }
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        Task { @MainActor in PushNotifications.shared.failedRegistration() }
    }
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .list])
    }
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        if let watchID = response.notification.request.content.userInfo["watch_id"] as? String,
           watchID.range(of: "^[A-Za-z0-9_-]{1,100}$", options: .regularExpression) != nil {
            Task { @MainActor in PushNotifications.shared.targetWatchID = watchID }
        }
        completionHandler()
    }
}
struct PushSettingsView: View {
    @ObservedObject private var push = PushNotifications.shared
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Push notifications", systemImage: "bell.badge").font(.headline)
            Text(push.status).font(.subheadline).foregroundStyle(.secondary)
            Button(push.enabled ? "Turn off on this device" : "Enable change alerts") {
                Task { if push.enabled { await push.disable() } else { await push.enable() } }
            }.disabled(push.busy)
            Button("Open notification settings") {
                if let url = URL(string: UIApplication.openNotificationSettingsURLString) { UIApplication.shared.open(url) }
            }.font(.footnote)
            Text("Email alerts remain independent. Lock-screen alerts do not include page content.").font(.caption).foregroundStyle(.secondary)
        }
    }
}
struct PushDestinationView: View {
    @EnvironmentObject private var store: AppStore
    let watchID: String
    @State private var monitor: Monitor?
    @State private var error: String?
    var body: some View {
        NavigationStack {
            Group {
                if let monitor { MonitorAlbumView(monitor: monitor) }
                else if let error { ContentUnavailableView("Monitor unavailable", systemImage: "bell.slash", description: Text(error)) }
                else { ProgressView("Opening monitor…") }
            }.task {
                do { monitor = try await store.api.request("/api/watches/\(watchID)") }
                catch { self.error = error.localizedDescription }
            }.toolbar { Button("Done") { PushNotifications.shared.targetWatchID = nil } }
        }
    }
}
