import SwiftUI
import StoreKit

struct PurchaseConfiguration: Decodable {
    let available: Bool
    let productIds: [String]
    let appAccountToken: UUID?
    let canPurchase: Bool
}
struct PurchaseAccess: Decodable { let active: Bool }

@MainActor final class Purchases: ObservableObject {
    static let shared = Purchases()
    @Published var products: [Product] = []
    @Published var configuration: PurchaseConfiguration?
    @Published var busy = false
    @Published var message: String?
    private weak var store: AppStore?
    private var updates: Task<Void, Never>?
    private var restoreTask: Task<Void, Never>?
    private var restoreTimeout: Task<Void, Never>?
    private var restoreID: UUID?
    @Published private(set) var restoring = false
    @Published private(set) var restoreProgress = "Restoring purchases…"

    func cancelRestore() {
        guard restoreID != nil else { return }
        finishRestore(message: "Restore stopped. You can try again when you’re ready.")
    }

    private func finishRestore(message: String?) {
        // Invalidate first: late StoreKit completions must not change a newer attempt.
        restoreID = nil
        restoreTask?.cancel(); restoreTask = nil
        restoreTimeout?.cancel(); restoreTimeout = nil
        restoring = false; busy = false
        self.message = message
    }
    private let identifiers = ["com.easyscreencapture.ios.lite.monthly", "com.easyscreencapture.ios.lite.yearly"]

    func connect(_ store: AppStore) async {
        self.store = store
        if updates == nil {
            updates = Task { [weak self] in
                for await result in StoreKit.Transaction.updates {
                    guard !Task.isCancelled else { return }
                    guard case .verified(let transaction) = result else { continue }
                    do { try await self?.deliver(transaction) }
                    catch { self?.message = "Your purchase needs syncing. Open You → Lite → Restore purchases." }
                }
            }
        }
        await load()
        if configuration?.available == true { await syncCurrent() }
    }
    func stop() {
        if restoring { finishRestore(message: nil) }
        updates?.cancel(); updates = nil; store = nil
        products = []; configuration = nil; message = nil
    }
    func load() async {
        guard let store, store.signedIn else { return }
        do {
            let config: PurchaseConfiguration = try await store.api.request("/api/mobile/purchases")
            configuration = config
            guard config.available else { products = []; return }
            products = try await Product.products(for: config.productIds).sorted { $0.price < $1.price }
            if products.isEmpty { message = "Subscriptions are not available from the App Store yet. You can continue using your current allowance." }
        } catch { message = error.localizedDescription }
    }
    func buy(_ product: Product) async {
        guard !busy, let store else { return }
        busy = true; message = nil; defer { busy = false }
        do {
            // Recheck eligibility immediately before presenting Apple's purchase sheet.
            let config: PurchaseConfiguration = try await store.api.request("/api/mobile/purchases")
            configuration = config
            guard config.canPurchase, let token = config.appAccountToken else {
                message = "You already have a paid plan. Manage your existing subscription instead."; return
            }
            switch try await product.purchase(options: [.appAccountToken(token)]) {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    message = "Apple could not verify the purchase. Please try Restore purchases."; return
                }
                try await deliver(transaction)
                await load()
                message = "Purchase synced. Your allowance is updated."
            case .pending: message = "Your purchase is awaiting approval. Access updates once Apple approves it."
            case .userCancelled: break
            @unknown default: message = "Please check your subscription status and try Restore purchases."
            }
        } catch { message = error.localizedDescription }
    }
    func restore() async {
        guard !busy, let store, store.signedIn else { return }
        let id = UUID()
        restoreID = id
        restoring = true; busy = true; message = nil
        restoreProgress = "Connecting to the App Store…"
        // Independent watchdog: a task group would wait for an uncooperative
        // StoreKit child even after cancellation, leaving the UI blocked.
        restoreTimeout = Task { [weak self] in
            do { try await Task.sleep(nanoseconds: 45_000_000_000) }
            catch { return }
            guard let self, self.restoreID == id else { return }
            self.finishRestore(message: "Restore took too long. Please check your connection and try again. Your existing subscription has not been canceled.")
        }
        restoreTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await StoreKit.AppStore.sync()
                try Task.checkCancellation()
                guard self.restoreID == id else { return }
                self.restoreProgress = "Checking your purchases…"
                var active = false
                for await result in StoreKit.Transaction.currentEntitlements {
                    try Task.checkCancellation()
                    guard self.restoreID == id else { return }
                    guard case .verified(let transaction) = result,
                          self.identifiers.contains(transaction.productID) else { continue }
                    self.restoreProgress = "Verifying your subscription…"
                    let access = try await self.deliver(transaction, refreshProfile: false)
                    active = active || access
                }
                try Task.checkCancellation()
                guard self.restoreID == id else { return }
                self.restoreProgress = "Updating your account…"
                // Restore needs the account and eligibility, not product prices or
                // the capture/monitor libraries. Avoid unrelated waits here.
                let profile: Profile = try await store.api.request("/api/mobile/profile")
                try Task.checkCancellation()
                guard self.restoreID == id, store.signedIn else { return }
                store.profile = profile
                let config: PurchaseConfiguration = try await store.api.request("/api/mobile/purchases")
                try Task.checkCancellation()
                guard self.restoreID == id else { return }
                self.configuration = config
                self.finishRestore(message: active ? "Purchases restored to your account." : "No active Lite subscription was found for this Apple Account.")
            } catch {
                guard self.restoreID == id else { return }
                self.finishRestore(message: error.localizedDescription)
            }
        }
    }
    private func syncCurrent() async {
        for await result in StoreKit.Transaction.currentEntitlements {
            guard case .verified(let transaction) = result, identifiers.contains(transaction.productID) else { continue }
            do { try await deliver(transaction) }
            catch { message = "Could not sync a purchase. Use Restore purchases with the Easy Capture account you originally subscribed with." }
        }
    }
    @discardableResult
    private func deliver(_ transaction: StoreKit.Transaction, refreshProfile: Bool = true) async throws -> Bool {
        try Task.checkCancellation()
        guard identifiers.contains(transaction.productID), let store, store.signedIn else { throw CancellationError() }
        let userID = store.profile?.user.id
        let environment: String
        switch transaction.environment {
        case .production: environment = "Production"
        case .sandbox: environment = "Sandbox"
        default: throw APIError(status: 0, message: "Use Sandbox or TestFlight purchases to test the server integration.")
        }
        let access: PurchaseAccess = try await store.api.request("/api/mobile/purchases", method: "POST", body: ["transactionId": String(transaction.id), "environment": environment])
        try Task.checkCancellation()
        guard store.signedIn, store.profile?.user.id == userID else { throw CancellationError() }
        // Finish only after the server has recorded and checked this transaction.
        await transaction.finish()
        try Task.checkCancellation()
        if refreshProfile { await store.refresh() }
        return access.active
    }
}

struct PurchaseView: View {
    @ObservedObject private var purchases = Purchases.shared
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Image(systemName: "camera.aperture").font(.system(size: 44)).foregroundStyle(Palette.blue)
                    Eyebrow(text: "EASY CAPTURE LITE")
                    Text("More room to capture.").font(.system(.largeTitle, design: .rounded, weight: .bold))
                    Card {
                        Label("500 screenshots each calendar month", systemImage: "camera")
                        Label("30-day cloud history", systemImage: "icloud")
                        Label("No watermark", systemImage: "sparkles")
                        Label("Shared allowance on web and iPhone", systemImage: "arrow.triangle.2.circlepath")
                    }
                    Text("Your allowance resets on the first of each month (UTC). Unused screenshots do not roll over. Scheduled monitors are not included.")
                        .font(.footnote).foregroundStyle(.secondary)
                    if purchases.configuration?.canPurchase == true {
                        ForEach(purchases.products, id: \.id) { product in
                            Button { Task { await purchases.buy(product) } } label: {
                                VStack(spacing: 6) {
                                    Text(product.id.hasSuffix("yearly") ? "Lite · Yearly" : "Lite · Monthly").font(.headline)
                                    Text("\(product.displayPrice) / \(product.id.hasSuffix("yearly") ? "year" : "month")")
                                }.frame(maxWidth: .infinity)
                            }.buttonStyle(PrimaryButton()).disabled(purchases.busy)
                        }
                    } else if purchases.configuration?.available == true {
                        Text("Your account already has a paid plan. Restore an Apple purchase or manage your existing subscription below.").foregroundStyle(.secondary)
                    }
                    if purchases.busy {
                        ProgressView(purchases.restoring ? purchases.restoreProgress : "Updating your subscription…")
                    }
                    if purchases.restoring {
                        Button("Cancel restore") { purchases.cancelRestore() }
                    }
                    if let message = purchases.message { Text(message).font(.subheadline).foregroundStyle(.secondary) }
                    Button("Restore purchases") { Task { await purchases.restore() } }.disabled(purchases.busy)
                    Link("Manage Apple subscription", destination: URL(string: "https://apps.apple.com/account/subscriptions")!)
                    Text("Payment is charged to your Apple Account. Subscriptions renew automatically unless canceled at least 24 hours before the current period ends. Manage or cancel in your Apple Account settings.")
                        .font(.footnote).foregroundStyle(.secondary)
                    HStack {
                        Link("Privacy", destination: API.base.appendingPathComponent("privacy"))
                        Spacer()
                        Link("Terms of Use", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                    }.font(.footnote)
                }.padding(24).frame(maxWidth: 650)
            }.background(Palette.canvas).navigationTitle("Lite").navigationBarTitleDisplayMode(.inline)
                .toolbar { Button("Done") { purchases.cancelRestore(); dismiss() }.disabled(purchases.busy && !purchases.restoring) }
                .task { await purchases.load() }
        }.interactiveDismissDisabled(purchases.busy && !purchases.restoring)
            .onDisappear { purchases.cancelRestore() }
    }
}
