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
    func testFirstMonitorRunHasNoBaseline() throws {
        let data = Data(#"{"runs":[{"id":"run_1","capture_id":"cap_1","baseline_capture_id":null,"status":"baseline","changed":0,"change_pct":null,"created_at":"2026-09-17T12:00:00Z","detail":null}]}"#.utf8)
        let detail = try JSONDecoder().decode(MonitorDetail.self, from: data)
        XCTAssertNil(detail.runs.first?.baseline_capture_id)
    }
}
