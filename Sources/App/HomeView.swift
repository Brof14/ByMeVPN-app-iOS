import SwiftUI
import NetworkExtension

struct HomeView: View {
    @EnvironmentObject private var store: ByMeStore

    var body: some View {
        HomeBody(vpn: store.vpn)
    }
}

private struct HomeBody: View {
    @EnvironmentObject private var store: ByMeStore
    @ObservedObject var vpn: VPNController
    @State private var showServers = false
    @State private var elapsedSeconds = 0
    @State private var connectedAt: Date?
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            topBar
            ScrollView {
                VStack(spacing: 17) {
                    if store.isSubscribed {
                        connectionCard
                        if let node = selectedNode { locationCard(node) }
                        HStack(spacing: 12) {
                            stateStat(icon: "lock.shield", title: store.t("Защищённый канал", "Encrypted tunnel"),
                                      detail: vpn.isConnected ? store.t("VPN активен", "VPN active") : store.t("VPN выключен", "VPN off"))
                            stateStat(icon: "clock", title: store.t("Время работы", "Session time"),
                                      detail: displayTime)
                        }
                        CardSurface {
                            HStack {
                                Image(systemName: "checkmark.seal.fill").foregroundStyle(Brand.mint)
                                Text(store.t("Подписка активна", "Subscription active"))
                                    .foregroundStyle(Brand.text).fontWeight(.semibold)
                                Spacer()
                                Text(store.subscription?.remainingDays.map { "\($0) \(store.t("дн.", "days"))" } ?? "—")
                                    .foregroundStyle(Brand.mint)
                            }
                            ByMeButton(title: store.t("Продлить подписку", "Renew subscription"), secondary: true) {
                                store.navigate(.pricing)
                            }
                        }
                    } else {
                        noPlanCard
                    }
                    Button { store.navigate(.support) } label: {
                        HStack {
                            Image(systemName: "questionmark.circle").foregroundStyle(Brand.mint)
                            Text(store.t("Не получается подключиться?", "Having trouble connecting?"))
                                .foregroundStyle(Brand.muted).font(.system(size: 13))
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(Brand.dim)
                        }.padding(14)
                    }
                }
                .padding(.horizontal, 25)
                .padding(.top, 12)
                .padding(.bottom, 25)
            }
            .refreshable { await store.refreshAll() }
            BottomTabs(selected: .home)
        }
        .sheet(isPresented: $showServers) { ServerListSheet() }
        .onReceive(ticker) { _ in
            if vpn.isConnected {
                if connectedAt == nil { connectedAt = Date() }
                elapsedSeconds = Int(Date().timeIntervalSince(connectedAt ?? Date()))
            } else {
                connectedAt = nil
                elapsedSeconds = 0
            }
        }
    }

    private var selectedNode: ServerNode? {
        store.nodes.first { $0.code == store.selectedNode } ?? store.nodes.first
    }

    private var topBar: some View {
        HStack {
            BrandShield(size: 39)
            Text("ByMeVPN").font(.system(size: 19, weight: .bold)).foregroundStyle(Brand.text)
            Spacer()
            Button { store.navigate(.support) } label: {
                Image(systemName: "questionmark.circle").font(.system(size: 20)).foregroundStyle(Brand.muted)
            }.accessibilityLabel(store.t("Поддержка", "Support"))
            Button { store.navigate(.account) } label: {
                Image(systemName: "person.crop.circle").font(.system(size: 22)).foregroundStyle(Brand.mint)
            }.accessibilityLabel(store.t("Аккаунт", "Account"))
        }
        .padding(.horizontal, 25).padding(.vertical, 15)
    }

    private var connectionCard: some View {
        VStack(spacing: 15) {
            SectionKicker(title: store.t("ВАШЕ ПОДКЛЮЧЕНИЕ", "YOUR CONNECTION"))
            Text(vpn.isConnected ? store.t("VPN запущен", "VPN started") :
                 vpn.isBusy || store.loading ? store.t("Подключение…", "Connecting…") :
                 store.t("VPN выключен", "VPN is off"))
                .font(.system(size: 29, weight: .bold)).foregroundStyle(Brand.text)
            Text(vpn.isConnected ? store.t("Туннель активен", "Tunnel active") :
                 store.t("Нажмите, чтобы подключиться", "Tap to connect"))
                .foregroundStyle(Brand.muted).font(.system(size: 12))
            Button {
                Task { await store.toggleVPN() }
            } label: {
                ZStack {
                    Circle().stroke(Brand.mint.opacity(vpn.isConnected ? 0.7 : 0.22), lineWidth: 2)
                        .frame(width: 205, height: 205)
                    Circle().fill(RadialGradient(colors: [Brand.mint.opacity(vpn.isConnected ? 0.18 : 0.05), .clear],
                                                center: .center, startRadius: 5, endRadius: 100))
                        .frame(width: 198, height: 198)
                    BrandShield(size: 137)
                        .scaleEffect(vpn.isBusy ? 0.97 : 1)
                    if vpn.isBusy {
                        ProgressView().tint(Brand.mint).scaleEffect(1.2).offset(y: 95)
                    }
                }.frame(width: 219, height: 219)
            }
            .disabled(store.loading || vpn.isBusy)
            .accessibilityLabel(vpn.isConnected ? store.t("Отключить VPN", "Disconnect VPN") : store.t("Подключить VPN", "Connect VPN"))
            .accessibilityAddTraits(.isButton)
            Text(vpn.isConnected ? store.t("Нажмите для отключения", "Tap to disconnect") :
                 store.t("Одно касание для подключения", "One tap to connect"))
                .foregroundStyle(Brand.dim).font(.system(size: 11))
            if let error = vpn.errorText {
                Text(error).font(.system(size: 12)).foregroundStyle(Color.red)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Brand.surface, in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Brand.border))
    }

    private func locationCard(_ node: ServerNode) -> some View {
        CardSurface {
            SectionKicker(title: store.t("МЕСТОПОЛОЖЕНИЕ", "LOCATION"))
            Button {
                showServers = true
            } label: {
                HStack(spacing: 13) {
                    Text(node.flag).font(.system(size: 31))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(node.displayName(store.ru)).foregroundStyle(Brand.text).font(.system(size: 15, weight: .semibold))
                        Text(node.protocolName).foregroundStyle(Brand.muted).font(.system(size: 11))
                    }
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down").foregroundStyle(Brand.mint)
                }
            }.buttonStyle(.plain)
        }
    }

    private func stateStat(icon: String, title: String, detail: String) -> some View {
        CardSurface {
            Image(systemName: icon).foregroundStyle(Brand.mint).font(.system(size: 16))
            Text(title).foregroundStyle(Brand.muted).font(.system(size: 10)).lineLimit(2)
            Text(detail).foregroundStyle(Brand.text).font(.system(size: 12, weight: .semibold)).lineLimit(2)
        }
    }

    private var displayTime: String {
        let hours = elapsedSeconds / 3600
        let minutes = (elapsedSeconds / 60) % 60
        let seconds = elapsedSeconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    private var noPlanCard: some View {
        VStack(spacing: 19) {
            VStack(spacing: 8) {
                Text("ByMeVPN").font(.system(size: 33, weight: .bold)).foregroundStyle(Brand.text)
                Text(store.t("Свободный интернет.\nОдно касание.", "Open internet.\nOne tap."))
                    .font(.system(size: 25, weight: .semibold)).foregroundStyle(Brand.text)
                    .multilineTextAlignment(.center)
                Text(store.t("Подключайтесь к привычным сервисам с ByMeVPN — без сложных настроек.",
                             "Connect to the services you use with ByMeVPN."))
                    .font(.system(size: 13)).foregroundStyle(Brand.muted).multilineTextAlignment(.center)
            }
            BrandShield(size: 155)
            HStack {
                Label(store.t("Простое подключение", "Easy connection"), systemImage: "bolt.fill")
                Spacer()
                Label(store.t("Защищённый VPN", "Secure VPN"), systemImage: "lock.shield.fill")
            }.font(.system(size: 10)).foregroundStyle(Brand.muted)
            CardSurface {
                Text(store.t("ДЛЯ НОВЫХ ПОЛЬЗОВАТЕЛЕЙ", "FOR NEW USERS"))
                    .font(.system(size: 10, weight: .bold)).foregroundStyle(Brand.mint)
                Text(store.t("3 дня бесплатно", "3 days free"))
                    .font(.system(size: 27, weight: .bold)).foregroundStyle(Brand.text)
                Text(store.t("Попробуйте сервис перед покупкой.", "Try the service before buying."))
                    .font(.system(size: 12)).foregroundStyle(Brand.muted)
                ByMeButton(title: store.t("Попробовать бесплатно", "Try for free")) {
                    store.navigate(.trial)
                }
            }
            ByMeButton(title: store.t("Посмотреть все тарифы", "See all plans"), secondary: true) {
                store.navigate(.pricing)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(Brand.surface, in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Brand.border))
    }
}

private struct ServerListSheet: View {
    @EnvironmentObject private var store: ByMeStore
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                if store.nodes.isEmpty {
                    Text(store.t("Серверы временно недоступны", "No servers available")).foregroundStyle(Brand.muted)
                }
                ForEach(store.nodes) { node in
                    Button {
                        if !store.vpn.isConnected {
                            store.selectedNode = node.code
                            dismiss()
                        } else {
                            store.message = store.t("Сначала отключите VPN, чтобы сменить сервер.",
                                                   "Disconnect VPN before changing servers.")
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Text(node.flag).font(.system(size: 25))
                            VStack(alignment: .leading) {
                                Text(node.displayName(store.ru)).foregroundStyle(Brand.text)
                                Text(node.protocolName).font(.caption).foregroundStyle(Brand.muted)
                            }
                            Spacer()
                            if store.selectedNode == node.code { Image(systemName: "checkmark.circle.fill").foregroundStyle(Brand.mint) }
                        }
                    }.listRowBackground(Brand.surface)
                }
            }.scrollContentBackground(.hidden).background(Brand.canvas)
                .navigationTitle(store.t("Список серверов", "Server list"))
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(store.t("Готово", "Done")) { dismiss() }
                    }
                }
                .refreshable { await store.refreshAll() }
        }
        .preferredColorScheme(.dark)
    }
}
