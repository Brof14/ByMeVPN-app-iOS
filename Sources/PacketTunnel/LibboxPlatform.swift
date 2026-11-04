import Foundation
import Libbox
import Network
import NetworkExtension

final class LibboxPlatform: NSObject, LibboxPlatformInterfaceProtocol {
    private weak var provider: PacketTunnelProvider?
    private var appliedSettings: NEPacketTunnelNetworkSettings?
    private var monitor: NWPathMonitor?

    init(provider: PacketTunnelProvider) {
        self.provider = provider
        super.init()
    }

    func openTun(_ options: LibboxTunOptionsProtocol?, ret0_: UnsafeMutablePointer<Int32>?) throws {
        guard let options, let ret0_, let provider else {
            throw ByMeError.unavailable("VPN TUN interface is unavailable")
        }
        let settings = try makeSettings(options)
        try provider.apply(settings)
        appliedSettings = settings
        let fd = LibboxGetTunnelFileDescriptor()
        guard fd >= 0 else { throw ByMeError.unavailable("Could not obtain the VPN tunnel descriptor") }
        ret0_.pointee = fd
    }

    private func makeSettings(_ options: LibboxTunOptionsProtocol) throws -> NEPacketTunnelNetworkSettings {
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "198.18.0.1")
        guard options.getAutoRoute() else { throw ByMeError.invalidConfiguration("TUN auto routing is required") }
        settings.mtu = NSNumber(value: options.getMTU())

        let ipv4Addresses = prefixes(options.getInet4Address())
        guard !ipv4Addresses.isEmpty else { throw ByMeError.invalidConfiguration("TUN IPv4 address missing") }
        let ipv4 = NEIPv4Settings(addresses: ipv4Addresses.map(\.address), subnetMasks: ipv4Addresses.map(\.mask))
        let ipv4Included = prefixes(options.getInet4RouteAddress())
        ipv4.includedRoutes = ipv4Included.isEmpty ? [NEIPv4Route.default()] :
            ipv4Included.map { NEIPv4Route(destinationAddress: $0.address, subnetMask: $0.mask) }
        let ipv4Excluded = prefixes(options.getInet4RouteExcludeAddress())
        if !ipv4Excluded.isEmpty {
            ipv4.excludedRoutes = ipv4Excluded.map { NEIPv4Route(destinationAddress: $0.address, subnetMask: $0.mask) }
        }
        settings.ipv4Settings = ipv4

        let ipv6Addresses = prefixes(options.getInet6Address())
        if !ipv6Addresses.isEmpty {
            let ipv6 = NEIPv6Settings(
                addresses: ipv6Addresses.map(\.address),
                networkPrefixLengths: ipv6Addresses.map { NSNumber(value: $0.prefix) }
            )
            let included = prefixes(options.getInet6RouteAddress())
            ipv6.includedRoutes = included.isEmpty ? [NEIPv6Route.default()] :
                included.map { NEIPv6Route(destinationAddress: $0.address, networkPrefixLength: NSNumber(value: $0.prefix)) }
            let excluded = prefixes(options.getInet6RouteExcludeAddress())
            if !excluded.isEmpty {
                ipv6.excludedRoutes = excluded.map { NEIPv6Route(destinationAddress: $0.address, networkPrefixLength: NSNumber(value: $0.prefix)) }
            }
            settings.ipv6Settings = ipv6
        }
        let dnsString = try options.getDNSServerAddress().value
        guard !dnsString.isEmpty else { throw ByMeError.invalidConfiguration("No tunnel DNS configured") }
        let dns = NEDNSSettings(servers: [dnsString])
        dns.matchDomains = [""]
        dns.matchDomainsNoSearch = true
        settings.dnsSettings = dns
        return settings
    }

    func usePlatformAutoDetectControl() -> Bool { false }
    func usePlatformAutoDetectInterfaceControl() -> Bool { false }
    func autoDetectControl(_ fd: Int32) throws {}
    func autoDetectInterfaceControl(_ fd: Int32) throws {}
    func localDNSTransport() -> (any LibboxLocalDNSTransportProtocol)? { nil }
    func useProcFS() -> Bool { false }
    func findConnectionOwner(_ ipProtocol: Int32, sourceAddress: String?, sourcePort: Int32,
                             destinationAddress: String?, destinationPort: Int32) throws -> LibboxConnectionOwner {
        throw ByMeError.unavailable("Connection owner inspection is not supported on iOS")
    }

    func startDefaultInterfaceMonitor(_ listener: LibboxInterfaceUpdateListenerProtocol?) throws {
        guard let listener else { return }
        monitor?.cancel()
        let newMonitor = NWPathMonitor()
        monitor = newMonitor
        let initialUpdate = DispatchSemaphore(value: 0)
        let lock = NSLock()
        var first = true
        newMonitor.pathUpdateHandler = { path in
            // The first available interface is not necessarily the path's active one.
            // Selecting a dormant cellular/Wi-Fi interface can break all outbound traffic.
            let interface = path.status == .satisfied
                ? path.availableInterfaces.first(where: { path.usesInterfaceType($0.type) })
                : nil
            // Core startup must observe the initial route before we unblock it.
            listener.updateDefaultInterface(
                interface?.name ?? "", interfaceIndex: Int32(interface?.index ?? -1),
                isExpensive: path.isExpensive, isConstrained: path.isConstrained
            )
            lock.lock()
            if first { first = false; initialUpdate.signal() }
            lock.unlock()
        }
        newMonitor.start(queue: DispatchQueue(label: "com.bymevpn.ios.path", qos: .utility))
        guard initialUpdate.wait(timeout: .now() + 10) == .success else {
            throw ByMeError.unavailable("Network interface detection timed out")
        }
    }

    func closeDefaultInterfaceMonitor(_ listener: LibboxInterfaceUpdateListenerProtocol?) throws {
        monitor?.cancel()
        monitor = nil
    }

    func getInterfaces() throws -> LibboxNetworkInterfaceIteratorProtocol {
        let path = monitor?.currentPath
        let networkInterfaces = (path?.availableInterfaces ?? []).map { item -> LibboxNetworkInterface in
            let value = LibboxNetworkInterface()
            value.name = item.name
            value.index = Int32(item.index)
            value.mtu = 0
            value.flags = 0
            value.addresses = LibboxStringList([])
            value.dnsServer = LibboxStringList([])
            value.metered = path?.isExpensive ?? false
            switch item.type {
            case .wifi: value.type = LibboxInterfaceTypeWIFI
            case .cellular: value.type = LibboxInterfaceTypeCellular
            case .wiredEthernet: value.type = LibboxInterfaceTypeEthernet
            default: value.type = LibboxInterfaceTypeOther
            }
            return value
        }
        return LibboxInterfaceList(networkInterfaces)
    }

    func underNetworkExtension() -> Bool { true }
    func includeAllNetworks() -> Bool { false }
    func readWIFIState() -> LibboxWIFIState? { nil }
    func systemCertificates() -> (any LibboxStringIteratorProtocol)? { nil }

    func clearDNSCache() {
        guard let provider, let settings = appliedSettings else { return }
        try? provider.apply(nil)
        try? provider.apply(settings)
    }

    func send(_ notification: LibboxNotification?) throws {}
    func sendNotification(_ notification: LibboxNotification?) throws {}

    func reset() {
        monitor?.cancel()
        monitor = nil
        appliedSettings = nil
    }

    func systemProxyStatus() -> LibboxSystemProxyStatus {
        let status = LibboxSystemProxyStatus()
        status.available = false
        status.enabled = false
        return status
    }

    func setSystemProxyEnabled(_ enabled: Bool) throws {
        // ByMeVPN uses a TUN interface, not the iOS HTTP system proxy.
    }

    private func prefixes(_ iterator: LibboxRoutePrefixIteratorProtocol?) -> [RoutePrefix] {
        guard let iterator else { return [] }
        var items: [RoutePrefix] = []
        while iterator.hasNext() {
            if let item = iterator.next() {
                items.append(RoutePrefix(address: item.address(), mask: item.mask(), prefix: item.prefix()))
            }
        }
        return items
    }
}

private struct RoutePrefix {
    let address: String
    let mask: String
    let prefix: Int32
}

private final class LibboxInterfaceList: NSObject, LibboxNetworkInterfaceIteratorProtocol {
    private let values: [LibboxNetworkInterface]
    private var cursor = 0
    init(_ values: [LibboxNetworkInterface]) { self.values = values }
    func hasNext() -> Bool { cursor < values.count }
    func next() -> LibboxNetworkInterface? {
        guard hasNext() else { return nil }
        defer { cursor += 1 }
        return values[cursor]
    }
}

private final class LibboxStringList: NSObject, LibboxStringIteratorProtocol {
    private let values: [String]
    private var cursor = 0
    init(_ values: [String]) { self.values = values }
    func len() -> Int32 { Int32(values.count) }
    func hasNext() -> Bool { cursor < values.count }
    func next() -> String {
        guard hasNext() else { return "" }
        defer { cursor += 1 }
        return values[cursor]
    }
}
