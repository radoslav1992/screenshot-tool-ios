import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: AppStore
    @State private var tab = 0
    @State private var compose = false
    var body: some View {
        TabView(selection: $tab) {
            NavigationStack { OverviewView(compose: $compose) }.tabItem { Label("Today", systemImage: "sun.max") }.tag(0)
            NavigationStack { LibraryView() }.tabItem { Label("Library", systemImage: "rectangle.stack") }.tag(1)
            NavigationStack { MonitorsView() }.tabItem { Label("Monitors", systemImage: "waveform.path") }.tag(2)
            NavigationStack { AccountView() }.tabItem { Label("You", systemImage: "person.crop.circle") }.tag(3)
        }.task { await store.refresh(); if !store.incomingURL.isEmpty { compose = true } }
            .onChange(of: store.incomingURL) { _, value in if !value.isEmpty { compose = true } }
            .sheet(isPresented: $compose, onDismiss: { store.incomingURL = "" }) { CaptureComposer(initialURL: store.incomingURL) }
    }
}
struct OverviewView: View {
    @EnvironmentObject private var store: AppStore
    @Binding var compose: Bool
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack { Eyebrow(text: "Your daily perspective"); Spacer(); Image(systemName: "sparkle").foregroundStyle(Palette.coral) }
                Text("A little clarity.\nEvery day.").font(.system(.largeTitle, design: .rounded, weight: .bold))
                VStack(alignment: .leading, spacing: 22) {
                    HStack { Label("READY WHEN YOU ARE", systemImage: "viewfinder").font(.caption.bold()).tracking(1); Spacer() }
                    Text("Something worth\nkeeping?").font(.system(.title, design: .rounded, weight: .bold))
                    Button { compose = true } label: { HStack { Text("Capture a website"); Spacer(); Image(systemName: "arrow.up.right") }.font(.headline).padding(18).background(.white, in: RoundedRectangle(cornerRadius: 18)).foregroundStyle(Palette.ink) }
                }.foregroundStyle(.white).padding(26).background(LinearGradient(colors: [Palette.ink, Palette.blue], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 30))
                HStack(spacing: 14) {
                    Card { Text("\(store.monitors.filter { $0.status == "active" }.count)").font(.largeTitle.bold()).foregroundStyle(Palette.blue); Text("Active monitors").font(.subheadline).foregroundStyle(.secondary) }
                    Card { Text(store.profile.map { "\($0.usage.remaining)" } ?? "—").font(.largeTitle.bold()).foregroundStyle(Palette.coral); Text("Captures left").font(.subheadline).foregroundStyle(.secondary) }
                }
                if store.profile?.verified == false {
                    Card { Label("Verify your email", systemImage: "envelope.badge").font(.headline); Text("Open the verification link in your inbox, then pull down to refresh.").font(.subheadline).foregroundStyle(.secondary) }
                }
                HStack { Text("Recently collected").font(.title2.bold()); Spacer(); NavigationLink { LibraryView() } label: { Image(systemName: "arrow.right") }.accessibilityLabel("See library") }
                if store.captures.isEmpty { EmptyCard(symbol: "rectangle.stack.badge.plus", title: "Make your first capture", detail: "Save a page, a design, or a moment from the web.") }
                ForEach(store.captures.prefix(3)) { capture in NavigationLink { CaptureDetailView(capture: capture) } label: { CaptureCard(capture: capture) }.buttonStyle(.plain) }
            }.padding(22).frame(maxWidth: 760)
        }.background(Palette.canvas).navigationTitle("Easy Capture").navigationBarTitleDisplayMode(.inline).refreshable { await store.refresh() }
    }
}
struct CaptureCard: View {
    let capture: Capture
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ShotImage(url: capture.imageURL).frame(height: 180).clipped()
            VStack(alignment: .leading, spacing: 8) {
                Text(capture.display_url).font(.headline).lineLimit(2)
                HStack { Label(capture.device.capitalized, systemImage: "desktopcomputer"); Spacer(); Text(capture.format.uppercased()).font(.caption.bold()).foregroundStyle(Palette.blue) }.font(.caption).foregroundStyle(.secondary)
                Text(friendlyDate(capture.created_at)).font(.caption).foregroundStyle(.secondary)
                if capture.status != "done" { Label(capture.error ?? capture.status.capitalized, systemImage: "exclamationmark.circle").font(.caption).foregroundStyle(.orange) }
            }.padding(18)
        }.background(Palette.card).clipShape(RoundedRectangle(cornerRadius: 24))
    }
}
struct LibraryView: View {
    @EnvironmentObject private var store: AppStore
    @State private var search = ""
    @State private var compose = false
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                Eyebrow(text: "A collection of good finds")
                Text("Your web,\nwell kept.").font(.system(.largeTitle, design: .rounded, weight: .bold))
                Text("Manual captures live here. Scheduled screenshots stay in their monitor albums.").foregroundStyle(.secondary)
                if store.captures.isEmpty { EmptyCard(symbol: "rectangle.stack", title: "Room for inspiration", detail: "Tap + to capture your first website.") }
                ForEach(store.captures.filter { search.isEmpty || $0.url.localizedCaseInsensitiveContains(search) }) { capture in
                    NavigationLink { CaptureDetailView(capture: capture) } label: { CaptureCard(capture: capture) }.buttonStyle(.plain)
                }
                if store.canLoadMore { Button("Load more captures") { Task { await store.loadMore() } }.buttonStyle(PrimaryButton()).disabled(store.busy) }
                if !search.isEmpty { Text("Search applies to the captures loaded so far.").font(.caption).foregroundStyle(.secondary) }
            }.padding(22).frame(maxWidth: 760)
        }.background(Palette.canvas).navigationTitle("Library").searchable(text: $search, prompt: "Find a website")
            .toolbar { Button { compose = true } label: { Image(systemName: "plus") }.accessibilityLabel("New capture") }
            .sheet(isPresented: $compose) { CaptureComposer(initialURL: "") }.refreshable { await store.refresh() }
    }
}
struct CaptureComposer: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var url: String
    @State private var device = "desktop"; @State private var mode = "fullpage"
    @State private var busy = false; @State private var result: Capture?; @State private var error: String?
    init(initialURL: String) { _url = State(initialValue: initialURL) }
    var body: some View {
        NavigationStack {
            ScrollView { VStack(alignment: .leading, spacing: 24) {
                Eyebrow(text: "A new perspective")
                Text("Keep something\nworth seeing.").font(.system(.largeTitle, design: .rounded, weight: .bold))
                Card { VStack(alignment: .leading, spacing: 16) {
                    Text("Website address").font(.headline)
                    TextField("https://example.com", text: $url).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled().textFieldStyle(.roundedBorder)
                    Picker("Device", selection: $device) { Text("Desktop").tag("desktop"); Text("Mobile").tag("mobile"); Text("Tablet").tag("tablet") }.pickerStyle(.segmented)
                    Picker("Capture area", selection: $mode) { Text("Full page").tag("fullpage"); Text("Visible area").tag("visible") }
                } }
                Text("Captured securely in the cloud as a PNG. This uses your existing account allowance.").font(.subheadline).foregroundStyle(.secondary)
                if let error { Text(error).foregroundStyle(.red) }
                Button { Task { await capture() } } label: { HStack { if busy { ProgressView().tint(.white) }; Text(busy ? "Capturing the page…" : "Create capture"); if !busy { Image(systemName: "viewfinder") } } }.buttonStyle(PrimaryButton()).disabled(busy || validatedWebsite(url) == nil)
            }.padding(24) }.background(Palette.canvas).navigationTitle("New capture").navigationBarTitleDisplayMode(.inline)
                .toolbar { Button("Done") { dismiss() }.disabled(busy) }
                .navigationDestination(item: $result) { CaptureDetailView(capture: $0) }
        }.interactiveDismissDisabled(busy)
    }
    private func capture() async {
        guard let target = validatedWebsite(url) else { return }; busy = true; error = nil; defer { busy = false }
        do {
            let capture: Capture = try await store.api.request("/api/captures", method: "POST", body: ["url": target.absoluteString, "device": device, "mode": mode, "format": "png"])
            if capture.status == "error" { error = capture.error ?? "The page could not be captured." } else { result = capture; await store.refresh() }
        } catch { self.error = error.localizedDescription }
    }
}
extension Capture: Hashable {
    static func == (lhs: Capture, rhs: Capture) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
