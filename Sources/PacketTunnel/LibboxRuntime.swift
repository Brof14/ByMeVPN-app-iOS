import Foundation
import NetworkExtension
import Libbox

final class LibboxRuntime: NSObject, LibboxCommandServerHandlerProtocol {
    private let config: String
    private let adapter: LibboxPlatform
    private var commandServer: LibboxCommandServer?

    init(provider: PacketTunnelProvider, configuration: String) {
        config = configuration
        adapter = LibboxPlatform(provider: provider)
        super.init()
    }

    func start() throws {
        guard !config.isEmpty else { throw ByMeError.invalidConfiguration("Empty VPN config") }
        guard let base = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: ByMeConfiguration.appGroup) else {
            throw ByMeError.unavailable("Missing App Group entitlement")
        }
        let runtime = base.appendingPathComponent("Runtime", isDirectory: true)
        let working = runtime.appendingPathComponent("Working", isDirectory: true)
        let temp = runtime.appendingPathComponent("Temp", isDirectory: true)
        for folder in [runtime, working, temp] {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }

        LibboxSetLocale(Locale.current.identifier)
        LibboxSetMemoryLimit(true)
        let options = LibboxSetupOptions()
        options.basePath = runtime.path
        options.workingPath = working.path
        options.tempPath = temp.path
        options.logMaxLines = 500
        options.debug = false

        var error: NSError?
        guard LibboxSetup(options, &error) else {
            throw error ?? ByMeError.unavailable("Libbox setup failed")
        }
        var checkError: NSError?
        guard LibboxCheckConfig(config, &checkError) else {
            throw checkError ?? ByMeError.invalidConfiguration("VPN config was rejected by the native core")
        }
        var serverError: NSError?
        guard let server = LibboxNewCommandServer(self, adapter, &serverError) else {
            throw serverError ?? ByMeError.unavailable("VPN core could not start")
        }
        commandServer = server
        do {
            try server.start()
            try server.startOrReloadService(config, options: LibboxOverrideOptions())
        } catch {
            stop()
            throw error
        }
    }

    func stop() {
        if let commandServer {
            try? commandServer.closeService()
            commandServer.close()
        }
        commandServer = nil
        adapter.reset()
    }

    func sleep() { commandServer?.pause() }
    func wake() { commandServer?.wake() }

    func serviceStop() throws {
        try commandServer?.closeService()
        adapter.reset()
    }

    func serviceReload() throws {
        guard let commandServer else { throw ByMeError.unavailable("VPN command service is stopped") }
        try commandServer.startOrReloadService(config, options: LibboxOverrideOptions())
    }

    func getSystemProxyStatus() throws -> LibboxSystemProxyStatus { adapter.systemProxyStatus() }
    func setSystemProxyEnabled(_ enabled: Bool) throws { try adapter.setSystemProxyEnabled(enabled) }
    func writeDebugMessage(_ message: String?) { /* Deliberately never log secrets. */ }
    func writeMessage(_ message: String) { /* Avoid persisting user traffic or configuration. */ }
}
