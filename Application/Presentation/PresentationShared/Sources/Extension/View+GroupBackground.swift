//
//  View+GroupBackground.swift
//  PresentationShared
//
//  Created by opfic on 11/14/26.
//

import SwiftUI

public extension View {
    func groupBackground<S: InsettableShape>(in shape: S) -> some View {
        modifier(GroupBackgroundModifier(shape: shape))
    }
}

private struct GroupBackgroundModifier<S: InsettableShape>: ViewModifier {
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
    @Environment(\.colorScheme) private var colorScheme
    let shape: S

    func body(content: Content) -> some View {
        if isiOSAppOnMac {
            content
                .background(Color.surface, in: shape)
                .overlay { shape.strokeBorder(Color.border) }
        } else {
            // 다크는 밝은 카드, 라이트는 바탕 없이 구분선만 표시
            content.background(colorScheme == .dark ? Color.surfaceSecondary : .clear, in: shape)
        }
    }
}
