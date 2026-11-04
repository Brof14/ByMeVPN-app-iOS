import Foundation

enum ByMeConfiguration {
    static let apiBase = URL(string: "https://bymevpn.duckdns.org/api/v1")!
    static let appGroup = "group.com.bymevpn.ios"
    static let tunnelBundleID = "com.bymevpn.ios.PacketTunnel"
    static let supportURL = URL(string: "https://t.me/ByMeVPNSupportBot")!
    static let telegramBotURL = URL(string: "https://t.me/ByMeVPNbot")!
}

typealias JSONObject = [String: Any]

enum Wire {
    static func object(_ value: Any?) -> JSONObject { value as? JSONObject ?? [:] }
    static func string(_ value: Any?) -> String {
        guard let value, !(value is NSNull) else { return "" }
        if let string = value as? String { return string == "null" ? "" : string }
        if let number = value as? NSNumber { return number.stringValue }
        return ""
    }
    static func int(_ value: Any?) -> Int {
        if let n = value as? NSNumber { return n.intValue }
        return Int(string(value)) ?? 0
    }
    static func bool(_ value: Any?) -> Bool {
        if let n = value as? NSNumber { return n.boolValue }
        return string(value).lowercased() == "true"
    }
    static func optional(_ value: Any?) -> String? { let v = string(value); return v.isEmpty ? nil : v }
}

struct AppUser: Equatable {
    let id: String
    let name: String
    let email: String
    let isGoogle: Bool

    init(_ raw: JSONObject) {
        let obj = (raw["user"] as? JSONObject) ?? raw
        id = Wire.string(obj["user_id"] ?? obj["id"])
        email = Wire.string(obj["email"])
        name = Wire.optional(obj["name"]) ?? email.components(separatedBy: "@").first.flatMap { $0.isEmpty ? nil : $0 } ?? "User"
        isGoogle = Wire.bool(obj["is_google"])
    }
}

struct Subscription: Equatable {
    let status: String
    let planCode: String?
    let planName: String?
    let expiry: String?
    let secondsRemaining: Int
    let trialAvailable: Bool
    let maxDevices: Int
    let activeDevices: Int
    let autoRenew: Bool?
    let receivedAt: Date

    init(_ raw: JSONObject, now: Date = Date()) {
        let obj = (raw["subscription"] as? JSONObject) ?? raw
        status = Wire.string(obj["status"]).isEmpty ? "none" : Wire.string(obj["status"])
        planCode = Wire.optional(obj["plan_code"])
        planName = Wire.optional(obj["plan_name"])
        expiry = Wire.optional(obj["expires_at"])
        secondsRemaining = max(0, Wire.int(obj["seconds_remaining"]))
        trialAvailable = Wire.bool(obj["trial_available"])
        let explicit = Wire.int(obj["max_devices"])
        let regexLimit = planCode.flatMap { code -> Int? in
            guard let range = code.range(of: #"_d(2|5|10)$"#, options: .regularExpression) else { return nil }
            return Int(code[range].dropFirst(2))
        }
        maxDevices = explicit > 0 ? explicit : (regexLimit ?? 0)
        activeDevices = max(0, Wire.int(obj["active_devices"]))
        autoRenew = obj["auto_renew"] == nil || obj["auto_renew"] is NSNull ? nil : Wire.bool(obj["auto_renew"])
        receivedAt = now
    }

    private var parsedExpiry: Date? {
        guard let expiry, !expiry.isEmpty else { return nil }
        if let seconds = TimeInterval(expiry), seconds > 1_000_000_000 {
            return Date(timeIntervalSince1970: seconds)
        }
        // Only timestamps with an explicit timezone are interpreted as absolute.
        // Treating a naive backend-local timestamp as UTC would wrongly expire access.
        let dateFormats: [ISO8601DateFormatter.Options] = [
            [.withInternetDateTime, .withFractionalSeconds], [.withInternetDateTime]
        ]
        for options in dateFormats {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = options
            if let date = formatter.date(from: expiry) { return date }
        }
        return nil
    }

    var isActive: Bool {
        guard ["active", "trial", "grace"].contains(status.lowercased()) else { return false }
        if let parsedExpiry, parsedExpiry <= Date() { return false }
        return secondsRemaining == 0 || Date().timeIntervalSince(receivedAt) < Double(secondsRemaining)
    }
    var remainingDays: Int? {
        let remaining: TimeInterval
        if secondsRemaining > 0 {
            remaining = Double(secondsRemaining) - max(0, Date().timeIntervalSince(receivedAt))
        } else if let parsedExpiry {
            remaining = parsedExpiry.timeIntervalSinceNow
        } else { return nil }
        guard remaining > 0 else { return nil }
        return Int(ceil(remaining / 86_400))
    }
}

struct PricingPlan: Identifiable, Equatable {
    var id: String { code }
    let code: String
    let name: String
    let priceRub: Int
    let days: Int
    let devices: Int
    let isPopular: Bool
    let purchaseEnabled: Bool

    init(_ json: JSONObject, catalogEnabled: Bool = false) {
        code = Wire.string(json["code"])
        name = Wire.string(json["name"])
        priceRub = Wire.int(json["price_rub"])
        days = Wire.int(json["days"])
        devices = Wire.int(json["devices"])
        isPopular = Wire.bool(json["is_popular"])
        purchaseEnabled = Wire.bool(json["purchase_enabled"] ?? catalogEnabled)
    }
}

struct ServerNode: Identifiable, Equatable {
    var id: String { code }
    let code: String
    let country: String
    let countryEN: String
    let city: String
    let cityEN: String
    let countryCode: String
    let label: String
    let protocolName: String
    let load: Int
    let config: VPNSession?

    init(_ json: JSONObject) {
        code = Wire.string(json["code"] ?? json["node_code"])
        countryCode = Wire.string(json["country_code"]).uppercased()
        let fallback: [String: (String, String)] = ["NL": ("Нидерланды","Netherlands"), "DE": ("Германия","Germany"), "US": ("США","USA"), "FI": ("Финляндия","Finland")]
        country = Wire.optional(json["country"]) ?? fallback[countryCode]?.0 ?? "Основной сервер"
        countryEN = Wire.optional(json["country_en"]) ?? fallback[countryCode]?.1 ?? country
        city = Wire.string(json["city"])
        cityEN = Wire.optional(json["city_en"]) ?? city
        label = Wire.optional(json["display_name"]) ?? Wire.string(json["remark"])
        protocolName = Wire.optional(json["protocol"]) ?? "VPN"
        load = Wire.int(json["load_pct"] ?? json["load_percent"])
        config = (json["config"] as? JSONObject).flatMap { try? VPNSession($0) }
    }
    var flag: String {
        guard countryCode.unicodeScalars.count == 2,
              countryCode.unicodeScalars.allSatisfy({ (65...90).contains($0.value) }) else { return "🌐" }
        return countryCode.unicodeScalars.map { String(UnicodeScalar(127397 + $0.value)!) }.joined()
    }
    func displayName(_ ru: Bool) -> String {
        if !label.isEmpty { return label }
        let countryName = ru ? country : countryEN
        let cityName = ru ? city : cityEN
        return cityName.isEmpty ? countryName : "\(countryName) · \(cityName)"
    }
}

struct Device: Identifiable, Equatable {
    let id: String
    let name: String
    let platform: String
    let lastSeen: String
    let isCurrent: Bool

    init?(_ json: JSONObject, installID: String) {
        let id = Wire.string(json["id"] ?? json["device_id"] ?? json["hwid_id"])
        // Mirror Android: deleting devices requires a real numeric backend ID.
        guard !id.isEmpty, id.allSatisfy({ $0 >= "0" && $0 <= "9" }) else { return nil }
        self.id = id
        name = Wire.optional(json["device_model"]) ?? Wire.optional(json["device_name"]) ?? "Device"
        platform = Wire.optional(json["platform"]) ?? "Unknown"
        lastSeen = Wire.optional(json["last_seen_at"]) ?? Wire.optional(json["last_active"]) ?? ""
        isCurrent = Wire.bool(json["is_current"]) || Wire.string(json["install_id"]) == installID
    }
}

struct VPNSession: Codable, Equatable {
    let proto: String
    let server: String
    let port: Int
    let uuid: String
    let flow: String
    let security: String
    let serverName: String
    let publicKey: String
    let shortID: String
    let fingerprint: String
    let network: String
    let transportPath: String
    let transportHost: String
    let transportMode: String

    init(_ json: JSONObject) throws {
        proto = Wire.optional(json["protocol"]) ?? "vless"
        server = Wire.string(json["server"] ?? json["endpoint"])
        port = Wire.int(json["port"]) == 0 ? 443 : Wire.int(json["port"])
        uuid = Wire.string(json["uuid"] ?? json["id"])
        flow = Wire.optional(json["flow"]) ?? "xtls-rprx-vision"
        security = Wire.optional(json["security"]) ?? "reality"
        serverName = Wire.string(json["server_name"] ?? json["sni"])
        publicKey = Wire.string(json["public_key"] ?? json["server_public_key"])
        shortID = Wire.string(json["short_id"])
        fingerprint = Wire.optional(json["fingerprint"]) ?? "chrome"
        network = Wire.optional(json["network"]) ?? "tcp"
        transportPath = Wire.string(json["path"])
        transportHost = Wire.string(json["host"])
        transportMode = Wire.string(json["mode"])
        guard !server.isEmpty, (1...65535).contains(port), !uuid.isEmpty else { throw ByMeError.invalidConfiguration("Missing server, port, or credentials") }
        if security == "reality" && publicKey.isEmpty { throw ByMeError.invalidConfiguration("Missing Reality public key") }
    }
}

struct TelegramSession {
    let token: String
    let botURL: URL
}

enum ByMeError: LocalizedError {
    case http(Int, String)
    case invalidResponse
    case invalidConfiguration(String)
    case expiredSession
    case unavailable(String)

    var errorDescription: String? {
        switch self {
        case .http(let code, let message): return "HTTP \(code): \(message)"
        case .invalidResponse: return "Invalid server response"
        case .invalidConfiguration(let text): return text
        case .expiredSession: return "Session expired. Sign in again."
        case .unavailable(let text): return text
        }
    }
}
