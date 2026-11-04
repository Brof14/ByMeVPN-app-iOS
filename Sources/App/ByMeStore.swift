import Foundation
import SwiftUI
import UIKit

enum Screen: Hashable {
    case signIn, signUp, home, settings, advanced, account, accountSettings
    case devices, renewal, support, trial, pricing
}

@MainActor
final class ByMeStore: ObservableObject {
    @Published var screen: Screen = .signIn
    @Published var user: AppUser?
    @Published var subscription: Subscription?
    @Published var nodes: [ServerNode] = []
    @Published var selectedNode: String?
    @Published var devices: [Device] = []
    @Published var plans: [PricingPlan] = []
    @Published var loading = false
    @Published var message: String?
    @Published var showVPNDisclosure = false
    @Published var telegramPending = false
    @Published var language = UserDefaults.standard.string(forKey: "language") ?? "system"
    @Published var bypassRU = UserDefaults.standard.object(forKey: "bypassRU") as? Bool ?? true
    @Published var connectOnDemand = UserDefaults.standard.bool(forKey: "connectOnDemand")
    @Published var killSwitch = UserDefaults.standard.bool(forKey: "killSwitch")
    @Published var dnsMode = UserDefaults.standard.string(forKey: "dnsMode") ?? "cloudflare"

    let vpn = VPNController()
    private var telegramTask: Task<Void, Never>?
    private var telegramGeneration = 0
    private var pendingConnect = false
    private var planLoadGeneration = 0
    private let api = ByMeAPI.shared

    var ru: Bool { L10n.isRussian(language) }
    func t(_ ru: String, _ en: String) -> String { L10n.text(ru, en, language: language) }
    var isSubscribed: Bool { subscription?.isActive == true }

    func boot() async {
        await vpn.load()
        guard SecureStorage.shared.accessToken != nil else { return }
        await refreshAll()
        if user == nil { screen = .signIn } else { screen = .home }
    }

    func navigate(_ destination: Screen) {
        screen = destination
        if destination == .pricing { Task { await loadPlans(devices: 2) } }
        if destination == .devices { Task { await loadDevices() } }
        if [.account, .home].contains(destination) { Task { await refreshAll() } }
    }

    func back() {
        switch screen {
        case .advanced: screen = .settings
        case .devices, .renewal, .support, .accountSettings: screen = .account
        case .trial, .pricing, .settings, .account: screen = .home
        case .signUp: screen = .signIn
        default: screen = user == nil ? .signIn : .home
        }
    }

    func setLanguage(_ value: String) {
        language = value
        UserDefaults.standard.set(value, forKey: "language")
    }
    func setBypassRU(_ value: Bool) {
        bypassRU = value
        UserDefaults.standard.set(value, forKey: "bypassRU")
    }
    func setAutoConnect(_ value: Bool) {
        connectOnDemand = value
        UserDefaults.standard.set(value, forKey: "connectOnDemand")
        if vpn.isConnected { message = t("Переподключите VPN, чтобы применить настройку.", "Reconnect VPN to apply this setting.") }
    }
    func setKillSwitch(_ value: Bool) {
        killSwitch = value
        UserDefaults.standard.set(value, forKey: "killSwitch")
        if vpn.isConnected { message = t("Переподключите VPN, чтобы применить настройку.", "Reconnect VPN to apply this setting.") }
    }
    func setDNS(_ value: String) {
        dnsMode = value
        UserDefaults.standard.set(value, forKey: "dnsMode")
        if vpn.isConnected { message = t("Переподключите VPN, чтобы сменить DNS.", "Reconnect VPN to change DNS.") }
    }

    func signIn(email: String, password: String) async {
        cancelTelegram()
        await run {
            let auth = try await self.api.login(email: email, password: password)
            self.user = auth.user
            self.subscription = auth.subscription
            self.nodes = []
            self.devices = []
            self.screen = .home
            await self.refreshAll()
        }
    }

    func signUp(name: String, email: String, password: String) async {
        cancelTelegram()
        await run {
            let auth = try await self.api.register(name: name, email: email, password: password)
            self.user = auth.user
            self.subscription = auth.subscription
            self.nodes = []
            self.screen = .home
            await self.refreshAll()
        }
    }

    func loginViaTelegram() async {
        guard telegramTask == nil else { return }
        telegramGeneration += 1
        let generation = telegramGeneration
        do {
            let session = try await api.createTelegramSession()
            telegramPending = true
            #if canImport(UIKit)
            await UIApplication.shared.open(session.botURL)
            #endif
            telegramTask = Task { [weak self] in
                guard let self else { return }
                defer {
                    if self.telegramGeneration == generation {
                        self.telegramPending = false
                        self.telegramTask = nil
                    }
                }
                var transientRetries = 0
                for _ in 0..<45 {
                    if Task.isCancelled { return }
                    do {
                        let (status, auth) = try await self.api.pollTelegram(session.token)
                        guard !Task.isCancelled, self.telegramGeneration == generation else { return }
                        if status == "authenticated", let auth {
                            self.user = auth.user
                            self.subscription = auth.subscription
                            self.screen = .home
                            await self.refreshAll()
                            return
                        }
                        if status == "expired" { self.message = self.t("Время входа истекло.", "Telegram sign-in expired."); return }
                        transientRetries = 0
                    } catch {
                        transientRetries += 1
                        if transientRetries > 2 { self.message = error.localizedDescription; return }
                    }
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                }
                self.message = self.t("Время ожидания Telegram истекло.", "Telegram sign-in timed out.")
            }
        } catch { message = error.localizedDescription }
    }

    func cancelTelegram() {
        telegramGeneration += 1
        telegramTask?.cancel()
        telegramTask = nil
        telegramPending = false
    }

    func refreshAll() async {
        guard SecureStorage.shared.accessToken != nil else { return }
        // Independently refresh account and entitlement. A temporary /servers
        // outage must not discard a valid login or keep users on the sign-in screen.
        do {
            user = try await api.me()
        } catch {
            if case ByMeError.expiredSession = error {
                await vpn.disconnect()
                user = nil; subscription = nil; nodes = []; devices = []; plans = []
                selectedNode = nil; screen = .signIn
            } else {
                message = error.localizedDescription
            }
            return
        }
        do {
            let current = try await api.subscription()
            subscription = current
            // Only a confirmed negative entitlement may tear down an existing tunnel.
            // A temporary backend outage must not convert a valid subscription to none.
            if !current.isActive && (vpn.isConnected || vpn.isBusy) {
                await vpn.disconnect()
                await api.stopVPNSession()
            }
        } catch {
            message = error.localizedDescription
        }
        do {
            nodes = try await api.servers()
            if !nodes.contains(where: { $0.code == selectedNode }) {
                selectedNode = nodes.first?.code
            }
        } catch {
            nodes = []
            message = error.localizedDescription
        }
    }

    func loadDevices() async {
        do { devices = try await api.devices() }
        catch { message = error.localizedDescription }
    }

    func removeDevice(_ device: Device) async {
        guard !device.isCurrent else { return }
        await run {
            try await self.api.deleteDevice(device.id)
            self.devices = try await self.api.devices()
        }
    }

    func loadPlans(devices: Int) async {
        planLoadGeneration += 1
        let generation = planLoadGeneration
        plans = []
        do {
            let result = try await api.plans(devices: devices)
            guard !Task.isCancelled, generation == planLoadGeneration else { return }
            plans = result
        } catch is CancellationError {
            // Changing the device tier cancels the obsolete catalog request.
        } catch {
            guard !Task.isCancelled, generation == planLoadGeneration else { return }
            message = t("Каталог тарифов недоступен: ", "Plan catalog unavailable: ") + error.localizedDescription
        }
    }

    func activateTrial() async {
        await run {
            self.subscription = try await self.api.activateTrial()
            self.screen = .home
            await self.refreshAll()
        }
    }

    func toggleVPN() async {
        if vpn.isConnected || vpn.isBusy {
            await vpn.disconnect()
            await api.stopVPNSession()
            return
        }
        guard UserDefaults.standard.bool(forKey: "vpnDisclosureAccepted") else {
            pendingConnect = true
            showVPNDisclosure = true
            return
        }
        await connect()
    }

    func acceptVPNDisclosure() {
        UserDefaults.standard.set(true, forKey: "vpnDisclosureAccepted")
        showVPNDisclosure = false
        if pendingConnect {
            pendingConnect = false
            Task { await connect() }
        }
    }

    private func connect() async {
        guard !loading else { return }
        await run {
            // Use *fresh server entitlement*, not a local flag or trial display.
            let sub = try await self.api.subscription()
            self.subscription = sub
            guard sub.isActive else { throw ByMeError.unavailable(self.t("Нужна активная подписка.", "An active subscription is required.")) }
            if self.nodes.isEmpty { self.nodes = try await self.api.servers() }
            guard let code = (self.nodes.first { $0.code == self.selectedNode } ?? self.nodes.first)?.code else {
                throw ByMeError.unavailable(self.t("Серверы недоступны.", "No servers available."))
            }
            self.selectedNode = code
            let session = try await self.api.startVPNSession(node: code)
            // Also release the server session if parsing or native configuration fails.
            // Otherwise an unsuccessful local connection can occupy a device slot.
            do {
                let json = try SingBoxConfiguration.make(session: session, bypassRussianSites: self.bypassRU,
                                                         dnsMode: self.dnsMode, killSwitch: self.killSwitch)
                try await self.vpn.connect(json: json, killSwitch: self.killSwitch, onDemand: self.connectOnDemand)
            } catch {
                await self.api.stopVPNSession()
                throw error
            }
        }
    }

    func signOut() async {
        await vpn.disconnect()
        cancelTelegram()
        await api.stopVPNSession()
        await api.logout()
        user = nil; subscription = nil; nodes = []; devices = []; plans = []
        selectedNode = nil
        screen = .signIn
    }

    func deleteAccount() async {
        await run {
            await self.vpn.disconnect()
            await self.api.stopVPNSession()
            try await self.api.deleteAccount()
            self.user = nil; self.subscription = nil; self.nodes = []; self.devices = []
            self.plans = []; self.selectedNode = nil
            self.screen = .signIn
        }
    }

    private func run(_ operation: () async throws -> Void) async {
        guard !loading else { return }
        loading = true
        defer { loading = false }
        do { try await operation() }
        catch { message = error.localizedDescription }
    }
}
