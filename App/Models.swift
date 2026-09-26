import Foundation

struct User: Codable { let id: String; let email: String; let name: String }
struct AuthResponse: Decodable { let user: User }
struct ListResponse<T: Decodable>: Decodable { let data: [T] }
struct Usage: Decodable { let used: Int; let quota: Int; let remaining: Int; let renewsOn: String }
struct Profile: Decodable { let user: User; let plan: String; let verified: Bool; let usage: Usage; let frequencies: [String]; var retentionDays: Int? = nil }
struct Capture: Decodable, Identifiable {
    let id: String; let status: String; let url: String; let display_url: String
    let device: String; let mode: String; let format: String; let source: String
    let images: [String]; let created_at: String; let error: String?
    var imageURL: URL? { images.first.flatMap(URL.init(string:)) }
}
struct Monitor: Decodable, Identifiable {
    let id: String; let label: String; let url: String; let display_url: String
    let device: String; let frequency: String; let status: String
    let last_run_at: String?; let next_run_at: String; let last_change_pct: Double?; let last_error: String?
    let threshold: Double?
    var title: String { label.isEmpty ? display_url : label }
}
struct Run: Decodable, Identifiable {
    let id: String; let capture_id: String?; let baseline_capture_id: String?
    let status: String; let changed: Int; let change_pct: Double?; let created_at: String; let detail: String?
}
extension Run {
    var resultTitle: String {
        if status == "error" { return "Check failed" }
        if status == "skipped" { return "Check skipped" }
        if status != "done" { return status.capitalized }
        if baseline_capture_id == nil { return "Baseline saved" }
        if changed == 1 { return "Change detected" }
        return change_pct == nil ? "Check completed" : "No alert triggered"
    }
}
struct MonitorDetail: Decodable { let runs: [Run]; let status: String?; let frequency: String?; let threshold: Double? }
struct APIProblem: Decodable { struct Detail: Decodable { let type: String; let message: String }; let error: Detail }
struct APIError: LocalizedError { let status: Int; let message: String; var errorDescription: String? { message } }
struct Acknowledgment: Decodable {}

func friendlyDate(_ raw: String) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    let date = formatter.date(from: raw) ?? ISO8601DateFormatter().date(from: raw)
    return date?.formatted(date: .abbreviated, time: .shortened) ?? raw
}
func validatedWebsite(_ input: String) -> URL? {
    let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
    let candidate = trimmed.contains("://") ? trimmed : "https://" + trimmed
    guard let url = URL(string: candidate), ["https", "http"].contains(url.scheme?.lowercased() ?? ""),
          let host = url.host, !host.isEmpty, url.user == nil, url.password == nil else { return nil }
    return url
}

// Web error wording can include upgrade prompts. Keep native plan limits neutral.
extension APIProblem.Detail {
    var companionMessage: String {
        switch type {
        case "plan_required": return "This feature or schedule is not included in your current account plan."
        case "watch_limit": return "You have reached your account’s monitor limit. Remove an existing monitor to create another."
        default: return message
        }
    }
}
