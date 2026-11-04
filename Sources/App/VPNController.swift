import Foundation
import NetworkExtension

@MainActor
final class VPNController: ObservableObject {
    @Published private(set) var status: NEVPNStatus = .disconnected
    @Published private(set) var errorText: String?
    private var manager: NETunnelProviderManager?
    private var statusObserver: NSObjectProtocol?

    init() {
        statusObserver = NotificationCenter.default.addObserver(
            forName: .NEVPNStatusDidChange, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.status = self?.manager?.connection.status ?? .disconnected }
        }
    }

    deinit {
        if let statusObserver { NotificationCenter.default.removeObserver(statusObserver) }
    }

    var isConnected: Bool { status == .connected }
    var isBusy: Bool { [.connecting, .reasserting, .disconnecting].contains(status) }

    func load() async {
        do {
            let all = try await NETunnelProviderManager.loadAllFromPreferences()
            manager = all.first { ($0.protocolConfiguration as? NETunnelProviderProtocol)?.providerBundleIdentifier == ByMeConfiguration.tunnelBundleID }
            status = manager?.connection.status ?? .disconnected
        } catch {
            errorText = error.localizedDescription
        }
    }

    func connect(json: String, killSwitch: Bool, onDemand: Bool) async throws {
        #if targetEnvironment(simulator)
        throw ByMeError.unavailable("A Packet Tunnel cannot run in the iOS Simulator. Use a signed build on an iPhone.")
        #else
        errorText = nil
        // The payload is written only after the backend issues a fresh VPN session.
        try SharedTunnelConfig.write(json)
        do {
            if manager == nil { await load() }
            let configManager = manager ?? NETunnelProviderManager()
            let proto = NETunnelProviderProtocol()
            proto.providerBundleIdentifier = ByMeConfiguration.tunnelBundleID
            proto.serverAddress = "ByMeVPN"
            proto.disconnectOnSleep = false
            proto.includeAllNetworks = killSwitch
            configManager.protocolConfiguration = proto
            configManager.localizedDescription = "ByMeVPN"
            configManager.isEnabled = true
            configManager.isOnDemandEnabled = onDemand
            if onDemand {
                let rule = NEOnDemandRuleConnect()
                configManager.onDemandRules = [rule]
            } else {
                configManager.onDemandRules = []
            }
            try await configManager.saveToPreferences()
            try await configManager.loadFromPreferences()
            manager = configManager
            try configManager.connection.startVPNTunnel()
            status = configManager.connection.status
        } catch {
            SharedTunnelConfig.clear()
            errorText = error.localizedDescription
            throw error
        }
        #endif
    }

    func disconnect() {
        manager?.connection.stopVPNTunnel()
        status = manager?.connection.status ?? .disconnected
        SharedTunnelConfig.clear()
    }

    func clearError() { errorText = nil }
}
