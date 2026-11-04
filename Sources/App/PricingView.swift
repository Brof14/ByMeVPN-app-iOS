import SwiftUI

private enum PlanDuration: String, CaseIterable, Identifiable {
    case month1 = "1m", month4 = "3m", month8 = "6m", month15 = "12m"
    var id: String { rawValue }
    var days: Int {
        switch self { case .month1: return 30; case .month4: return 120; case .month8: return 240; case .month15: return 450 }
    }
    var months: Int { days / 30 }
    func title(_ ru: Bool) -> String {
        switch self {
        case .month1: return ru ? "1 месяц" : "1 month"
        case .month4: return ru ? "3 + 1 месяц" : "3 + 1 months"
        case .month8: return ru ? "6 + 2 месяца" : "6 + 2 months"
        case .month15: return ru ? "12 + 3 месяца" : "12 + 3 months"
        }
    }
}

struct PricingView: View {
    @EnvironmentObject private var store: ByMeStore
    @State private var tier = 2
    @State private var duration: PlanDuration = .month15
    @State private var loadingTier: Int?

    private var selectedPlan: PricingPlan? {
        store.plans.first {
            $0.code == "\(duration.rawValue)_d\(tier)" &&
            $0.devices == tier && $0.days == duration.days && $0.priceRub > 0
        }
    }

    var body: some View {
        AppPage(title: store.t("Выберите тариф", "Choose a plan"),
                subtitle: store.t("Одна подписка для всех ваших устройств", "One plan for all your devices")) {
            SectionKicker(title: store.t("СКОЛЬКО УСТРОЙСТВ?", "HOW MANY DEVICES?"))
            HStack(spacing: 10) {
                ForEach([2, 5, 10], id: \.self) { count in
                    Button {
                        tier = count
                    } label: {
                        Text("\(count) \(store.t("устр.", "devices"))")
                            .font(.system(size: 12, weight: .semibold))
                            .frame(maxWidth: .infinity).frame(height: 43)
                            .foregroundStyle(count == tier ? Brand.canvas : Brand.text)
                            .background(count == tier ? Brand.mint : Brand.surface,
                                        in: RoundedRectangle(cornerRadius: 11))
                            .overlay(RoundedRectangle(cornerRadius: 11).stroke(Brand.border))
                    }.buttonStyle(.plain)
                }
            }
            SectionKicker(title: store.t("СРОК ПОДПИСКИ", "SUBSCRIPTION LENGTH"))
            ForEach(PlanDuration.allCases) { period in
                let verified = store.plans.first {
                    $0.code == "\(period.rawValue)_d\(tier)" &&
                    $0.devices == tier && $0.days == period.days && $0.priceRub > 0
                }
                Button { duration = period } label: {
                    HStack(spacing: 12) {
                        Image(systemName: duration == period ? "largecircle.fill.circle" : "circle")
                            .foregroundStyle(Brand.mint).font(.system(size: 21))
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(period.title(store.ru)).font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Brand.text)
                                if period == .month15 {
                                    Text(store.t("ПОПУЛЯРНЫЙ", "POPULAR"))
                                        .font(.system(size: 9, weight: .bold)).foregroundStyle(Brand.canvas)
                                        .padding(.horizontal, 7).padding(.vertical, 4)
                                        .background(Brand.mint, in: Capsule())
                                }
                            }
                            Text(verified.map { "\(max(1, $0.priceRub / period.months)) ₽ / \(store.t("мес.", "mo."))" } ??
                                 store.t("Цена не подтверждена", "Price not confirmed"))
                                .font(.system(size: 11)).foregroundStyle(Brand.muted)
                        }
                        Spacer()
                        Text(verified.map { "\($0.priceRub) ₽" } ?? "—")
                            .foregroundStyle(Brand.text).font(.system(size: 19, weight: .bold))
                    }
                    .padding(17)
                    .background(duration == period ? Color(hex: 0x1A3340) : Brand.surface,
                                in: RoundedRectangle(cornerRadius: 17))
                    .overlay(RoundedRectangle(cornerRadius: 17)
                        .stroke(duration == period ? Brand.mint : Brand.border, lineWidth: 1))
                }.buttonStyle(.plain)
            }
            if loadingTier == tier {
                ProgressView().tint(Brand.mint).frame(maxWidth: .infinity)
            }
            CardSurface {
                HStack {
                    Text(store.t("Итого", "Total")).foregroundStyle(Brand.muted)
                    Spacer()
                    Text(selectedPlan.map { "\($0.priceRub) ₽" } ?? "—")
                        .font(.system(size: 26, weight: .bold)).foregroundStyle(Brand.text)
                }
                Text(store.t("Тарифы и цены подтверждаются сервером. Оплата в iOS будет доступна после интеграции StoreKit и серверной проверки покупок.",
                             "Plans and prices are server-confirmed. iOS checkout requires StoreKit and server-side purchase verification."))
                    .font(.system(size: 12)).foregroundStyle(Brand.muted)
                ByMeButton(title: store.t("Обновить тарифы", "Refresh plans"), secondary: true, busy: loadingTier == tier) {
                    Task { await reload() }
                }
            }
        }
        .task(id: tier) { await reload() }
    }

    private func reload() async {
        let requestedTier = tier
        loadingTier = requestedTier
        defer { if loadingTier == requestedTier { loadingTier = nil } }
        await store.loadPlans(devices: requestedTier)
    }
}
