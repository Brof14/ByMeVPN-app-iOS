import SwiftUI

struct SupportView: View {
    @EnvironmentObject private var store: ByMeStore
    @State private var expanded: Int?

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
        AppPage(title: store.t("Поддержка", "Support")) {
            CardSurface {
                Image(systemName: "bubble.left.and.bubble.right.fill").font(.system(size: 29)).foregroundStyle(Brand.mint)
                Text(store.t("Мы готовы помочь", "We're here to help"))
                    .font(.system(size: 24, weight: .semibold)).foregroundStyle(Brand.text)
                Text(store.t("По вопросам подключения, оплаты и аккаунта обращайтесь в поддержку ByMeVPN.",
                             "For help with connection, payment, or your account, contact ByMeVPN support."))
                    .font(.system(size: 13)).foregroundStyle(Brand.muted)
                Link(destination: ByMeConfiguration.supportURL) {
                    HStack {
                        Image(systemName: "paperplane.fill")
                        Text(store.t("Написать в Telegram", "Contact via Telegram"))
                            .fontWeight(.semibold)
                    }.frame(maxWidth: .infinity).frame(height: 50)
                }
                .foregroundStyle(Brand.canvas)
                .background(Brand.mint, in: RoundedRectangle(cornerRadius: 14))
            }
            SectionKicker(title: store.t("Частые вопросы", "Frequently asked questions"))
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
        }
    }
}
