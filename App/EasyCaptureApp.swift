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
                ZStack(alignment: .bottomLeading) {
                    RoundedRectangle(cornerRadius: 36).fill(Palette.ink.gradient)
                    Circle().fill(Palette.coral).frame(width: 160, height: 160).offset(x: 180, y: -100)
                    VStack(alignment: .leading, spacing: 14) {
                        Image(systemName: "viewfinder").font(.system(size: 54, weight: .light))
                        Text("The web moves.\nKeep the moments.").font(.system(.largeTitle, design: .rounded, weight: .bold))
                        Text("Capture beautifully. Follow every change.").font(.subheadline).foregroundStyle(.white.opacity(0.75))
                    }.foregroundStyle(.white).padding(28)
                }.frame(height: 300).clipped().clipShape(RoundedRectangle(cornerRadius: 36)).accessibilityElement(children: .combine)
                VStack(alignment: .leading, spacing: 16) {
                    Text(register ? "Your collection starts here." : "Welcome back.").font(.title2.bold())
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
