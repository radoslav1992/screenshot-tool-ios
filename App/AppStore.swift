import SwiftUI

@MainActor final class AppStore: ObservableObject {
    let api = API()
    @Published var signedIn = SessionVault.read() != nil
    @Published var profile: Profile?
    @Published var captures: [Capture] = []
    @Published var monitors: [Monitor] = []
    @Published var error: String?
    @Published var busy = false
    @Published var canLoadMore = false
    @Published var incomingURL = ""
    private var offset = 0
    init() { api.onUnauthorized = { [weak self] in self?.reset() } }
    func reset() { signedIn = false; profile = nil; captures = []; monitors = []; offset = 0; canLoadMore = false }
    func authenticate(email: String, password: String, name: String, register: Bool) async {
        busy = true; defer { busy = false }
        do {
            let _: AuthResponse = try await api.request(register ? "/api/auth/signup" : "/api/auth/login", method: "POST",
                                                        body: ["email": email, "password": password, "name": name])
            signedIn = true; await refresh()
        } catch { self.error = error.localizedDescription }
    }
    func refresh() async {
        do {
            let p: Profile = try await api.request("/api/mobile/profile")
            let w: ListResponse<Monitor> = try await api.request("/api/watches")
            let c: ListResponse<Capture> = try await api.request("/api/captures?collection=regular&limit=30&offset=0")
            profile = p; monitors = w.data; captures = c.data; offset = c.data.count; canLoadMore = c.data.count == 30
        } catch { if signedIn { self.error = error.localizedDescription } }
    }
    func loadMore() async {
        guard !busy else { return }; busy = true; defer { busy = false }
        do {
            let page: ListResponse<Capture> = try await api.request("/api/captures?collection=regular&limit=30&offset=\(offset)")
            let known = Set(captures.map(\.id)); captures += page.data.filter { !known.contains($0.id) }
            offset += page.data.count; canLoadMore = page.data.count == 30
        } catch { self.error = error.localizedDescription }
    }
    func logout() async {
        do { let _: Acknowledgment = try await api.request("/api/auth/logout", method: "POST", body: [:]) }
        catch { self.error = "Signed out on this device. The server session could not be revoked; it will expire automatically." }
        SessionVault.clear(); reset()
    }
}
