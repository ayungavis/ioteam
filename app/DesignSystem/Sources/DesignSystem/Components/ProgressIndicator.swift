import SwiftUI

public enum StepState {
    case active
    case completed
    case upcoming
}

public struct ProgressIndicatorView: View {
    private let step1: (label: String, state: StepState)
    private let step2: (label: String, state: StepState)
    private let step3: (label: String, state: StepState)

    public init(step1: String, state1: StepState,
                step2: String, state2: StepState,
                step3: String, state3: StepState) {
        self.step1 = (step1, state1)
        self.step2 = (step2, state2)
        self.step3 = (step3, state3)
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 0) {
            StepItem(number: "1", title: step1.label, state: step1.state)
            connector
            StepItem(number: "2", title: step2.label, state: step2.state)
            connector
            StepItem(number: "3", title: step3.label, state: step3.state)
        }
        .frame(maxWidth: .infinity)
    }

    private var connector: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.3))
            .frame(height: 1)
            .frame(width: 40)
            .offset(y: 22)
    }
}

public struct StepItem: View {
    private let number: String
    private let title: String
    private let state: StepState

    public init(number: String, title: String, state: StepState) {
        self.number = number
        self.title = title
        self.state = state
    }

    public var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(fillColor)
                    .frame(width: 44, height: 44)

                if state == .upcoming {
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        .frame(width: 44, height: 44)
                }

                Text(number)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(numberColor)
            }

            Text(title)
                .font(.system(size: 11, weight: .regular))
                .foregroundColor(textColor)
                .lineLimit(1)
                .fixedSize()
        }
    }

    private var fillColor: Color {
        switch state {
        case .active: return .brandAccent
        case .completed: return .brandAccentLight
        case .upcoming: return .clear
        }
    }

    private var numberColor: Color {
        switch state {
        case .active: return .white
        case .completed: return .brandAccent
        case .upcoming: return .gray.opacity(0.5)
        }
    }

    private var textColor: Color {
        switch state {
        case .active: return .brandAccent
        case .completed: return .brandAccentLight
        case .upcoming: return .gray.opacity(0.5)
        }
    }
}

#Preview {
    ProgressIndicatorView(
        step1: "Select Device", state1: .completed,
        step2: "Connect Bluetooth", state2: .active,
        step3: "Name Device", state3: .upcoming
    )
    .padding()
    .background(Color.brandSurface)
}
