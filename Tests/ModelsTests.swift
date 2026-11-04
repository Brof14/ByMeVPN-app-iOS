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

    func testExplicitISOExpiryStopsExpiredAccessWithZeroSeconds() {
        let yesterday = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-86_400))
        let status = Subscription(["status": "active", "seconds_remaining": 0,
                                   "expires_at": yesterday])
        XCTAssertFalse(status.isActive)
        XCTAssertNil(status.remainingDays)
    }

    func testFutureISOExpiryShowsRemainingDaysWhenSecondsMissing() {
        let future = ISO8601DateFormatter().string(from: Date().addingTimeInterval(172_800))
        let status = Subscription(["status": "trial", "expires_at": future])
        XCTAssertTrue(status.isActive)
        XCTAssertNotNil(status.remainingDays)
        XCTAssertTrue((status.remainingDays ?? 0) >= 1)
    }

    func testFractionalSecondISOExpiry() {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let expired = formatter.string(from: Date().addingTimeInterval(-60))
        XCTAssertFalse(Subscription(["status": "active", "expires_at": expired]).isActive)
    }

    func testUnixEpochExpiry() {
        let past = Int(Date().addingTimeInterval(-60).timeIntervalSince1970)
        let status = Subscription(["status": "grace", "expires_at": String(past)])
        XCTAssertFalse(status.isActive)
    }

    func testServerFlagRejectsMalformedCountryCode() {
        XCTAssertEqual(ServerNode(["code": "foo", "country_code": "XYZ"]).flag, "🌐")
        XCTAssertEqual(ServerNode(["code": "bar", "country_code": "DE"]).flag, "🇩🇪")
    }

    func testUnicodeNumericDeviceIDCannotBeDeleted() {
        XCTAssertNil(Device(["id": "１２３", "device_model": "Test"], installID: "id"))
        XCTAssertNotNil(Device(["id": "123", "device_model": "Test"], installID: "id"))
    }

    func testWireRejectsLiteralNullString() {
        XCTAssertNil(Wire.optional("null"))
        XCTAssertEqual(Wire.string(NSNull()), "")
    }

    func testVLESSWebSocketTransportKeepsHostAndDoesNotInheritVision() throws {
        let session = try VPNSession([
            "protocol": "vless", "server": "vpn.example.org", "port": 443,
            "uuid": "00000000-0000-0000-0000-000000000000",
            "network": "ws", "security": "tls", "server_name": "example.org",
            "path": "/websocket", "host": "cdn.example.org"
        ])
        let data = try XCTUnwrap(SingBoxConfiguration.make(
            session: session, bypassRussianSites: false, dnsMode: "google", killSwitch: false
        ).data(using: .utf8))
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? JSONObject)
        let outbound = try XCTUnwrap((root["outbounds"] as? [JSONObject])?.first)
        XCTAssertNil(outbound["flow"])
        let transport = try XCTUnwrap(outbound["transport"] as? JSONObject)
        XCTAssertEqual(transport["type"] as? String, "ws")
        XCTAssertEqual(transport["path"] as? String, "/websocket")
        XCTAssertEqual((transport["headers"] as? JSONObject)?["Host"] as? String, "cdn.example.org")
    }

    func testHysteria2KeepsCredentialAndServerPort() throws {
        let session = try VPNSession([
            "protocol": "hysteria2", "server": "hy.example.org", "port": 4443,
            "uuid": "long-password", "security": "tls", "server_name": "hy.example.org"
        ])
        let json = try SingBoxConfiguration.make(
            session: session, bypassRussianSites: false, dnsMode: "cloudflare", killSwitch: false
        )
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(json.utf8)) as? JSONObject)
        let outbound = try XCTUnwrap((root["outbounds"] as? [JSONObject])?.first)
        XCTAssertEqual(outbound["type"] as? String, "hysteria2")
        XCTAssertEqual(outbound["server_port"] as? Int, 4443)
        XCTAssertEqual(outbound["password"] as? String, "long-password")
    }

    func testKillSwitchAndRussianDomainRuleFollowSettings() throws {
        let session = try VPNSession([
            "protocol": "vless", "server": "vpn.example.org", "port": 443,
            "uuid": "00000000-0000-0000-0000-000000000000",
            "security": "reality", "public_key": "example-public-key", "server_name": "example.org"
        ])
        func config(_ bypass: Bool, _ kill: Bool) throws -> JSONObject {
            let text = try SingBoxConfiguration.make(
                session: session, bypassRussianSites: bypass,
                dnsMode: "adguard", killSwitch: kill
            )
            return try XCTUnwrap(JSONSerialization.jsonObject(with: Data(text.utf8)) as? JSONObject)
        }
        let enabled = try config(true, true)
        let inbound = try XCTUnwrap((enabled["inbounds"] as? [JSONObject])?.first)
        XCTAssertEqual(inbound["strict_route"] as? Bool, true)
        let rulesEnabled = try XCTUnwrap((enabled["route"] as? JSONObject)?["rules"] as? [JSONObject])
        XCTAssertTrue(rulesEnabled.contains { $0["domain_suffix"] != nil })
        let disabled = try config(false, false)
        let rulesDisabled = try XCTUnwrap((disabled["route"] as? JSONObject)?["rules"] as? [JSONObject])
        XCTAssertFalse(rulesDisabled.contains { $0["domain_suffix"] != nil })
    }

    func testUnknownVPNTransportFailsClosed() throws {
        let session = try VPNSession([
            "protocol": "vless", "server": "vpn.example.org", "port": 443,
            "uuid": "00000000-0000-0000-0000-000000000000",
            "network": "grpc", "security": "tls", "server_name": "example.org"
        ])
        XCTAssertThrowsError(try SingBoxConfiguration.make(
            session: session, bypassRussianSites: false,
            dnsMode: "cloudflare", killSwitch: false
        ))
    }
}
