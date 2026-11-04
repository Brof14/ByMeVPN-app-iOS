import SwiftUI

struct SignInView: View {
    @EnvironmentObject private var store: ByMeStore
    @State private var email = ""
    @State private var password = ""
    @State private var visiblePassword = false

    var body: some View {
        ScrollView {
            VStack(spacing: 23) {
                Spacer(minLength: 26)
                BrandShield(size: 105)
                VStack(spacing: 7) {
                    Text("ByMeVPN").font(.system(size: 35, weight: .bold)).foregroundStyle(Brand.text)
                    Text(store.t("Войдите в свой аккаунт", "Sign in to your account"))
                        .font(.system(size: 14)).foregroundStyle(Brand.muted)
                }
                VStack(alignment: .leading, spacing: 14) {
                    fieldTitle("Email")
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress).keyboardType(.emailAddress).textInputAutocapitalization(.never)
                        .autocorrectionDisabled().modifier(AuthField())
                    fieldTitle(store.t("Пароль", "Password"))
                    HStack {
                        Group {
                            if visiblePassword { TextField(store.t("Пароль", "Password"), text: $password) }
                            else { SecureField(store.t("Пароль", "Password"), text: $password) }
                        }
                        .textContentType(.password)
                        Button { visiblePassword.toggle() } label: {
                            Image(systemName: visiblePassword ? "eye.slash" : "eye").foregroundStyle(Brand.muted)
                        }
                    }
                    .modifier(AuthField())
                    ByMeButton(title: store.t("Войти", "Sign in"), disabled: email.isEmpty || password.isEmpty,
                               busy: store.loading) {
                        Task { await store.signIn(email: email, password: password) }
                    }
                    HStack(spacing: 8) {
                        Rectangle().fill(Brand.border).frame(height: 1)
                        Text(store.t("или", "or")).font(.caption).foregroundStyle(Brand.dim)
                        Rectangle().fill(Brand.border).frame(height: 1)
                    }.padding(.vertical, 3)
                    ByMeButton(title: store.telegramPending ?
                               store.t("Ожидание Telegram…", "Waiting for Telegram…") :
                               store.t("Продолжить через Telegram", "Continue with Telegram"),
                               secondary: true, disabled: store.telegramPending) {
                        Task { await store.loginViaTelegram() }
                    }
                    if store.telegramPending {
                        Button(store.t("Отменить вход через Telegram", "Cancel Telegram sign-in")) { store.cancelTelegram() }
                            .font(.system(size: 12)).frame(maxWidth: .infinity)
                    }
                    Button(store.t("Войти через Google", "Continue with Google")) {
                        store.message = store.t("Для Google Sign-In нужно настроить iOS OAuth Client ID и GoogleSignIn SDK.",
                                                "Google Sign-In requires an iOS OAuth client ID and GoogleSignIn SDK.")
                    }
                    .font(.system(size: 12)).foregroundStyle(Brand.muted).frame(maxWidth: .infinity)
                }
                HStack {
                    Text(store.t("Нет аккаунта?", "No account?")).foregroundStyle(Brand.muted)
                    Button(store.t("Регистрация", "Sign up")) { store.navigate(.signUp) }
                        .accessibilityIdentifier("auth.signUp")
                        .foregroundStyle(Brand.mint).fontWeight(.semibold)
                }.font(.system(size: 13))
                Link(store.t("Поддержка", "Support"), destination: ByMeConfiguration.supportURL)
                    .foregroundStyle(Brand.dim).font(.system(size: 12))
            }.padding(28).frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
    }
    private func fieldTitle(_ title: String) -> some View {
        Text(title).foregroundStyle(Brand.muted).font(.system(size: 12, weight: .medium))
    }
}

struct AuthField: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 15)).foregroundStyle(Brand.text)
            .padding(.horizontal, 16).frame(height: 52)
            .background(Color(hex: 0x111C2B), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: 0x2B4051)))
    }
}

struct SignUpView: View {
    @EnvironmentObject private var store: ByMeStore
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var repeatedPassword = ""
    @State private var accepted = false

    private var valid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        email.contains("@") && password.count >= 8 &&
        password == repeatedPassword && accepted
    }

    var body: some View {
        VStack(spacing: 0) {
            PageHeader(title: store.t("Создать аккаунт", "Create account"))
            ScrollView {
                VStack(alignment: .leading, spacing: 15) {
                    BrandShield(size: 70).frame(maxWidth: .infinity)
                    Text(store.t("Один аккаунт — все ваши устройства", "One account for all your devices"))
                        .font(.system(size: 15)).foregroundStyle(Brand.muted)
                    Text(store.t("Имя", "Name")).foregroundStyle(Brand.muted)
                    TextField(store.t("Ваше имя", "Your name"), text: $name).textContentType(.name).modifier(AuthField())
                    Text("Email").foregroundStyle(Brand.muted)
                    TextField("Email", text: $email).keyboardType(.emailAddress)
                        .textContentType(.emailAddress).textInputAutocapitalization(.never)
                        .autocorrectionDisabled().modifier(AuthField())
                    Text(store.t("Пароль (от 8 символов)", "Password (8+ characters)")).foregroundStyle(Brand.muted)
                    SecureField(store.t("Пароль", "Password"), text: $password).textContentType(.newPassword).modifier(AuthField())
                    Text(store.t("Повторите пароль", "Confirm password")).foregroundStyle(Brand.muted)
                    SecureField(store.t("Повторите пароль", "Confirm password"), text: $repeatedPassword)
                        .textContentType(.newPassword).modifier(AuthField())
                    Toggle(isOn: $accepted) {
                        Text(store.t("Я ознакомился с условиями использования и политикой конфиденциальности",
                                     "I have reviewed the terms and privacy policy"))
                            .font(.system(size: 12)).foregroundStyle(Brand.muted)
                    }.tint(Brand.mint)
                    ByMeButton(title: store.t("Зарегистрироваться", "Create account"),
                               disabled: !valid, busy: store.loading) {
                        Task { await store.signUp(name: name, email: email, password: password) }
                    }
                    Button(store.t("Уже есть аккаунт? Войти", "Already have an account? Sign in")) {
                        store.navigate(.signIn)
                    }.accessibilityIdentifier("auth.signIn")
                     .font(.system(size: 13)).frame(maxWidth: .infinity)
                }
                .font(.system(size: 12)).padding(.horizontal, 27).padding(.bottom, 30)
            }.scrollDismissesKeyboard(.interactively)
        }
    }
}
