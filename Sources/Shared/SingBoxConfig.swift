import Foundation

enum SingBoxConfiguration {
    /// Converts the *server-issued* session into a sing-box Packet Tunnel config.
    /// Never connect from an untrusted, unauthenticated subscription URL.
    static func make(session: VPNSession, bypassRussianSites: Bool, dnsMode: String, killSwitch: Bool) throws -> String {
        var outbound: JSONObject
        switch session.proto.lowercased() {
        case "vless":
            outbound = [
                "type": "vless", "tag": "proxy", "server": session.server,
                "server_port": session.port, "uuid": session.uuid
            ]
            // Vision only applies to direct TCP VLESS; transport modes must not inherit it.
            if session.network.lowercased() == "tcp" && session.transportPath.isEmpty && !session.flow.isEmpty {
                outbound["flow"] = session.flow
            }
            if session.security.lowercased() == "reality" || session.security.lowercased() == "tls" {
                var tls: JSONObject = ["enabled": true, "server_name": session.serverName,
                                       "utls": ["enabled": true, "fingerprint": session.fingerprint]]
                if session.security.lowercased() == "reality" {
                    tls["reality"] = ["enabled": true, "public_key": session.publicKey, "short_id": session.shortID]
                }
                outbound["tls"] = tls
            }
            if ["ws", "websocket"].contains(session.network.lowercased()) {
                outbound["transport"] = ["type": "ws", "path": session.transportPath.isEmpty ? "/" : session.transportPath,
                                         "headers": ["Host": session.transportHost.isEmpty ? session.serverName : session.transportHost]]
            } else if ["xhttp", "splithttp"].contains(session.network.lowercased()) {
                // sing-box's V2Ray transport does not offer XHTTP. Do not silently switch
                // to TCP: that would create a misleading VPN-connected state.
                throw ByMeError.unavailable("This server uses XHTTP. An Xray-compatible iOS engine is required.")
            } else if session.network.lowercased() != "tcp" {
                throw ByMeError.unavailable("Unsupported VLESS transport: \(session.network)")
            }
        case "hysteria2", "hy2":
            outbound = ["type": "hysteria2", "tag": "proxy", "server": session.server,
                        "server_port": session.port, "password": session.uuid,
                        "tls": ["enabled": true, "server_name": session.serverName]]
        default:
            throw ByMeError.unavailable("Unsupported VPN protocol: \(session.proto)")
        }

        let dnsServer: String
        switch dnsMode {
        case "google": dnsServer = "8.8.8.8"
        case "adguard": dnsServer = "94.140.14.14"
        default: dnsServer = "1.1.1.1"
        }

        var rules: [JSONObject] = [
            ["action": "sniff"],
            ["protocol": "dns", "action": "hijack-dns"],
            ["ip_is_private": true, "outbound": "direct"]
        ]

        if bypassRussianSites {
            // Explicit list only. A complete Russian bypass needs signed remote domain
            // and IP rule sets maintained by the backend; do not mislabel this as all .ru.
            rules.append(["domain_suffix": [".ru", ".рф", ".su"], "outbound": "direct"])
        }

        let config: JSONObject = [
            "log": ["level": "warn"],
            "dns": ["servers": [["type": "udp", "tag": "dns-remote", "server": dnsServer]]],
            "inbounds": [["type": "tun", "tag": "tun-in", "interface_name": "utun", "address": ["172.19.0.1/30", "fd00:abcd::1/126"],
                          "mtu": 1400, "auto_route": true, "strict_route": killSwitch,
                          "stack": "gvisor"]],
            "outbounds": [outbound, ["type": "direct", "tag": "direct"], ["type": "block", "tag": "block"]],
            "route": ["rules": rules, "final": "proxy", "default_domain_resolver": ["server": "dns-remote"]]
        ]
        guard JSONSerialization.isValidJSONObject(config) else { throw ByMeError.invalidConfiguration("Invalid tunnel JSON") }
        let data = try JSONSerialization.data(withJSONObject: config, options: [.sortedKeys])
        guard let json = String(data: data, encoding: .utf8) else { throw ByMeError.invalidResponse }
        return json
    }
}

enum SharedTunnelConfig {
    static func write(_ json: String) throws {
        guard let directory = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: ByMeConfiguration.appGroup) else {
            throw ByMeError.unavailable("App Group is not provisioned by your Apple Developer team")
        }
        let file = directory.appendingPathComponent("tunnel.json")
        try Data(json.utf8).write(to: file, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    static func read() throws -> String {
        guard let directory = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: ByMeConfiguration.appGroup) else {
            throw ByMeError.unavailable("App Group is unavailable")
        }
        let data = try Data(contentsOf: directory.appendingPathComponent("tunnel.json"))
        guard let json = String(data: data, encoding: .utf8), !json.isEmpty else { throw ByMeError.invalidResponse }
        return json
    }

    static func clear() {
        guard let directory = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: ByMeConfiguration.appGroup) else { return }
        try? FileManager.default.removeItem(at: directory.appendingPathComponent("tunnel.json"))
    }
}
