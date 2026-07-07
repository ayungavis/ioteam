import Foundation
import SwiftUI

@Observable
final class LocaleManager {
    var languageCode: String {
        didSet {
            UserDefaults.standard.set(languageCode, forKey: "appLanguageCode")
        }
    }

    var language: AppLanguage {
        AppLanguage(rawValue: languageCode) ?? .system
    }

    var locale: Locale {
        language.locale
    }

    init() {
        self.languageCode = UserDefaults.standard.string(forKey: "appLanguageCode") ?? AppLanguage.system.rawValue
    }
}
