import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case english
    case indonesian

    var id: String { rawValue }

    var locale: Locale {
        switch self {
        case .system:
            return .autoupdatingCurrent
        case .english:
            return Locale(identifier: "en")
        case .indonesian:
            return Locale(identifier: "id")
        }
    }
}
