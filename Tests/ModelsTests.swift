import Foundation
import XCTest
@testable import ByMeVPN

final class ModelsTests: XCTestCase {
    func testSubscriptionStatusAndDeviceLimitFromPlan() {
        let status = Subscription(["status": "active", "plan_code": "3m_d5",
                                   "seconds_remaining": 604800])
        XCTAssertTrue(status.isActive)
        XCTAssertEqual(status.maxDevices, 5)
        XCTAssertEqual(status.remainingDays, 7)
    }

    func testExpiredSubscriptionIsNotAccepted() {
        let status = Subscription(["status": "active", "seconds_remaining": 1],
                                  now: Date().addingTimeInterval(-10))
        XCTAssertFalse(status.isActive)
    }

    func testTrialStatus() {
        let sub = Subscription(["subscription": ["status": "none", "trial_available": true]])
        XCTAssertTrue(sub.trialAvailable)
        XCTAssertFalse(sub.isActive)
    }

    func testPlanParsingMustUseBackendPrices() {
        let plan = PricingPlan(["code": "12m_d10", "price_rub": 900,
                                "days": 450, "devices": 10])
        XCTAssertEqual(plan.priceRub, 900)
        XCTAssertFalse(plan.purchaseEnabled)
    }

    func testServerIdentifiersAreStable() {
        let server = ServerNode(["node_code": "de-1", "country_code": "DE"])
        XCTAssertEqual(server.id, "de-1")
        XCTAssertEqual(server.flag, "🇩🇪")
    }

    func testDeviceDeletionUsesOnlyServerIDs() {
        XCTAssertNil(Device(["id": "fake-nonnumeric", "device_model": "Laptop"], installID: "x"))
        XCTAssertNotNil(Device(["id": 34, "device_model": "Laptop"], installID: "x"))
    }

    func testRealitySessionValidation() {
        XCTAssertThrowsError(try VPNSession(["protocol": "vless", "server": "example.org",
                                             "port": 443, "uuid": "0000", "security": "reality"]))
    }

    func testXHTTPRejectedInsteadOfFakeConnection() throws {
        let session = try VPNSession(["protocol": "vless", "server": "example.org", "port": 443,
                                      "uuid": "00000000-0000-0000-0000-000000000000",
                                      "security": "tls", "network": "xhttp"])
        XCTAssertThrowsError(try SingBoxConfiguration.make(session: session,
                                    bypassRussianSites: true, dnsMode: "cloudflare", killSwitch: false))
    }

    func testVLESSRealityOutput() throws {
        let session = try VPNSession(["protocol": "vless", "server": "vpn.example.org",
                                      "port": 443, "uuid": "00000000-0000-0000-0000-000000000000",
                                      "security": "reality", "public_key": "example-public-key",
                                      "server_name": "example.com"])
        let json = try SingBoxConfiguration.make(session: session,
                      bypassRussianSites: true, dnsMode: "cloudflare", killSwitch: false)
        XCTAssertTrue(json.contains("\"type\":\"vless\""))
        XCTAssertTrue(json.contains("\"public_key\":\"example-public-key\""))
        XCTAssertTrue(json.contains(".ru"))
    }
}
