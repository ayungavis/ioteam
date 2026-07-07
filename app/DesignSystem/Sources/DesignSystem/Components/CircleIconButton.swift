import SwiftUI

public struct CircleIconButton: View {
    private let iconName: String
    private let action: () -> Void

    public init(iconName: String, action: @escaping () -> Void) {
        self.iconName = iconName
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: iconName)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.brandTextPrimary)
                .frame(width: 44, height: 44)
                .background(Color.brandCard)
                .clipShape(Circle())
        }
    }
}

#Preview {
    HStack(spacing: 12) {
        CircleIconButton(iconName: "plus") {}
        CircleIconButton(iconName: "bell") {}
    }
    .padding()
    .background(Color.brandSurface)
}
