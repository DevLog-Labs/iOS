//
//  NavigationBackButton.swift
//  PresentationShared
//
//  Created by opfic on 9/24/26.
//

import SwiftUI

public struct NavigationBackButton: View {
    private let action: () -> Void

    public init(action: @escaping () -> Void) {
        self.action = action
    }

    public var body: some View {
        if #available(iOS 26.0, *) {
            Button(action: action) {
                Image(systemName: "chevron.left")
            }
            .topBarButtonStyle()
        } else {
            Button(action: action) {
                Image(systemName: "chevron.left")
                    .font(.adaptive(.title3).weight(.semibold))
                    .frame(width: 28 * AdaptiveSize.scale, height: 28 * AdaptiveSize.scale)
            }
            .adaptiveButtonStyle(shape: .circle, color: .secondaryBackground, glassEffect: .enabled)
        }
    }
}
