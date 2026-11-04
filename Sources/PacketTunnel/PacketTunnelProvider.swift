import Foundation
import NetworkExtension
import Libbox

final class PacketTunnelProvider: NEPacketTunnelProvider {
    private var runtime: LibboxRuntime?

    override func startTunnel(options: [String: NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        // Never announce an active VPN until the actual native core starts.
        do {
            let json = try SharedTunnelConfig.read()
            let runtime = LibboxRuntime(provider: self, configuration: json)
            try runtime.start()
            self.runtime = runtime
            completionHandler(nil)
        } catch {
            runtime?.stop()
            runtime = nil
            completionHandler(error)
        }
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        runtime?.stop()
        runtime = nil
        completionHandler()
    }

    override func sleep(completionHandler: @escaping () -> Void) {
        runtime?.sleep()
        completionHandler()
    }

    override func wake() {
        runtime?.wake()
    }

    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        // Never echo a token or unvalidated configuration to other processes.
        completionHandler?(Data("ok".utf8))
    }

    func apply(_ settings: NEPacketTunnelNetworkSettings?) throws {
        let semaphore = DispatchSemaphore(value: 0)
        var result: Error?
        setTunnelNetworkSettings(settings) { error in
            result = error
            semaphore.signal()
        }
        guard semaphore.wait(timeout: .now() + 15) == .success else {
            throw ByMeError.unavailable("Applying VPN network settings timed out")
        }
        if let result { throw result }
    }
}
