import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case system, ru, en
    var id: String { rawValue }
    var label: String {
        switch self {
        case .system: return "System / Системный"
        case .ru: return "Русский"
        case .en: return "English"
        }
    }
}
struct L10n {
    static func isRussian(_ language: String) -> Bool {
        if language == "ru" { return true }
        if language == "en" { return false }
        return Locale.preferredLanguages.first?.lowercased().hasPrefix("ru") ?? true
    }
    static func text(_ ru: String, _ en: String, language: String) -> String {
        isRussian(language) ? ru : en
    }
}
