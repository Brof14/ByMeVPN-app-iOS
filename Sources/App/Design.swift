import SwiftUI

enum Brand {
    static let canvas = Color(hex: 0x090F1D)
    static let surface = Color(hex: 0x121C2B)
    static let elevated = Color(hex: 0x18283A)
    static let border = Color(hex: 0x263647)
    static let mint = Color(hex: 0x69D3BC)
    static let mintLight = Color(hex: 0x79D9C4)
    static let text = Color(hex: 0xEEF4F4)
    static let muted = Color(hex: 0x9CACBD)
    static let dim = Color(hex: 0x7D94A8)
}
extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xff)/255,
                  green: Double((hex >> 8) & 0xff)/255,
                  blue: Double(hex & 0xff)/255, opacity: 1)
    }
}

struct BrandBackground: View {
    var body: some View {
        ZStack {
            Brand.canvas.ignoresSafeArea()
            RadialGradient(colors: [Color(hex: 0x152E57).opacity(0.24), .clear],
                           center: .top, startRadius: 15, endRadius: 360).ignoresSafeArea()
        }
    }
}

struct CardSurface<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 14) { content }
            .padding(19)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Brand.surface, in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Brand.border, lineWidth: 1))
    }
}

struct ByMeButton: View {
    let title: String
    var secondary = false
    var disabled = false
    var busy = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if busy { ProgressView().tint(secondary ? Brand.mint : Brand.canvas) }
                Text(title).font(.system(size: 15, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .foregroundStyle(secondary ? Brand.text : Color(hex: 0x0A2431))
            .background(
                secondary ? AnyShapeStyle(Brand.elevated) :
                    AnyShapeStyle(LinearGradient(colors: [Brand.mint, Color(hex: 0x64C0D4)], startPoint: .leading, endPoint: .trailing)),
                in: RoundedRectangle(cornerRadius: 15)
            )
            .overlay(RoundedRectangle(cornerRadius: 15).stroke(secondary ? Brand.border : .clear))
            .opacity(disabled ? 0.48 : 1)
        }
        .buttonStyle(.plain)
        .disabled(disabled || busy)
        .accessibilityAddTraits(.isButton)
    }
}

struct PageHeader: View {
    @EnvironmentObject var store: ByMeStore
    let title: String
    var subtitle: String? = nil

    var body: some View {
        HStack(spacing: 14) {
            Button { store.back() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Brand.text)
                    .frame(width: 39, height: 39)
                    .background(Brand.elevated, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Brand.border))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 26, weight: .bold)).foregroundStyle(Brand.text)
                if let subtitle { Text(subtitle).font(.system(size: 12)).foregroundStyle(Brand.muted) }
            }
            Spacer()
        }
        .padding(.horizontal, 25)
        .padding(.top, 15)
        .padding(.bottom, 18)
    }
}

struct SettingRow: View {
    let icon: String
    let title: String
    var subtitle: String? = nil
    var trailing: String? = nil
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 13) {
                Image(systemName: icon).font(.system(size: 18)).foregroundStyle(Brand.mint)
                    .frame(width: 31, height: 31)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).foregroundStyle(Brand.text).font(.system(size: 14, weight: .medium))
                    if let subtitle { Text(subtitle).foregroundStyle(Brand.muted).font(.system(size: 11)) }
                }
                Spacer()
                if let trailing { Text(trailing).font(.system(size: 12)).foregroundStyle(Brand.muted) }
                Image(systemName: "chevron.right").font(.system(size: 11, weight: .medium)).foregroundStyle(Brand.dim)
            }
            .padding(.vertical, 5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct SettingToggleRow: View {
    let icon: String
    let title: String
    var subtitle: String? = nil
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: icon).font(.system(size: 18)).foregroundStyle(Brand.mint).frame(width: 31, height: 31)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).foregroundStyle(Brand.text).font(.system(size: 14, weight: .medium))
                if let subtitle { Text(subtitle).font(.system(size: 11)).foregroundStyle(Brand.muted) }
            }
            Spacer()
            Toggle("", isOn: $isOn).labelsHidden().tint(Brand.mint)
        }
    }
}

struct SectionKicker: View {
    let title: String
    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .bold))
            .tracking(1.3)
            .foregroundStyle(Brand.dim)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct BottomTabs: View {
    @EnvironmentObject var store: ByMeStore
    let selected: Screen

    var body: some View {
        HStack {
            item(icon: "house", title: store.t("Главная", "Home"), screen: .home)
            Spacer()
            item(icon: "gearshape", title: store.t("Настройки", "Settings"), screen: .settings)
            Spacer()
            item(icon: "person.crop.circle", title: store.t("Аккаунт", "Account"), screen: .account)
        }
        .padding(.horizontal, 35)
        .padding(.vertical, 11)
        .background(Color(hex: 0x101A29))
        .overlay(alignment: .top) { Rectangle().fill(Color(hex: 0x243447)).frame(height: 1) }
    }
    private func item(icon: String, title: String, screen: Screen) -> some View {
        Button { store.navigate(screen) } label: {
            VStack(spacing: 5) {
                Image(systemName: selected == screen ? icon + ".fill" : icon).font(.system(size: 19))
                Text(title).font(.system(size: 10, weight: selected == screen ? .semibold : .regular))
            }
            .foregroundStyle(selected == screen ? Brand.mint : Brand.dim)
            .frame(minWidth: 65)
        }
        .buttonStyle(.plain)
    }
}

struct AppPage<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    var tab: Screen? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            PageHeader(title: title, subtitle: subtitle)
            ScrollView {
                VStack(alignment: .leading, spacing: 18) { content }
                    .padding(.horizontal, 25).padding(.bottom, 25)
            }
            if let tab { BottomTabs(selected: tab) }
        }
    }
}

struct BrandShield: View {
    var size: CGFloat = 96
    var body: some View {
        Image("Shield")
            .resizable().scaledToFit()
            .frame(width: size, height: size)
            .accessibilityLabel("ByMeVPN")
    }
}
