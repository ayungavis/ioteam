import SwiftUI

/// In-app appearance override, persisted via AppStorage under "appTheme".
/// `.system` defers to the device's light/dark setting.
enum AppTheme: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    static let storageKey = "appTheme"

    var id: String { rawValue }

    /// nil means "follow the system setting" for .preferredColorScheme.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}
