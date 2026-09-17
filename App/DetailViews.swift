import SwiftUI
import Photos
import UIKit

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: items, applicationActivities: nil) }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
struct CaptureDetailView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let capture: Capture
    @State private var busy = false; @State private var delete = false
    @State private var shared: UIImage?; @State private var showShare = false; @State private var message: String?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Eyebrow(text: capture.mode == "fullpage" ? "The complete picture" : "A moment, preserved")
                Text(capture.display_url).font(.title2.bold()).textSelection(.enabled)
                Text(friendlyDate(capture.created_at)).font(.subheadline).foregroundStyle(.secondary)
                ForEach(Array(capture.images.enumerated()), id: \.offset) { _, source in
                    AsyncImage(url: URL(string: source)) { phase in
                        if let image = phase.image { image.resizable().scaledToFit() }
                        else if phase.error != nil { ContentUnavailableView("Image unavailable", systemImage: "photo", description: Text("The file may have expired. Pull down to try again.")) }
                        else { ProgressView().frame(maxWidth: .infinity).frame(height: 240) }
                    }.clipShape(RoundedRectangle(cornerRadius: 20))
                }
                if let error = capture.error { Text(error).foregroundStyle(.red) }
                if !capture.images.isEmpty {
                    HStack {
                        Button { Task { await export(save: false) } } label: { Label("Share image", systemImage: "square.and.arrow.up") }
                        Spacer()
                        Button { Task { await export(save: true) } } label: { Label("Save", systemImage: "square.and.arrow.down") }
                    }.font(.headline).disabled(busy)
                    if capture.images.count > 1 { Text("Save and share export the first image.").font(.caption).foregroundStyle(.secondary) }
                }
                if busy { ProgressView("Preparing image…") }
                if let message { Text(message).font(.subheadline).foregroundStyle(.secondary) }
                Button("Delete capture", role: .destructive) { delete = true }.padding(.top)
            }.padding(22).frame(maxWidth: 850)
        }.background(Palette.canvas).navigationTitle("Capture").navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showShare) { if let shared { ShareSheet(items: [shared]) } }
            .confirmationDialog("Permanently delete this capture?", isPresented: $delete, titleVisibility: .visible) {
                Button("Delete capture", role: .destructive) { Task {
                    do { let _: Acknowledgment = try await store.api.request("/api/captures/\(capture.id)", method: "DELETE"); await store.refresh(); dismiss() }
                    catch { store.error = error.localizedDescription }
                } }
            }
    }
    private func export(save: Bool) async {
        guard let url = capture.imageURL else { return }; busy = true; defer { busy = false }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200, let image = UIImage(data: data) else { throw APIError(status: 0, message: "This image is unavailable or has expired.") }
            if save {
                let permission = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
                guard permission == .authorized || permission == .limited else { throw APIError(status: 0, message: "Allow access to add photos in iOS Settings, then try again.") }
                try await PHPhotoLibrary.shared().performChanges { PHAssetChangeRequest.creationRequestForAsset(from: image) }
                message = "Saved to Photos."
            } else { shared = image; showShare = true }
        } catch { store.error = error.localizedDescription }
    }
}
struct MonitorsView: View {
    @EnvironmentObject private var store: AppStore
    @State private var create = false
    var body: some View {
        ScrollView { LazyVStack(alignment: .leading, spacing: 20) {
            Eyebrow(text: "Less checking. More knowing.")
            Text("Stay in the know.").font(.system(.largeTitle, design: .rounded, weight: .bold))
            Text("A dedicated album for every page you follow.").foregroundStyle(.secondary)
            if store.monitors.isEmpty { EmptyCard(symbol: "waveform.path", title: "Let the web come to you", detail: "Follow a page to collect its changes over time. Monitor availability follows your account plan.") }
            ForEach(store.monitors) { monitor in NavigationLink { MonitorAlbumView(monitor: monitor) } label: {
                Card { VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Image(systemName: "rectangle.stack.fill").font(.title).foregroundStyle(Palette.blue).padding(14).background(Palette.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 18))
                        Spacer()
                        Label(monitor.status.capitalized, systemImage: monitor.status == "active" ? "waveform.path" : "pause.fill").font(.caption.bold()).foregroundStyle(monitor.status == "active" ? Palette.blue : .secondary)
                    }
                    Text(monitor.title).font(.title3.bold()).lineLimit(2)
                    Text(monitor.display_url).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                    Divider()
                    HStack { Text(monitor.frequency.capitalized); Spacer(); Text("Open album"); Image(systemName: "arrow.up.right") }.font(.caption.bold()).foregroundStyle(Palette.blue)
                    if let error = monitor.last_error { Text(error).font(.caption).foregroundStyle(.orange) }
                } }
            }.buttonStyle(.plain) }
        }.padding(22).frame(maxWidth: 760) }.background(Palette.canvas).navigationTitle("Monitors")
            .toolbar { Button { create = true } label: { Image(systemName: "plus") }.accessibilityLabel("New monitor") }
            .sheet(isPresented: $create) { MonitorComposer() }.refreshable { await store.refresh() }
    }
}
struct MonitorAlbumView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let monitor: Monitor
    @State private var runs: [Run] = []; @State private var shots: [Capture] = []
    @State private var changedOnly = false; @State private var loading = true; @State private var busy = false
    @State private var showDelete = false; @State private var showRun = false
    @State private var status = ""; @State private var frequency = ""
    @State private var error: String?; @State private var loaded = false
    var body: some View {
        ScrollView { LazyVStack(alignment: .leading, spacing: 20) {
            Eyebrow(text: "Monitor album")
            Text(monitor.title).font(.system(.largeTitle, design: .rounded, weight: .bold))
            Text(monitor.display_url).foregroundStyle(.secondary)
            HStack {
                Button(status == "paused" ? "Resume" : "Pause") { Task { await action(status == "paused" ? "resume" : "pause") } }
                Spacer(); Button("Check now") { showRun = true }
            }.buttonStyle(.bordered).disabled(busy || !loaded)
            if let frequencies = store.profile?.frequencies, !frequencies.isEmpty {
                HStack { Text("Schedule"); Spacer(); Menu(frequency.capitalized) {
                    ForEach(frequencies, id: \.self) { value in Button(value.capitalized) { Task { await action("schedule", newFrequency: value) } } }
                }.disabled(busy || !loaded) }
            }
            Toggle("Only show changes", isOn: $changedOnly)
            if loading { ProgressView("Opening album…") }
            if let error { Text(error).foregroundStyle(.red); Button("Try again") { Task { await load() } } }
            if !loading && runs.isEmpty && error == nil { EmptyCard(symbol: "clock", title: "Waiting for the first check", detail: "Your first scheduled check establishes the baseline. Later checks can reveal changes.") }
            ForEach(runs.filter { !changedOnly || $0.changed == 1 }) { run in
                VStack(alignment: .leading, spacing: 12) {
                    HStack { Circle().fill(run.changed == 1 ? Palette.coral : Palette.blue).frame(width: 8, height: 8); Text(run.changed == 1 ? "Change detected" : run.status.capitalized).font(.headline); Spacer(); if let pct = run.change_pct { Text(String(format: "%.1f%%", pct)).font(.caption.monospacedDigit()).foregroundStyle(Palette.coral) } }
                    Text(friendlyDate(run.created_at)).font(.caption).foregroundStyle(.secondary)
                    if let capture = shots.first(where: { $0.id == run.capture_id }) {
                        NavigationLink { CaptureDetailView(capture: capture) } label: { ShotImage(url: capture.imageURL).frame(height: 160).clipped().clipShape(RoundedRectangle(cornerRadius: 16)) }
                    }
                    if let current = run.capture_id, let baseline = run.baseline_capture_id {
                        NavigationLink { ComparisonView(beforeID: baseline, afterID: current) } label: { Label("Compare before & after", systemImage: "rectangle.split.2x1") }.font(.subheadline.bold())
                    }
                }.padding(18).background(Palette.card, in: RoundedRectangle(cornerRadius: 24))
            }
            Text("Showing up to 30 recent checks. Older history remains available on the website.").font(.caption).foregroundStyle(.secondary)
            Button("Delete monitor", role: .destructive) { showDelete = true }.disabled(busy)
        }.padding(22).frame(maxWidth: 760) }.background(Palette.canvas).navigationTitle("Album").navigationBarTitleDisplayMode(.inline)
            .task { status = monitor.status; frequency = monitor.frequency; await load() }.refreshable { await load() }
            .confirmationDialog("Run a check now? This uses your capture allowance.", isPresented: $showRun, titleVisibility: .visible) { Button("Run check") { Task { await action("run") } } }
            .confirmationDialog("Delete this monitor? Scheduled checks will stop.", isPresented: $showDelete, titleVisibility: .visible) { Button("Delete monitor", role: .destructive) { Task {
                busy = true; defer { busy = false }
                do { let _: Acknowledgment = try await store.api.request("/api/watches/\(monitor.id)", method: "DELETE"); await store.refresh(); dismiss() } catch { self.error = error.localizedDescription }
            } } }
    }
    private func load() async {
        loading = true; error = nil; defer { loading = false }
        do {
            let detail: MonitorDetail = try await store.api.request("/api/watches/\(monitor.id)")
            let album: ListResponse<Capture> = try await store.api.request("/api/captures?collection=monitors&watch_id=\(monitor.id)&limit=100")
            runs = detail.runs; shots = album.data; loaded = true
        } catch { self.error = error.localizedDescription }
    }
    private func action(_ action: String, newFrequency: String? = nil) async {
        busy = true; defer { busy = false }
        do {
            var body = ["action": action]; if let newFrequency { body["frequency"] = newFrequency }
            let updated: Monitor = try await store.api.request("/api/watches/\(monitor.id)", method: "POST", body: body)
            status = updated.status; frequency = updated.frequency; await load(); await store.refresh()
        } catch { self.error = error.localizedDescription }
    }
}
struct ComparisonView: View {
    @EnvironmentObject private var store: AppStore
    let beforeID: String; let afterID: String
    @State private var before: Capture?; @State private var after: Capture?
    @State private var error: String?; @State private var selection = 0
    var body: some View {
        ScrollView { VStack(spacing: 20) {
            Picker("Comparison", selection: $selection) { Text("Before").tag(0); Text("After").tag(1) }.pickerStyle(.segmented)
            if let shot = selection == 0 ? before : after {
                Text(friendlyDate(shot.created_at)).font(.caption).foregroundStyle(.secondary)
                AsyncImage(url: shot.imageURL) { phase in
                    if let image = phase.image { image.resizable().scaledToFit() }
                    else if phase.error != nil { Text("This image is no longer available.") }
                    else { ProgressView() }
                }.clipShape(RoundedRectangle(cornerRadius: 20))
            } else if error == nil { ProgressView("Loading comparison…") }
            if let error { Text(error).foregroundStyle(.red) }
        }.padding(22) }.background(Palette.canvas).navigationTitle("Before & after").navigationBarTitleDisplayMode(.inline).task {
            do { before = try await store.api.request("/api/captures/\(beforeID)"); after = try await store.api.request("/api/captures/\(afterID)") }
            catch { self.error = error.localizedDescription }
        }
    }
}
