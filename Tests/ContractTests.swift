import XCTest
@testable import EasyCapture

final class ContractTests: XCTestCase {
    func testWebsiteValidationRejectsExecutableAndCredentialURLs() {
        XCTAssertNil(validatedWebsite("javascript://alert(1)"))
        XCTAssertNil(validatedWebsite("file:///etc/passwd"))
        XCTAssertNil(validatedWebsite("https://user:password@example.com"))
        XCTAssertEqual(validatedWebsite(" example.com/path ")?.absoluteString, "https://example.com/path")
    }
    func testCaptureContractKeepsSourceAndSignedImageURL() throws {
        let data = Data(#"{"id":"cap_1","status":"done","url":"https://example.com","display_url":"example.com","device":"desktop","mode":"fullpage","format":"png","source":"watch","images":["https://easyscreencapture.com/f/cap_1/shot.png?t=secret"],"created_at":"2026-09-17T12:00:00.000Z"}"#.utf8)
        let shot = try JSONDecoder().decode(Capture.self, from: data)
        XCTAssertEqual(shot.source, "watch")
        XCTAssertEqual(shot.imageURL?.query, "t=secret")
    }
    func testProfileUsesServerAllowanceNotLocalPlanAssumptions() throws {
        let data = Data(#"{"user":{"id":"u_1","email":"user@example.com","name":"Rado"},"plan":"Plus","verified":false,"usage":{"used":12,"quota":500,"remaining":488,"renewsOn":"2026-10-01"},"frequencies":["daily","weekly"]}"#.utf8)
        let profile = try JSONDecoder().decode(Profile.self, from: data)
        XCTAssertFalse(profile.verified)
        XCTAssertEqual(profile.usage.remaining, 488)
        XCTAssertEqual(profile.frequencies, ["daily", "weekly"])
    }
    func testWebUpgradePromptsAreNotPresentedInCompanionApp() throws {
        let data = Data(#"{"error":{"type":"watch_limit","message":"Delete one, or upgrade for more."}}"#.utf8)
        let problem = try JSONDecoder().decode(APIProblem.self, from: data)
        XCTAssertFalse(problem.error.companionMessage.contains("upgrade"))
        XCTAssertTrue(problem.error.companionMessage.contains("monitor limit"))
    }
    func testThrottledSignInShowsTheServerMessage() throws {
        let data = Data(#"{"error":{"type":"rate_limited","message":"Too many sign-in attempts. Try again in 10 minutes."}}"#.utf8)
        let problem = try JSONDecoder().decode(APIProblem.self, from: data)
        XCTAssertEqual(problem.error.companionMessage, "Too many sign-in attempts. Try again in 10 minutes.")
    }
    func testMonitorPausedByPlanLimitDecodesWithItsReason() throws {
        // The backend may add fields (alert channels, rule details); the app must keep decoding.
        let data = Data(#"{"id":"wat_1","label":"","url":"https://example.com","display_url":"example.com","device":"desktop","frequency":"daily","status":"paused","last_run_at":null,"next_run_at":"2026-10-03T09:00:00.000Z","last_change_pct":null,"last_error":"Paused: your plan includes 5 monitors.","threshold":1,"notify_email":true,"webhook_url":null,"rule":{"kind":"visual"}}"#.utf8)
        let monitor = try JSONDecoder().decode(Monitor.self, from: data)
        XCTAssertEqual(monitor.status, "paused")
        XCTAssertEqual(monitor.last_error, "Paused: your plan includes 5 monitors.")
    }
    func testFailedCaptureWithErrorTypeStillDecodes() throws {
        let data = Data(#"{"id":"cap_2","status":"error","url":"https://example.com","display_url":"example.com","device":"mobile","mode":"fullpage","format":"png","source":"app","images":[],"created_at":"2026-10-02T12:00:00.000Z","error":"The page took too long to capture and was stopped.","error_type":"render_timeout"}"#.utf8)
        let shot = try JSONDecoder().decode(Capture.self, from: data)
        XCTAssertEqual(shot.status, "error")
        XCTAssertNil(shot.imageURL)
    }
    func testResumeBeyondPlanLimitKeepsNeutralWording() throws {
        let data = Data(#"{"error":{"type":"watch_limit","message":"Your plan includes 5 monitors. Upgrade to resume more."}}"#.utf8)
        let message = try JSONDecoder().decode(APIProblem.self, from: data).error.companionMessage
        XCTAssertFalse(message.contains("Upgrade") || message.contains("upgrade"))
        XCTAssertTrue(message.contains("monitor limit"))
    }
    func testFirstMonitorRunHasNoBaseline() throws {
        let data = Data(#"{"runs":[{"id":"run_1","capture_id":"cap_1","baseline_capture_id":null,"status":"baseline","changed":0,"change_pct":null,"created_at":"2026-09-17T12:00:00Z","detail":null}]}"#.utf8)
        let detail = try JSONDecoder().decode(MonitorDetail.self, from: data)
        XCTAssertNil(detail.runs.first?.baseline_capture_id)
    }
    func testScheduleLabelsReadNaturallyIncludingNewOnes() {
        XCTAssertEqual(frequencyLabel("quarter-hourly"), "Every 15 minutes")
        XCTAssertEqual(frequencyLabel("daily"), "Daily")
        // A schedule added on the server later still reads as words, not an id.
        XCTAssertEqual(frequencyLabel("twice-daily"), "Twice Daily")
    }
}
