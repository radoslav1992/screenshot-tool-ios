import SwiftUI

@main struct EasyCaptureApp: App {
    @UIApplicationDelegateAdaptor(PushAppDelegate.self) private var pushDelegate
    @StateObject private var store = AppStore()
    @Environment(\.scenePhase) private var scenePhase
    var body: some Scene {
        WindowGroup {
            Group { if store.signedIn { HomeView() } else { WelcomeView() } }
                .environmentObject(store).tint(Palette.blue)
                .alert("Something needs attention", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) {
                    Button("OK", role: .cancel) { store.error = nil }
                } message: { Text(store.error ?? "") }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { consumeSharedURL(); Task { await PushNotifications.shared.refresh() } }
                }
                .onAppear { PushNotifications.shared.connect(store); consumeSharedURL() }
                .onOpenURL { url in
                    guard url.scheme == "easycapture", url.host == "capture",
                          let raw = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "url" })?.value,
                          let website = validatedWebsite(raw) else { return }
                    store.incomingURL = website.absoluteString
                }
        }
    }
    private func consumeSharedURL() {
        guard let group = Bundle.main.object(forInfoDictionaryKey: "AppGroupIdentifier") as? String,
              let defaults = UserDefaults(suiteName: group),
              let raw = defaults.string(forKey: "pendingCaptureURL"), let url = validatedWebsite(raw) else { return }
        defaults.removeObject(forKey: "pendingCaptureURL")
        store.incomingURL = url.absoluteString
    }
}
struct WelcomeView: View {
    @EnvironmentObject private var store: AppStore
    @State private var register = false
    @State private var email = ""; @State private var password = ""; @State private var name = ""
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                HStack { Image(systemName: "viewfinder").font(.title); Text("EASY CAPTURE").font(.caption.bold()).tracking(3); Spacer() }.foregroundStyle(Palette.blue)
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Label("WEBSITE SCREENSHOTS", systemImage: "camera")
                            .font(.caption.bold()).tracking(1)
                        Spacer()
                        Image(systemName: "sparkle").foregroundStyle(Palette.coral)
                    }
                    Text("The whole page.\nIn your pocket.")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Turn any public website into a full-page screenshot. Save it, share it, and keep it in your library.")
                        .font(.subheadline).foregroundStyle(.white.opacity(0.85))
                    HStack(spacing: 16) {
                        Label("Full page", systemImage: "arrow.down.doc")
                        Label("Save & share", systemImage: "square.and.arrow.up")
                    }.font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.9))
                }
                .foregroundStyle(.white).padding(26)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Palette.ink.gradient, in: RoundedRectangle(cornerRadius: 30))
                .accessibilityElement(children: .combine)
                VStack(alignment: .leading, spacing: 16) {
                    Text(register ? "Your first screenshot starts here." : "Sign in to start capturing.").font(.title2.bold())
                    if register { TextField("Your name", text: $name).textContentType(.name).padding().background(Palette.card, in: RoundedRectangle(cornerRadius: 14)) }
                    TextField("Email address", text: $email).textContentType(.emailAddress).keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled().padding().background(Palette.card, in: RoundedRectangle(cornerRadius: 14))
                    SecureField("Password", text: $password).textContentType(register ? .newPassword : .password).padding().background(Palette.card, in: RoundedRectangle(cornerRadius: 14))
                    if register { Text("Use at least 8 characters. We’ll email you a verification link.").font(.footnote).foregroundStyle(.secondary) }
                    Button { Task { await store.authenticate(email: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password, name: name, register: register); password = "" } } label: {
                        HStack { if store.busy { ProgressView().tint(.white) }; Text(register ? "Create free account" : "Sign in"); Image(systemName: "arrow.right") }
                    }.buttonStyle(PrimaryButton()).disabled(store.busy || email.isEmpty || password.isEmpty || (register && password.count < 8))
                    Button(register ? "Already have an account? Sign in" : "New here? Create an account") { register.toggle() }.frame(maxWidth: .infinity)
                    HStack { Link("Privacy", destination: API.base.appendingPathComponent("privacy")); Text("·"); Link("Terms", destination: API.base.appendingPathComponent("terms")) }.font(.footnote).frame(maxWidth: .infinity)
                }
            }.padding(24).frame(maxWidth: 560)
        }.background(Palette.canvas).scrollDismissesKeyboard(.interactively)
    }
}
