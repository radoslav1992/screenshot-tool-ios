import Foundation
import Security

/// Only the server-issued session is persisted; never the user's password.
enum SessionVault {
    private static let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "com.easyscreencapture.ios.session", kSecAttrAccount as String: "session"]
    static func read() -> String? {
        var q = query; q[kSecReturnData as String] = true; q[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
    static func save(_ value: String) throws {
        clear(); var q = query
        q[kSecValueData as String] = Data(value.utf8)
        q[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        guard SecItemAdd(q as CFDictionary, nil) == errSecSuccess else {
            throw APIError(status: 0, message: "Could not securely save your session. Please sign in again.")
        }
    }
    static func clear() { SecItemDelete(query as CFDictionary) }
}
final class NoRedirects: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}
@MainActor final class API {
    static let base = URL(string: "https://easyscreencapture.com")!
    private let session: URLSession
    var onUnauthorized: (() -> Void)?
    init() {
        let config = URLSessionConfiguration.ephemeral
        config.httpShouldSetCookies = false; config.httpCookieStorage = nil
        config.timeoutIntervalForRequest = 120; config.timeoutIntervalForResource = 180
        session = URLSession(configuration: config, delegate: NoRedirects(), delegateQueue: nil)
    }
    func request<T: Decodable>(_ path: String, method: String = "GET", body: [String: String]? = nil) async throws -> T {
        guard path.hasPrefix("/api/"), let url = URL(string: path, relativeTo: Self.base)?.absoluteURL,
              url.host == Self.base.host, url.scheme == "https" else { throw APIError(status: 0, message: "Invalid service address.") }
        var request = URLRequest(url: url); request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token = SessionVault.read() { request.setValue("sf_session=\(token)", forHTTPHeaderField: "Cookie") }
        if let body { request.httpBody = try JSONEncoder().encode(body); request.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError(status: 0, message: "No response from the service.") }
        if http.statusCode == 401 && !path.hasPrefix("/api/auth/") { SessionVault.clear(); onUnauthorized?() }
        guard (200..<300).contains(http.statusCode) else {
            let problem = try? JSONDecoder().decode(APIProblem.self, from: data)
            throw APIError(status: http.statusCode, message: problem?.error.companionMessage ?? "The service could not complete this request (\(http.statusCode)). Please try again.")
        }
        let result: T
        do { result = try JSONDecoder().decode(T.self, from: data) }
        catch { throw APIError(status: http.statusCode, message: "The server returned an unexpected response. Check that the mobile backend update is deployed.") }
        if let header = http.value(forHTTPHeaderField: "Set-Cookie") {
            let cookies = HTTPCookie.cookies(withResponseHeaderFields: ["Set-Cookie": header], for: Self.base)
            if let cookie = cookies.first(where: { $0.name == "sf_session" }) {
                if cookie.value.isEmpty { SessionVault.clear() } else { try SessionVault.save(cookie.value) }
            }
        }
        return result
    }
}
