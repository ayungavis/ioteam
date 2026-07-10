import SwiftUI
import UIKit

extension UIApplication {
    /// Resigns whatever text field currently holds focus, hiding the keyboard.
    func endEditing() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

extension View {
    /// App-wide keyboard escape hatches:
    /// - dragging any scroll view pushes the keyboard away interactively
    /// - every keyboard gets a "Done" button (number pads have no return key)
    ///
    /// Apply once per presentation context: the window root covers all pushed
    /// screens; each `.sheet` root needs its own (sheets don't inherit toolbars).
    func keyboardDismissal() -> some View {
        self
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.endEditing()
                    }
                    .fontWeight(.semibold)
                }
            }
    }
}
