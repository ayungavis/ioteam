import SwiftUI

public struct SecondaryButton: View {
    private let title: LocalizedStringResource
    private let isValid: Bool
    private let icon: String?
    private let action: () -> Void

    public init(
        _ title: LocalizedStringResource,
        isValid: Bool = true,
        icon: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.isValid = isValid
        self.icon = icon
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.system(size: 16, weight: .regular))
                Spacer()
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .regular))
                }
            }
            .foregroundStyle(Color.brandTextPrimary)
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity)
            .background(Color.brandCard)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .disabled(!isValid)
    }
}

#Preview {
    SecondaryButton("Add device", icon: "plus") {}
        .padding()
        .background(Color.brandSurface)
}
