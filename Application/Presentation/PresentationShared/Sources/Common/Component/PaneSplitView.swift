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
            GeometryReader { proxy in
                // 경계선은 사이드바 경계선부터 창 오른쪽 끝까지 이동
                HStack(spacing: 0) {
                    primary
                        .resizablePane(
                            minimumWidth: 0,
                            idealWidth: 400,
                            maximumWidth: proxy.size.width
                        )
                    // 상세 칸이 기본 폭보다 좁으면 내용을 줄이지 않고 잘라서 표시
                    Color.clear
                        .overlay(alignment: .leading) {
                            detail
                                .frame(minWidth: 400, maxWidth: .infinity)
                        }
                        .clipped()
                        .contentShape(.rect)
                }
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
    private let idealWidth: CGFloat
    private let maximumWidth: CGFloat

    init(
        minimumWidth: CGFloat,
        idealWidth: CGFloat,
        maximumWidth: CGFloat
    ) {
        self.minimumWidth = minimumWidth
        self.idealWidth = idealWidth
        self.maximumWidth = maximumWidth
        self._width = State(initialValue: max(idealWidth, minimumWidth))
    }

    // 창 폭이 바뀌어 최대 폭이 줄어도 범위 안에 두는 실제 칸 폭
    private var paneWidth: CGFloat {
        min(max(width, minimumWidth), maximumWidth)
    }

    func body(content: Content) -> some View {
        content
            // 칸이 기본 폭보다 좁으면 내용을 줄이지 않고 기본 폭 그대로 두고 잘라서 표시
            .frame(width: max(paneWidth, idealWidth), alignment: .leading)
            .frame(width: paneWidth, alignment: .leading)
            .clipped()
            // 잘린 영역 밖 내용이 입력을 받지 않도록 칸 영역으로 제한
            .contentShape(.rect)
            .overlay(alignment: .trailing) {
                Color.clear
                    .frame(width: 16)
                    .contentShape(.rect)
                    .gesture(resizeGesture)
                    .overlay(alignment: .trailing) {
                        Rectangle()
                            .fill(Color.separator)
                            .frame(width: 2)
                    }
                    .ignoresSafeArea(.container, edges: .vertical)
            }
    }

    private var resizeGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .onChanged { value in
                if dragStartWidth == nil {
                    dragStartWidth = paneWidth
                }
                let startWidth = dragStartWidth ?? paneWidth
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
