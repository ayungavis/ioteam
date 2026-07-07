import SwiftUI
import UIKit

/// Brand tokens resolve per trait collection so every screen adapts to light/dark
/// automatically — views should only ever use these, never raw Color literals.
private func adaptive(light: UIColor, dark: UIColor) -> Color {
    Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark ? dark : light
    })
}

private func rgb(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> UIColor {
    UIColor(red: red / 255, green: green / 255, blue: blue / 255, alpha: alpha)
}

public extension Color {
    static let brandSurface = adaptive(light: rgb(244, 245, 246), dark: rgb(18, 18, 20))
    static let brandCard = adaptive(light: .white, dark: rgb(28, 28, 30))
    static let brandNavSurface = adaptive(light: rgb(236, 236, 236), dark: rgb(24, 24, 26))

    static let brandAccent = Color(uiColor: rgb(255, 145, 0))
    static let brandAccentStrong = Color(uiColor: rgb(255, 90, 0))
    static let brandAccentLight = adaptive(light: rgb(255, 218, 166), dark: rgb(92, 60, 16))
    static let brandSuccess = Color(uiColor: rgb(34, 197, 94))

    static let brandTextPrimary = adaptive(light: .black, dark: .white)
    static let brandTextSecondary = adaptive(light: rgb(0, 0, 0, 0.6), dark: rgb(255, 255, 255, 0.65))
    static let brandTextTertiary = adaptive(light: rgb(0, 0, 0, 0.45), dark: rgb(255, 255, 255, 0.45))

    static let brandBorder = adaptive(light: rgb(0, 0, 0, 0.15), dark: rgb(255, 255, 255, 0.18))
    static let brandDisabledFill = adaptive(light: rgb(0, 0, 0, 0.05), dark: rgb(255, 255, 255, 0.08))
}
