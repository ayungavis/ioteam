//
//  PrimaryButton.swift
//  DesignSystem
//
//  Created by Wahyu Kurniawan on 01/07/26.
//

import SwiftUI

public struct PrimaryButton: View {
    private let title: LocalizedStringResource
    private let isLoading: Bool
    private let action: () -> Void

    public init(title: LocalizedStringResource, isLoading: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.isLoading = isLoading
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack {
                if isLoading { ProgressView().tint(.white).padding(.trailing, 8) }
                Text(title).font(.headline).foregroundColor(.white)
            }
            .frame(maxWidth: .infinity).frame(height: 50)
            .background(Color.brandPrimary).cornerRadius(12)
        }
        .disabled(isLoading)
    }
}
