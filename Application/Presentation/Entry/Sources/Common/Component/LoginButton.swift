//
//  LoginButton.swift
//  Entry
//
//  Created by opfic on 4/25/25.
//

import SwiftUI

struct LoginButton: View {
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
    private var logo: Image?
    private var text = ""
    private let showsProgressView: Bool
    private let action: () -> Void

    init(
        logo: Image? = nil,
        text: String = "",
        showsProgressView: Bool = false,
        action: @escaping () -> Void = {}
    ) {
        self.logo = logo
        self.text = text
        self.showsProgressView = showsProgressView
        self.action = action
    }

    var body: some View {
        Button {
            action()
        } label: {
            Group {
                if showsProgressView {
                    ProgressView()
                } else {
                    HStack(spacing: 10 * AdaptiveSize.boardScale) {
                        if let logo {
                            logo
                                .resizable()
                                .scaledToFit()
                                .frame(width: 22 * AdaptiveSize.boardScale, height: 22 * AdaptiveSize.boardScale)
                        }
                        Text(text)
                            .font(isiOSAppOnMac ? .system(size: 13 * AdaptiveSize.boardScale) : .subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.label)
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: isiOSAppOnMac ? 40 * AdaptiveSize.boardScale : 52)
            .contentShape(.rect(cornerRadius: CornerRadius.control))
            .background {
                RoundedRectangle(cornerRadius: CornerRadius.control)
                    .fill(Color.secondaryBackground)
                    .stroke(Color.separator, lineWidth: 1)
            }
        }
    }
}
