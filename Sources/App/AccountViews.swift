import SwiftUI
import UIKit

struct AccountView: View {
    @EnvironmentObject private var store: ByMeStore
    @State private var confirmLogout = false

    var body: some View {
        AppPage(title: store.t("Аккаунт", "Account"), tab: .account) {
            HStack(spacing: 14) {
                Image(systemName: "person.crop.circle.fill").font(.system(size: 43)).foregroundStyle(Brand.mint)
                VStack(alignment: .leading, spacing: 4) {
                    Text(store.user?.name ?? store.t("Ваш аккаунт", "Your account"))
                        .font(.system(size: 17, weight: .semibold)).foregroundStyle(Brand.text)
                    Text(store.user?.email ?? "—").font(.system(size: 11)).foregroundStyle(Brand.muted)
                }
                Spacer()
                Text(store.isSubscribed ? store.t("Активен", "Active") : store.t("Без подписки", "No plan"))
                    .font(.system(size: 10, weight: .semibold))
                    .padding(.horizontal, 9).padding(.vertical, 7)
                    .foregroundStyle(store.isSubscribed ? Brand.mint : Color(hex: 0xE3A29A))
                    .background(store.isSubscribed ? Color(hex: 0x193743) : Color(hex: 0x2B2424),
                                in: RoundedRectangle(cornerRadius: 8))
            }
            CardSurface {
                SectionKicker(title: store.isSubscribed ? store.t("ПОДПИСКА BYMEVPN", "BYMEVPN SUBSCRIPTION") :
                                store.t("ВАШ ДОСТУП", "YOUR ACCESS"))
                if store.isSubscribed {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(store.subscription?.remainingDays.map(String.init) ?? "—")
                            .font(.system(size: 60, weight: .bold)).foregroundStyle(Brand.text)
                        Text(store.t("дн.", "days")).font(.system(size: 19, weight: .semibold)).foregroundStyle(Brand.mint)
                    }
                    Text(store.t("до окончания доступа", "until access expires"))
                        .foregroundStyle(Brand.muted).font(.system(size: 12))
                    Divider().overlay(Brand.border)
                    HStack {
                        Text(store.t("Ваш тариф", "Your plan")).foregroundStyle(Brand.muted)
                        Spacer()
                        Text(store.subscription?.planName ?? "—").foregroundStyle(Brand.text)
                    }.font(.system(size: 12))
                    ByMeButton(title: store.t("Продлить подписку", "Renew subscription"), secondary: true) {
                        store.navigate(.pricing)
                    }
                } else {
                    Text(store.t("Подписка не активна", "Subscription inactive"))
                        .font(.system(size: 24, weight: .bold)).foregroundStyle(Brand.text)
                    Text(store.t("Оформите подписку, чтобы подключаться к серверам ByMeVPN.",
                                 "Choose a plan to connect to ByMeVPN servers."))
                        .foregroundStyle(Brand.muted).font(.system(size: 12))
                    ByMeButton(title: store.t("3 дня бесплатно", "3 days free")) { store.navigate(.trial) }
                    ByMeButton(title: store.t("Посмотреть тарифы", "See plans"), secondary: true) { store.navigate(.pricing) }
                }
            }
            SectionKicker(title: store.t("Управление подпиской", "Subscription management"))
            CardSurface {
                SettingRow(icon: "iphone.gen3.radiowaves.left.and.right",
                           title: store.t("Мои устройства", "My devices"),
                           subtitle: store.subscription?.maxDevices == 0 ?
                           store.t("Лимит не подтверждён", "Limit not confirmed") :
                           "\(store.subscription?.activeDevices ?? 0) / \(store.subscription?.maxDevices ?? 0)") {
                    store.navigate(.devices)
                }
                Divider().overlay(Brand.border)
                SettingRow(icon: "calendar.badge.clock",
                           title: store.t("Срок и продление", "Expiry and renewal")) { store.navigate(.renewal) }
            }
            SectionKicker(title: store.t("Аккаунт", "Account"))
            CardSurface {
                SettingRow(icon: "person.crop.circle", title: store.t("Настройки аккаунта", "Account settings"),
                           subtitle: store.t("Профиль, подписка и доступ", "Profile, subscription and access")) {
                    store.navigate(.accountSettings)
                }
                Divider().overlay(Brand.border)
                SettingRow(icon: "questionmark.circle", title: store.t("Поддержка", "Support")) { store.navigate(.support) }
                Divider().overlay(Brand.border)
                SettingRow(icon: "arrow.clockwise", title: store.t("Обновить данные", "Refresh account")) {
                    Task { await store.refreshAll() }
                }
                Divider().overlay(Brand.border)
                SettingRow(icon: "rectangle.portrait.and.arrow.right",
                           title: store.t("Выйти из аккаунта", "Sign out")) { confirmLogout = true }
            }
        }
        .confirmationDialog(store.t("Выйти из аккаунта?", "Sign out?"), isPresented: $confirmLogout) {
            Button(store.t("Выйти", "Sign out"), role: .destructive) {
                Task { await store.signOut() }
            }
        }
    }
}

struct AccountSettingsView: View {
    @EnvironmentObject private var store: ByMeStore
    @State private var confirmDelete = false
    var body: some View {
        AppPage(title: store.t("Настройки аккаунта", "Account settings")) {
            SectionKicker(title: store.t("Профиль", "Profile"))
            CardSurface {
                valueRow(store.t("Имя", "Name"), store.user?.name ?? "—")
                Divider().overlay(Brand.border)
                valueRow("Email", store.user?.email ?? "—")
                Divider().overlay(Brand.border)
                HStack {
                    Text(store.t("ID аккаунта", "Account ID")).foregroundStyle(Brand.muted)
                    Spacer()
                    Button(store.t("Скопировать", "Copy")) {
                        UIPasteboard.general.string = store.user?.id
                        store.message = store.t("ID скопирован", "ID copied")
                    }.disabled(store.user?.id.isEmpty != false)
                }.font(.system(size: 13))
            }
            SectionKicker(title: store.t("Подписка", "Subscription"))
            CardSurface {
                valueRow(store.t("Статус", "Status"), store.subscription?.status ?? "none")
                valueRow(store.t("Осталось", "Remaining"),
                         store.subscription?.remainingDays.map { "\($0) \(store.t("дн.", "days"))" } ?? "—")
                valueRow(store.t("Устройства", "Devices"), "\(store.subscription?.activeDevices ?? 0) / \(store.subscription?.maxDevices ?? 0)")
                valueRow(store.t("Автопродление", "Auto renewal"),
                         store.subscription?.autoRenew.map { $0 ? store.t("Включено", "Enabled") : store.t("Выключено", "Disabled") } ?? "—")
            }
            SectionKicker(title: store.t("Управление", "Management"))
            CardSurface {
                SettingRow(icon: "iphone", title: store.t("Мои устройства", "My devices")) { store.navigate(.devices) }
                SettingRow(icon: "arrow.clockwise", title: store.t("Обновить аккаунт", "Refresh account")) {
                    Task { await store.refreshAll() }
                }
            }
            CardSurface {
                Text(store.t("Удаление аккаунта необратимо.", "Account deletion is irreversible."))
                    .font(.system(size: 12)).foregroundStyle(Brand.muted)
                Button(role: .destructive) { confirmDelete = true } label: {
                    Text(store.t("Удалить аккаунт", "Delete account"))
                        .font(.system(size: 14, weight: .semibold))
                }
            }
        }
        .confirmationDialog(store.t("Безвозвратно удалить аккаунт?", "Permanently delete account?"),
                            isPresented: $confirmDelete) {
            Button(store.t("Удалить навсегда", "Delete permanently"), role: .destructive) {
                Task { await store.deleteAccount() }
            }
        }
    }

    private func valueRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(Brand.muted)
            Spacer()
            Text(value).foregroundStyle(Brand.text).multilineTextAlignment(.trailing)
        }.font(.system(size: 13))
    }
}

struct DevicesView: View {
    @EnvironmentObject private var store: ByMeStore
    @State private var pendingDelete: Device?

    var body: some View {
        AppPage(title: store.t("Мои устройства", "My devices"), tab: .account) {
            CardSurface {
                SectionKicker(title: store.t("Подключенные устройства", "Connected devices"))
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(store.subscription?.activeDevices ?? store.devices.count)")
                        .font(.system(size: 50, weight: .bold)).foregroundStyle(Brand.text)
                    Text("/ \(store.subscription?.maxDevices == 0 ? "—" : String(store.subscription!.maxDevices))")
                        .font(.system(size: 20, weight: .medium)).foregroundStyle(Brand.muted)
                }
                Text(store.t("Ограничение зависит от подписки", "The limit depends on your plan"))
                    .font(.system(size: 12)).foregroundStyle(Brand.muted)
                SettingRow(icon: "arrow.clockwise", title: store.t("Обновить", "Refresh")) {
                    Task { await store.loadDevices() }
                }
            }
            SectionKicker(title: store.t("Это устройство и другие устройства", "This device and other devices"))
            CardSurface {
                HStack {
                    Image(systemName: "iphone").foregroundStyle(Brand.mint)
                    VStack(alignment: .leading) {
                        Text("iPhone / iPad").foregroundStyle(Brand.text)
                        Text(store.t("Это устройство", "This device")).foregroundStyle(Brand.muted).font(.caption)
                    }
                    Spacer()
                    Image(systemName: "checkmark.circle").foregroundStyle(Brand.mint)
                }
                ForEach(store.devices.filter { !$0.isCurrent }) { device in
                    Divider().overlay(Brand.border)
                    HStack {
                        Image(systemName: device.platform.lowercased().contains("windows") ? "desktopcomputer" : "iphone")
                            .foregroundStyle(Brand.mint)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(device.name).foregroundStyle(Brand.text)
                            Text(device.platform + " · " + device.lastSeen)
                                .font(.caption).foregroundStyle(Brand.muted)
                        }
                        Spacer()
                        Button(store.t("Удалить", "Remove"), role: .destructive) { pendingDelete = device }
                            .font(.system(size: 12))
                    }
                }
            }
            CardSurface {
                SectionKicker(title: store.t("ДОБАВИТЬ УСТРОЙСТВО", "ADD A DEVICE"))
                Text(store.t("Войдите в ByMeVPN на другом устройстве с тем же аккаунтом. Оно появится здесь после регистрации на сервере.",
                             "Sign in to ByMeVPN on another device using the same account. It will appear after server registration."))
                    .font(.system(size: 12)).foregroundStyle(Brand.muted)
            }
        }
        .confirmationDialog(store.t("Удалить устройство?", "Remove device?"),
                            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })) {
            Button(store.t("Удалить", "Remove"), role: .destructive) {
                if let device = pendingDelete { Task { await store.removeDevice(device) } }
                pendingDelete = nil
            }
        }
    }
}

struct RenewalView: View {
    @EnvironmentObject private var store: ByMeStore
    var body: some View {
        AppPage(title: store.t("Продление подписки", "Subscription renewal")) {
            CardSurface {
                Text(store.t("Текущая подписка", "Current subscription"))
                    .font(.system(size: 21, weight: .semibold)).foregroundStyle(Brand.text)
                Text(store.subscription?.planName ?? store.t("Нет активного тарифа", "No active plan"))
                    .foregroundStyle(Brand.muted)
                Text(store.subscription?.expiry ?? "—").font(.system(size: 14)).foregroundStyle(Brand.text)
                Text(store.subscription?.autoRenew == true ?
                     store.t("Автопродление включено", "Auto renewal enabled") :
                     store.t("Автопродление не подтверждено", "Auto renewal not confirmed"))
                    .foregroundStyle(Brand.muted).font(.system(size: 12))
                ByMeButton(title: store.t("Посмотреть тарифы", "View plans")) { store.navigate(.pricing) }
            }
            Text(store.t("Статус автопродления приходит с сервера. В iOS нельзя менять его локально без серверного API.",
                         "Auto-renewal status comes from the server. Changing it requires a backend API."))
                .font(.system(size: 12)).foregroundStyle(Brand.dim)
        }
    }
}
