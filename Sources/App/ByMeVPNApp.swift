import SwiftUI

@main
struct ByMeVPNApp: App {
    @StateObject private var store = ByMeStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .preferredColorScheme(.dark)
                .task { await store.boot() }
                .onOpenURL { url in
                    guard url.scheme == "bymevpn" else { return }
                    // Returning from payment is never proof of payment.
                    Task { await store.refreshAll() }
                }
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var store: ByMeStore

    var body: some View {
        ZStack {
            BrandBackground()
            Group {
                switch store.screen {
                case .signIn: SignInView()
                case .signUp: SignUpView()
                case .home: HomeView()
                case .settings: SettingsView()
                case .advanced: AdvancedSettingsView()
                case .account: AccountView()
                case .accountSettings: AccountSettingsView()
                case .devices: DevicesView()
                case .renewal: RenewalView()
                case .support: SupportView()
                case .trial: TrialView()
                case .pricing: PricingView()
                }
            }
        }
        .tint(Brand.mint)
        .alert(store.t("Ошибка или уведомление", "Notice"), isPresented: Binding(
            get: { store.message != nil },
            set: { if !$0 { store.message = nil } }
        )) {
            Button("OK") { store.message = nil }
        } message: {
            Text(store.message ?? "")
        }
        .alert(store.t("Использование VPN", "VPN disclosure"), isPresented: $store.showVPNDisclosure) {
            Button(store.t("Отмена", "Cancel"), role: .cancel) {}
            Button(store.t("Продолжить", "Continue")) { store.acceptVPNDisclosure() }
        } message: {
            Text(store.t(
                "ByMeVPN создаёт системный VPN-туннель. Для подключения приложение отправляет на сервер учётные данные доступа, идентификатор установки и сведения об устройстве. VPN-сервер обрабатывает ваш сетевой трафик. Перед использованием ознакомьтесь с политикой конфиденциальности.",
                "ByMeVPN creates a system VPN tunnel. To connect, it sends your access credentials, installation identifier and device details to the server. The VPN server processes your network traffic. Review the privacy policy before use."
            ))
        }
        .animation(.easeInOut(duration: 0.2), value: store.screen)
    }
}
