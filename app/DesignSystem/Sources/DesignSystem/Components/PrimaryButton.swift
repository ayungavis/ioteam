import SwiftUI

public struct PrimaryButton: View {
    public enum Icon {
        case none
        case arrow
        case checkmark
    }

    public enum Tint {
        case accent
        case success
    }

    private let title: LocalizedStringResource
    private let isValid: Bool
    private let isLoading: Bool
    private let icon: Icon
    private let tint: Tint
    private let action: () -> Void

    public init(
        _ title: LocalizedStringResource,
        isValid: Bool = true,
        isLoading: Bool = false,
        icon: Icon = .none,
        tint: Tint = .accent,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.isValid = isValid
        self.isLoading = isLoading
        self.icon = icon
        self.tint = tint
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                }

                Text(title)
                    .font(.system(size: 17, weight: .bold))

                if !isLoading {
                    switch icon {
                    case .none:
                        EmptyView()
                    case .arrow:
                        Image(systemName: "arrow.right")
                    case .checkmark:
                        Image(systemName: "checkmark")
                    }
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(fillColor.opacity(isValid ? 1.0 : 0.5))
            .clipShape(Capsule())
        }
        .disabled(!isValid || isLoading)
    }

    private var fillColor: Color {
        switch tint {
        case .accent:
            return .brandAccent
        case .success:
            return .brandSuccess
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        PrimaryButton("Continue", isValid: true, icon: .arrow) {}
        PrimaryButton("Add Device", icon: .checkmark, tint: .success) {}
        PrimaryButton("Connecting", isLoading: true) {}
        PrimaryButton("Continue", isValid: false, icon: .arrow) {}
    }
    .padding()
}
