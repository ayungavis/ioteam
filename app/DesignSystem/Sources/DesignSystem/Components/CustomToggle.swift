import SwiftUI

public struct CustomToggle: View {
    @Binding var isOn: Bool

    public init(isOn: Binding<Bool>) {
        _isOn = isOn
    }

    public var body: some View {
        ZStack {
            Capsule()
                .fill(isOn ? Color.brandAccent : Color.brandDisabledFill)
                .frame(width: 52, height: 32)
                .overlay(
                    Capsule()
                        .stroke(Color.brandBorder, lineWidth: isOn ? 0 : 1.5)
                )

            Circle()
                .fill(Color.white)
                .frame(width: 24, height: 24)
                .shadow(color: Color.black.opacity(0.15), radius: 2, x: 0, y: 1)
                .overlay(
                    Circle().stroke(Color.brandBorder, lineWidth: 0.5)
                )
                .offset(x: isOn ? 10 : -10)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isOn)
        }
        .onTapGesture {
            isOn.toggle()
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        CustomToggle(isOn: .constant(true))
        CustomToggle(isOn: .constant(false))
    }
    .padding()
    .background(Color.brandSurface)
}
