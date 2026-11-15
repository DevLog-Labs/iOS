//
//  View+InputBackground.swift
//  PresentationShared
//
//  Created by opfic on 11/15/26.
//

import SwiftUI

public extension View {
    // 입력칸 바탕과 테두리, 여러 줄 입력칸은 더 큰 모서리 반경
    func inputBackground(
        isMultiline: Bool = false,
        isFocused: Bool = false,
        isInvalid: Bool = false
    ) -> some View {
        modifier(InputBackgroundModifier(isMultiline: isMultiline, isFocused: isFocused, isInvalid: isInvalid))
    }
}

private struct InputBackgroundModifier: ViewModifier {
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
    let isMultiline: Bool
    let isFocused: Bool
    let isInvalid: Bool

    func body(content: Content) -> some View {
        if isiOSAppOnMac {
            let shape = RoundedRectangle(cornerRadius: isMultiline ? CornerRadius.group : CornerRadius.control)
            let border = isInvalid ? Color.danger : isFocused ? .accent : isMultiline ? .multilineInputBorder : .inputBorder

            // Orca 입력칸처럼 라이트는 테두리만, 다크는 옅은 바탕과 테두리
            content
                .background(Color.inputFill, in: shape)
                .overlay { shape.strokeBorder(border) }
                .overlay {
                    if isFocused && !isInvalid {
                        shape.inset(by: -3).strokeBorder(Color.accent.opacity(0.3), lineWidth: 3)
                    }
                }
        } else {
            content.background(Color.secondaryBackground, in: .rect(cornerRadius: CornerRadius.control))
        }
    }
}
