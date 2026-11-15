//
//  View+HoverHighlight.swift
//  PresentationShared
//
//  Created by opfic on 11/15/26.
//

import SwiftUI

public extension View {
    // Mac에서 마우스를 올린 동안 누를 수 있는 영역에 옅은 채움 표시
    func hoverHighlight<S: Shape>(in shape: S = Rectangle(), isEnabled: Bool = true) -> some View {
        modifier(HoverHighlightModifier(shape: shape, isEnabled: isEnabled))
    }
}

private struct HoverHighlightModifier<S: Shape>: ViewModifier {
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
    @Environment(\.isEnabled) private var isEnvironmentEnabled
    @State private var isHovered = false
    let shape: S
    let isEnabled: Bool

    func body(content: Content) -> some View {
        content
            .background {
                if isiOSAppOnMac && isEnabled && isEnvironmentEnabled && isHovered {
                    shape.fill(Color.fill)
                }
            }
            // 글자 사이 빈 곳에 올려도 반응하도록 영역 전체로 감지
            .contentShape(.interaction, shape)
            .onHover { isHovered = $0 }
    }
}
