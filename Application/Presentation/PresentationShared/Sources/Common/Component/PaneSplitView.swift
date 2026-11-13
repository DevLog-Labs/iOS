//
//  PaneSplitView.swift
//  PresentationShared
//
//  Created by opfic on 11/13/26.
//

import SwiftUI

// Mac 창에서 목록 칸 오른쪽에 상세 칸을 나란히 두는 화면
public struct PaneSplitView<Primary: View, Detail: View>: View {
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
    private let primary: Primary
    private let detail: Detail

    public init(
        @ViewBuilder primary: () -> Primary,
        @ViewBuilder detail: () -> Detail
    ) {
        self.primary = primary()
        self.detail = detail()
    }

    public var body: some View {
        if isiOSAppOnMac {
            HStack(spacing: 0) {
                primary
                    .resizablePane(
                        minimumWidth: 320,
                        idealWidth: 400,
                        maximumWidth: 520
                    )
                detail
                    .frame(maxWidth: .infinity)
            }
        } else {
            primary
        }
    }
}

public extension View {
    // 오른쪽 경계선을 끌어 폭을 바꾸는 칸
    func resizablePane(
        minimumWidth: CGFloat,
        idealWidth: CGFloat,
        maximumWidth: CGFloat
    ) -> some View {
        modifier(ResizablePaneModifier(
            minimumWidth: minimumWidth,
            idealWidth: idealWidth,
            maximumWidth: maximumWidth
        ))
    }
}

private struct ResizablePaneModifier: ViewModifier {
    @Environment(\.layoutDirection) private var layoutDirection
    @State private var width: CGFloat
    @State private var dragStartWidth: CGFloat?
    private let minimumWidth: CGFloat
    private let maximumWidth: CGFloat

    init(
        minimumWidth: CGFloat,
        idealWidth: CGFloat,
        maximumWidth: CGFloat
    ) {
        self.minimumWidth = minimumWidth
        self.maximumWidth = maximumWidth
        self._width = State(initialValue: min(max(idealWidth, minimumWidth), maximumWidth))
    }

    func body(content: Content) -> some View {
        content
            .frame(width: width)
            .overlay(alignment: .trailing) {
                Color.clear
                    .frame(width: 16)
                    .contentShape(.rect)
                    .gesture(resizeGesture)
                    .overlay(alignment: .trailing) {
                        Rectangle()
                            .fill(Color.border)
                            .frame(width: 1)
                    }
                    .ignoresSafeArea(.container, edges: .vertical)
            }
    }

    private var resizeGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .onChanged { value in
                if dragStartWidth == nil {
                    dragStartWidth = width
                }
                let startWidth = dragStartWidth ?? width
                let translation = layoutDirection == .leftToRight
                    ? value.translation.width
                    : -value.translation.width
                width = min(max(startWidth + translation, minimumWidth), maximumWidth)
            }
            .onEnded { _ in
                dragStartWidth = nil
            }
    }
}
