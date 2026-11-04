import SwiftUI

struct SupportView: View {
    @EnvironmentObject private var store: ByMeStore
    @State private var expanded: Int?
    @State private var showAbout = false
    @State private var showLegal = false

    private var questions: [(String, String, String, String)] { [
        ("Как подключиться?", "How do I connect?",
         "Выберите сервер и нажмите на щит. iOS попросит разрешение на VPN-конфигурацию.", "Select a server and tap the shield. iOS will ask permission to add a VPN configuration."),
        ("Почему VPN не подключается?", "Why won't VPN connect?",
         "Проверьте подписку, сеть и выбранный сервер. Напишите в поддержку, если ошибка сохраняется.",
         "Check your subscription, network and selected server. Contact support if the error remains."),
        ("Как добавить устройство?", "How do I add a device?",
         "Войдите в тот же аккаунт ByMeVPN на другом устройстве.", "Sign in to the same ByMeVPN account on another device."),
        ("Как сменить язык?", "How do I change language?",
         "Настройки → Язык. Доступен русский и английский.", "Settings → Language. Russian and English are available.")
    ] }

    var body: some View {
        AppPage(title: store.t("Помощь", "Help"), tab: .settings) {
            CardSurface {
                Image(systemName: "bubble.left.and.bubble.right.fill").font(.system(size: 29)).foregroundStyle(Brand.mint)
                Text(store.t("Мы готовы помочь", "We're here to help"))
                    .font(.system(size: 24, weight: .semibold)).foregroundStyle(Brand.text)
                Text(store.t("По вопросам подключения, оплаты и аккаунта обращайтесь в поддержку ByMeVPN.",
                             "For help with connection, payment, or your account, contact ByMeVPN support."))
                    .font(.system(size: 13)).foregroundStyle(Brand.muted)
                Link(destination: URL(string: "mailto:support@bymevpn.com?subject=ByMeVPN%20support")!) {
                    HStack {
                        Image(systemName: "paperplane.fill")
                        Text(store.t("Написать в поддержку", "Contact support"))
                            .fontWeight(.semibold)
                    }.frame(maxWidth: .infinity).frame(height: 50)
                }
                .foregroundStyle(Brand.canvas)
                .background(Brand.mint, in: RoundedRectangle(cornerRadius: 14))
            }
            SectionKicker(title: store.t("Ответы на вопросы", "FAQ"))
            ForEach(questions.indices, id: \.self) { index in
                let q = questions[index]
                CardSurface {
                    Button {
                        withAnimation { expanded = expanded == index ? nil : index }
                    } label: {
                        HStack {
                            Text(store.ru ? q.0 : q.1).font(.system(size: 14, weight: .medium)).foregroundStyle(Brand.text)
                            Spacer()
                            Image(systemName: expanded == index ? "minus" : "plus").foregroundStyle(Brand.mint)
                        }
                    }
                    if expanded == index {
                        Text(store.ru ? q.2 : q.3).foregroundStyle(Brand.muted).font(.system(size: 12))
                    }
                }
            }
            SectionKicker(title: store.t("Информация", "Information"))
            CardSurface {
                SettingRow(icon: "info.circle", title: store.t("О приложении", "About the app")) {
                    showAbout = true
                }
                Divider().overlay(Brand.border)
                SettingRow(icon: "hand.raised",
                           title: store.t("Документы и приватность", "Privacy and documents")) {
                    showLegal = true
                }
            }
            Text(store.t("ByMeVPN · Скорость. Свобода. Простота.", "ByMeVPN · Speed. Freedom. Simplicity."))
                .foregroundStyle(Brand.dim).font(.system(size: 11)).frame(maxWidth: .infinity)
        }
        .alert(store.t("О приложении", "About the app"), isPresented: $showAbout) {
            Button("OK") {}
        } message: {
            Text("ByMeVPN iOS · " + (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"))
        }
        .sheet(isPresented: $showLegal) {
            NavigationStack {
                VStack(alignment: .leading, spacing: 22) {
                    Text(store.t("Правовые документы", "Legal documents"))
                        .font(.title2.bold()).foregroundStyle(Brand.text)
                    Link(store.t("Политика конфиденциальности", "Privacy policy"),
                         destination: URL(string: "https://bymevpn.com/privacy")!)
                    Link(store.t("Условия использования", "Terms of use"),
                         destination: URL(string: "https://bymevpn.com/terms")!)
                    Text("support@bymevpn.com").foregroundStyle(Brand.muted).font(.caption)
                    Spacer()
                }
                .padding(26)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Brand.canvas)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(store.t("Готово", "Done")) { showLegal = false }
                    }
                }
            }.preferredColorScheme(.dark)
        }
    }
}
