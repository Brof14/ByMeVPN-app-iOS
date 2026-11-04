import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: ByMeStore

    var body: some View {
        AppPage(title: store.t("Настройки", "Settings"), tab: .settings) {
            Text(store.t("Приложение работает за вас.", "The app works for you."))
                .font(.system(size: 22, weight: .semibold)).foregroundStyle(Brand.text)
            Text(store.t("Основные настройки уже подобраны. При желании их можно изменить.",
                         "The defaults are ready to use. You can change them if needed."))
                .font(.system(size: 12)).foregroundStyle(Brand.muted)
            SectionKicker(title: store.t("Подключение", "Connection"))
            CardSurface {
                SettingToggleRow(icon: "arrow.triangle.2.circlepath",
                                 title: store.t("Подключаться автоматически", "Connect automatically"),
                                 subtitle: store.t("Через VPN On Demand", "Using VPN On Demand"),
                                 isOn: Binding(get: { store.connectOnDemand }, set: { store.setAutoConnect($0) }))
                Divider().overlay(Brand.border)
                SettingToggleRow(icon: "globe.europe.africa",
                                 title: store.t("Российские сайты напрямую", "Russian sites directly"),
                                 subtitle: store.t("Домены .ru, .рф, .su", "Domains .ru, .рф, .su"),
                                 isOn: Binding(get: { store.bypassRU }, set: { store.setBypassRU($0) }))
            }
            SectionKicker(title: store.t("Язык приложения", "App language"))
            CardSurface {
                HStack {
                    Label(store.t("Язык", "Language"), systemImage: "character.bubble").foregroundStyle(Brand.text)
                    Spacer()
                    Picker("", selection: Binding(get: { store.language }, set: { store.setLanguage($0) })) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(language.label).tag(language.rawValue)
                        }
                    }.labelsHidden().tint(Brand.mint)
                }
            }
            SectionKicker(title: store.t("Дополнительно", "Advanced"))
            CardSurface {
                SettingRow(icon: "slider.horizontal.3",
                           title: store.t("Дополнительные настройки", "Advanced settings"),
                           subtitle: store.t("Защита, DNS, переподключение", "Protection, DNS, reconnect")) {
                    store.navigate(.advanced)
                }
            }
            Text(store.t("Не уверены, что выбрать? Оставьте настройки по умолчанию.",
                         "Not sure? Keep the default settings."))
                .foregroundStyle(Brand.dim).font(.system(size: 12))
        }
    }
}

struct AdvancedSettingsView: View {
    @EnvironmentObject private var store: ByMeStore

    var body: some View {
        AppPage(title: store.t("Дополнительно", "More settings"), tab: .settings) {
            Text(store.t("Эти параметры необязательно изменять. Они нужны для особых сценариев подключения.",
                         "You can change these options for special connection scenarios."))
                .font(.system(size: 13)).foregroundStyle(Brand.muted)
            SectionKicker(title: store.t("Защита", "Protection"))
            CardSurface {
                SettingToggleRow(icon: "shield.lefthalf.filled",
                                 title: store.t("Защита при обрыве VPN", "Protection if VPN disconnects"),
                                 subtitle: store.t("Включить системный kill switch", "Enable system kill switch"),
                                 isOn: Binding(get: { store.killSwitch }, set: { store.setKillSwitch($0) }))
            }
            SectionKicker(title: "DNS")
            CardSurface {
                HStack {
                    Image(systemName: "network").foregroundStyle(Brand.mint)
                    Text(store.t("DNS-сервер", "DNS server")).foregroundStyle(Brand.text)
                    Spacer()
                    Picker("DNS", selection: Binding(get: { store.dnsMode }, set: { store.setDNS($0) })) {
                        Text("Cloudflare").tag("cloudflare")
                        Text("AdGuard").tag("adguard")
                        Text("Google").tag("google")
                    }.labelsHidden()
                }
            }
            Text(store.t("Изменения VPN-маршрутизации применяются при следующем подключении.",
                         "VPN routing changes apply the next time you connect."))
                .foregroundStyle(Brand.dim).font(.system(size: 12))
        }
    }
}

struct TrialView: View {
    @EnvironmentObject private var store: ByMeStore
    var body: some View {
        AppPage(title: store.t("3 дня бесплатно", "3 days free"),
                subtitle: store.t("Без привязки банковской карты", "No bank card required")) {
            CardSurface {
                BrandShield(size: 105).frame(maxWidth: .infinity)
                Text(store.t("Попробуйте ByMeVPN бесплатно", "Try ByMeVPN for free"))
                    .font(.system(size: 24, weight: .bold)).foregroundStyle(Brand.text)
                Text(store.t("Пробный период активируется сервером и доступен только новым пользователям.",
                             "The trial is activated by the server and is available only to eligible new users."))
                    .foregroundStyle(Brand.muted).font(.system(size: 13))
                ByMeButton(title: store.t("Активировать 3 дня", "Activate 3 days"),
                           disabled: store.subscription?.trialAvailable != true,
                           busy: store.loading) {
                    Task { await store.activateTrial() }
                }
                if store.subscription?.trialAvailable != true {
                    Text(store.t("Пробный период недоступен для этого аккаунта.",
                                 "Trial is not available for this account."))
                        .foregroundStyle(Brand.dim).font(.system(size: 12))
                }
            }
            ByMeButton(title: store.t("Выбрать тариф", "Choose a plan"), secondary: true) {
                store.navigate(.pricing)
            }
        }
    }
}
