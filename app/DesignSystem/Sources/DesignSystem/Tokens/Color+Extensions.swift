import SwiftUI

public extension Color {
    static let brandSurface = Color(red: 244/255, green: 245/255, blue: 246/255)
    static let brandCard = Color.white
    static let brandNavSurface = Color(red: 236/255, green: 236/255, blue: 236/255)

    static let brandAccent = Color(red: 255/255, green: 145/255, blue: 0/255)
    static let brandAccentStrong = Color(red: 255/255, green: 90/255, blue: 0/255)
    static let brandAccentLight = Color(red: 255/255, green: 218/255, blue: 166/255)
    static let brandSuccess = Color(red: 34/255, green: 197/255, blue: 94/255)

    static let brandTextPrimary = Color.black
    static let brandTextSecondary = Color.black.opacity(0.6)
    static let brandTextTertiary = Color.black.opacity(0.45)

    static let brandBorder = Color.black.opacity(0.15)
    static let brandDisabledFill = Color.black.opacity(0.05)
}
