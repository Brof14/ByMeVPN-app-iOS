import Foundation

struct AuthPayload {
    let user: AppUser
    let subscription: Subscription?
}

actor ByMeAPI {
    static let shared = ByMeAPI()
    private let vault = SecureStorage.shared
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 25
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        session = URLSession(configuration: config)
    }

    private func perform(_ method: String, _ path: String, body: JSONObject? = nil,
                         authorization: String? = nil) async throws -> JSONObject {
        guard let url = URL(string: ByMeConfiguration.apiBase.absoluteString + path),
              url.scheme == "https", url.host == ByMeConfiguration.apiBase.host else {
            throw ByMeError.invalidConfiguration("Invalid backend endpoint")
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue(vault.installID, forHTTPHeaderField: "X-HWID")
        request.setValue("iOS", forHTTPHeaderField: "X-Device-OS")
        request.setValue(ProcessInfo.processInfo.operatingSystemVersionString, forHTTPHeaderField: "X-Ver-OS")
        request.setValue("iPhone", forHTTPHeaderField: "X-Device-Model")
        if let authorization, !authorization.isEmpty {
            request.setValue("Bearer " + authorization, forHTTPHeaderField: "Authorization")
        }
        if let body { request.httpBody = try JSONSerialization.data(withJSONObject: body) }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.url?.scheme == "https" else {
            throw ByMeError.invalidResponse
        }
        let decoded = (try? JSONSerialization.jsonObject(with: data))
        var json = decoded as? JSONObject ?? [:]
        if let array = decoded as? [JSONObject] { json["raw_array"] = array }
        if !(200...299).contains(http.statusCode) {
            let detail = Wire.object(json["detail"])
            let nested = Wire.object(detail["error"] ?? json["error"])
            let message = Wire.optional(nested["message"]) ?? Wire.optional(detail["message"])
                ?? Wire.optional(json["detail"]) ?? HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
            throw ByMeError.http(http.statusCode, message)
        }
        return json
    }

    private var refreshInFlight: Task<Bool, Never>?

    private func refresh(for observedAccess: String) async -> Bool {
        if vault.accessToken != observedAccess { return vault.accessToken != nil }
        if let existing = refreshInFlight { return await existing.value }
        // A shared in-flight task prevents simultaneous 401 responses from rotating
        // the same refresh token more than once.
        let task = Task { () -> Bool in
            guard let old = self.vault.refreshToken, !old.isEmpty else { return false }
            guard let json = try? await self.perform("POST", "/auth/refresh", body: ["refresh": old]) else { return false }
            let access = Wire.string(json["access"] ?? json["access_token"])
            guard !access.isEmpty else { return false }
            if self.vault.accessToken != observedAccess { return self.vault.accessToken != nil }
            self.vault.setTokens(access: access,
                                 refresh: Wire.optional(json["refresh"] ?? json["refresh_token"]) ?? old)
            return true
        }
        refreshInFlight = task
        let success = await task.value
        refreshInFlight = nil
        return success
    }

    private func request(_ method: String, _ path: String, body: JSONObject? = nil, requiresAuth: Bool = true) async throws -> JSONObject {
        guard requiresAuth else { return try await perform(method, path, body: body) }
        guard let access = vault.accessToken, !access.isEmpty else { throw ByMeError.expiredSession }
        do {
            return try await perform(method, path, body: body, authorization: access)
        } catch ByMeError.http(401, _) {
            guard await refresh(for: access), let newAccess = vault.accessToken else {
                vault.clearSession()
                throw ByMeError.expiredSession
            }
            return try await perform(method, path, body: body, authorization: newAccess)
        }
    }

    private func persistAuth(_ json: JSONObject) throws -> AuthPayload {
        let access = Wire.string(json["access"] ?? json["access_token"])
        guard !access.isEmpty else { throw ByMeError.invalidResponse }
        // Android supports legacy ref_<JWT> fallback for Telegram flow.
        let refresh = Wire.optional(json["refresh"] ?? json["refresh_token"]) ?? "ref_" + access
        vault.clearSession()
        vault.setTokens(access: access, refresh: refresh)
        return AuthPayload(user: AppUser(json), subscription: (json["subscription"] as? JSONObject).map { Subscription($0) })
    }

    func login(email: String, password: String) async throws -> AuthPayload {
        let json = try await request("POST", "/auth/login", body: [
            "email": email.trimmingCharacters(in: .whitespacesAndNewlines),
            "password": password, "install_id": vault.installID
        ], requiresAuth: false)
        return try persistAuth(json)
    }

    func register(name: String, email: String, password: String) async throws -> AuthPayload {
        let json = try await request("POST", "/auth/register", body: [
            "name": name.trimmingCharacters(in: .whitespacesAndNewlines),
            "email": email.trimmingCharacters(in: .whitespacesAndNewlines),
            "password": password, "install_id": vault.installID
        ], requiresAuth: false)
        return try persistAuth(json)
    }

    func createTelegramSession() async throws -> TelegramSession {
        let json = try await request("POST", "/auth/telegram/create-session", body: [:], requiresAuth: false)
        guard let token = Wire.optional(json["session_token"]),
              let url = URL(string: Wire.string(json["bot_url"])),
              url.scheme == "https", ["t.me","telegram.me"].contains(url.host?.lowercased() ?? "") else {
            throw ByMeError.invalidResponse
        }
        return TelegramSession(token: token, botURL: url)
    }

    func pollTelegram(_ token: String) async throws -> (String, AuthPayload?) {
        let json: JSONObject
        do {
            json = try await request("POST", "/auth/telegram/check-session", body: ["token": token], requiresAuth: false)
        } catch ByMeError.http(405, _) {
            guard let encoded = token.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
                throw ByMeError.invalidResponse
            }
            json = try await request("GET", "/auth/telegram/check-session?token=" + encoded, requiresAuth: false)
        }
        let status = Wire.string(json["status"]).lowercased()
        guard ["pending", "authenticated", "expired"].contains(status) else { throw ByMeError.invalidResponse }
        return (status, status == "authenticated" ? try persistAuth(json) : nil)
    }

    func me() async throws -> AppUser { AppUser(try await request("GET", "/me")) }
    func subscription() async throws -> Subscription { Subscription(try await request("GET", "/subscription/status")) }
    func activateTrial() async throws -> Subscription {
        Subscription(try await request("POST", "/subscription/trial", body: [
            "install_id": vault.installID, "device_model": "iPhone"
        ]))
    }

    func servers() async throws -> [ServerNode] {
        let json = try await request("GET", "/servers")
        return (json["servers"] as? [JSONObject] ?? []).map(ServerNode.init).filter { !$0.code.isEmpty }
    }

    func startVPNSession(node: String) async throws -> VPNSession {
        guard !node.isEmpty else { throw ByMeError.invalidConfiguration("No server selected") }
        let json = try await request("POST", "/vpn/session", body: [
            "node_code": node, "install_id": vault.installID
        ])
        return try VPNSession(json)
    }

    func stopVPNSession() async {
        _ = try? await request("DELETE", "/vpn/session")
    }

    func plans(devices: Int) async throws -> [PricingPlan] {
        guard [2, 5, 10].contains(devices) else { throw ByMeError.invalidConfiguration("Invalid device tier") }
        let json = try await request("GET", "/mobile/v2/plans?devices=\(devices)")
        let plans = (json["raw_array"] as? [JSONObject]) ?? (json["plans"] as? [JSONObject]) ?? []
        return plans.map { PricingPlan($0, catalogEnabled: Wire.bool(json["payment_enabled"])) }
    }

    func devices() async throws -> [Device] {
        let json = try await request("GET", "/devices")
        var seen = Set<String>()
        return (json["devices"] as? [JSONObject] ?? []).compactMap { Device($0, installID: vault.installID) }
            .filter { seen.insert($0.id).inserted }
    }

    func deleteDevice(_ id: String) async throws {
        guard !id.isEmpty, id.allSatisfy({ $0.isNumber }) else {
            throw ByMeError.invalidConfiguration("Invalid device identifier")
        }
        _ = try await request("DELETE", "/devices/" + id)
    }

    func deleteAccount() async throws {
        _ = try await request("DELETE", "/me")
        vault.clearSession()
    }

    func logout() async {
        _ = try? await request("POST", "/auth/logout", body: [:])
        vault.clearSession()
    }
}
