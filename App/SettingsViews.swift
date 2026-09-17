import SwiftUI

struct MonitorComposer: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var url = ""; @State private var label = ""; @State private var frequency = "daily"
    @State private var device = "desktop"; @State private var threshold = 1.0
    @State private var notify = true; @State private var busy = false; @State private var error: String?
    var body: some View {
        NavigationStack {
            Form {
                Section { Text("Follow the details.\nCatch the changes.").font(.system(.title, design: .rounded, weight: .bold)).listRowBackground(Color.clear) }
                Section("The page") {
                    TextField("https://example.com", text: $url).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                    TextField("Album name (optional)", text: $label)
                    Picker("Device", selection: $device) { Text("Desktop").tag("desktop"); Text("Mobile").tag("mobile"); Text("Tablet").tag("tablet") }
                }
                Section("The rhythm") {
                    if let frequencies = store.profile?.frequencies, !frequencies.isEmpty {
                        Picker("Check", selection: $frequency) { ForEach(frequencies, id: \.self) { Text($0.capitalized).tag($0) } }
                    } else { Text("Your current plan does not include scheduled monitors.").foregroundStyle(.secondary) }
                    VStack(alignment: .leading) { Text("Visual change threshold: \(threshold, specifier: "%.1f")%"); Slider(value: $threshold, in: 0.1...20, step: 0.1).accessibilityLabel("Visual change threshold") }
                    Toggle("Email me when a change is found", isOn: $notify)
                }
                Section { Text("The first check establishes a baseline. Each scheduled check uses your existing capture allowance. Email alerts use the address on your account.").font(.footnote).foregroundStyle(.secondary) }
                if let error { Section { Text(error).foregroundStyle(.red) } }
                Section { Button { Task { await create() } } label: { HStack { if busy { ProgressView() }; Text("Create monitor") } }.disabled(busy || validatedWebsite(url) == nil || (store.profile?.frequencies.isEmpty ?? true)) }
            }.navigationTitle("New monitor").navigationBarTitleDisplayMode(.inline)
                .toolbar { Button("Cancel") { dismiss() }.disabled(busy) }
                .onAppear { frequency = store.profile?.frequencies.first ?? "daily" }
        }.interactiveDismissDisabled(busy)
    }
    private func create() async {
        guard let target = validatedWebsite(url) else { return }; busy = true; defer { busy = false }
        do {
            let _: Monitor = try await store.api.request("/api/watches", method: "POST", body: ["url": target.absoluteString, "label": label, "frequency": frequency, "device": device, "threshold": String(threshold), "notify_email": notify ? "1" : "0", "mode": "fullpage", "format": "png"])
            await store.refresh(); dismiss()
        } catch { self.error = error.localizedDescription }
    }
}
struct AccountView: View {
    @EnvironmentObject private var store: AppStore
    @State private var deleting = false; @State private var busy = false
    @State private var message: String?
    var body: some View {
        ScrollView { VStack(alignment: .leading, spacing: 24) {
            Eyebrow(text: "Your space")
            if let profile = store.profile {
                HStack(spacing: 18) {
                    Text(String((profile.user.name.isEmpty ? profile.user.email : profile.user.name).prefix(1)).uppercased()).font(.largeTitle.bold()).foregroundStyle(.white).frame(width: 76, height: 76).background(Palette.blue.gradient, in: RoundedRectangle(cornerRadius: 25))
                    VStack(alignment: .leading, spacing: 6) { Text(profile.user.name.isEmpty ? "Welcome" : profile.user.name).font(.title2.bold()); Text(profile.user.email).font(.subheadline).foregroundStyle(.secondary).textSelection(.enabled) }
                }
                Card { VStack(alignment: .leading, spacing: 16) {
                    HStack { Text("\(profile.plan) plan").font(.title2.bold()); Spacer(); Image(systemName: "circle.hexagongrid.fill").foregroundStyle(Palette.coral) }
                    Text("\(profile.usage.remaining) captures remaining").font(.headline)
                    ProgressView(value: Double(min(profile.usage.used, profile.usage.quota)), total: Double(max(1, profile.usage.quota))).tint(Palette.blue)
                    Text("\(profile.usage.used) of \(profile.usage.quota) used · Resets \(profile.usage.renewsOn)").font(.caption).foregroundStyle(.secondary)
                    Text("Your account and allowance stay in sync across devices.").font(.subheadline).foregroundStyle(.secondary)
                } }
                if !profile.verified { Card {
                    Text("Check your inbox").font(.headline)
                    Text("Verify your email to start capturing.").foregroundStyle(.secondary)
                    Button("Resend verification email") { Task {
                        busy = true; defer { busy = false }
                        do { let _: Acknowledgment = try await store.api.request("/api/auth/resend-verification", method: "POST", body: [:]); message = "Verification email requested. Check your inbox." } catch { store.error = error.localizedDescription }
                    } }.disabled(busy)
                } }
            } else { EmptyCard(symbol: "person.crop.circle", title: "Account details unavailable", detail: "Pull down to reconnect and load your plan.") }
            if let message { Text(message).font(.subheadline) }
            Card { VStack(alignment: .leading, spacing: 20) {
                Label("Alerts arrive by email", systemImage: "envelope").font(.headline)
                Text("Push notifications are not available in this version.").font(.subheadline).foregroundStyle(.secondary)
                Divider()
                Link(destination: API.base.appendingPathComponent("privacy")) { Label("Privacy policy", systemImage: "hand.raised") }
                Link(destination: API.base.appendingPathComponent("terms")) { Label("Terms of service", systemImage: "doc.text") }
            } }
            Button("Sign out") { Task { busy = true; await store.logout(); busy = false } }.buttonStyle(PrimaryButton()).disabled(busy)
            Button("Delete my account", role: .destructive) { deleting = true }.frame(maxWidth: .infinity)
            Text("Easy Screen Capture · Made for your pocket").font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity)
        }.padding(24).frame(maxWidth: 760) }.background(Palette.canvas).navigationTitle("Account").refreshable { await store.refresh() }.sheet(isPresented: $deleting) { DeleteAccountView() }
    }
}
struct DeleteAccountView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var password = ""; @State private var busy = false; @State private var confirm = false; @State private var error: String?
    var body: some View {
        NavigationStack { Form {
            Section { Text("Permanently delete your account?").font(.title2.bold()); Text("This deletes your account and captures and cancels an active subscription. This action cannot be undone.") }
            Section("Confirm your identity") { SecureField("Account password", text: $password).textContentType(.password) }
            if let error { Section { Text(error).foregroundStyle(.red) } }
            Section { Button("Delete my account", role: .destructive) { confirm = true }.disabled(password.isEmpty || busy); if busy { ProgressView("Deleting account…") } }
        }.navigationTitle("Delete account").toolbar { Button("Cancel") { dismiss() }.disabled(busy) }
            .confirmationDialog("This cannot be undone.", isPresented: $confirm, titleVisibility: .visible) {
                Button("Permanently delete account", role: .destructive) { Task {
                    busy = true; defer { busy = false; password = "" }
                    do { let _: Acknowledgment = try await store.api.request("/api/account", method: "DELETE", body: ["password": password]); SessionVault.clear(); store.reset(); dismiss() }
                    catch { self.error = error.localizedDescription }
                } }
            }
        }.interactiveDismissDisabled(busy)
    }
}
