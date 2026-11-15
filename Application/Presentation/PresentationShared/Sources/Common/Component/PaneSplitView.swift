//
//  PaneSplitView.swift
//  PresentationShared
//
//  Created by opfic on 11/13/26.
//

import SwiftUI

// 사이드바가 있는 창에서 목록 칸 오른쪽에 상세 칸을 나란히 두는 화면
public struct PaneSplitView<Primary: View, Detail: View>: View {
    @Environment(\.usesDesktopLayout) private var usesDesktopLayout
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
        if usesDesktopLayout {
            GeometryReader { proxy in
                // 경계선은 사이드바 경계선부터 창 오른쪽 끝까지 이동
                HStack(spacing: 0) {
                    primary
                        .resizablePane(
                            minimumWidth: 0,
                            idealWidth: 400,
                            maximumWidth: proxy.size.width
                        )
                        // 세부 정보 사이드바 여는 버튼은 오른쪽 칸 제목 줄에만 표시
                        .environment(\.showDetailSideBar, nil)
                    // 상세 칸이 기본 폭보다 좁으면 내용을 줄이지 않고 잘라서 표시
                    Color.clear
                        .overlay(alignment: .leading) {
                            detail
                                .frame(minWidth: 400, maxWidth: .infinity)
                                // 사이드바 펴기 버튼은 왼쪽 칸 제목 줄에만 표시
                                .environment(\.expandSideBar, nil)
                        }
                        .clipped()
                        .contentShape(.rect)
                }
            }
            // 잘라 낸 칸 바탕이 닿지 않는 아래쪽 안전 영역을 칸 바탕과 같은 색으로 채움
            .background(Color.background, ignoresSafeAreaEdges: .bottom)
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
            width: nil,
            minimumWidth: minimumWidth,
            idealWidth: idealWidth,
            maximumWidth: maximumWidth,
            onResize: nil
        ))
    }

    // 폭을 바깥 상태에 두어 칸을 다시 만들어도 같은 폭으로 표시하고, 끌기를 마치면 바뀐 폭 전달
    func resizablePane(
        width: CGFloat?,
        minimumWidth: CGFloat,
        idealWidth: CGFloat,
        maximumWidth: CGFloat,
        onResize: @escaping (CGFloat) -> Void
    ) -> some View {
        modifier(ResizablePaneModifier(
            width: width,
            minimumWidth: minimumWidth,
            idealWidth: idealWidth,
            maximumWidth: maximumWidth,
            onResize: onResize
        ))
    }
}

private struct ResizablePaneModifier: ViewModifier {
    @Environment(\.layoutDirection) private var layoutDirection
    @State private var width: CGFloat
    @State private var dragStartWidth: CGFloat?
    // 바깥에서 정한 폭, 없으면 기본 폭
    private let storedWidth: CGFloat?
    private let minimumWidth: CGFloat
    private let idealWidth: CGFloat
    private let maximumWidth: CGFloat
    private let onResize: ((CGFloat) -> Void)?

    init(
        width: CGFloat?,
        minimumWidth: CGFloat,
        idealWidth: CGFloat,
        maximumWidth: CGFloat,
        onResize: ((CGFloat) -> Void)?
    ) {
        self.storedWidth = width
        self.minimumWidth = minimumWidth
        self.idealWidth = idealWidth
        self.maximumWidth = maximumWidth
        self.onResize = onResize
        self._width = State(initialValue: max(width ?? idealWidth, minimumWidth))
    }

    // 창 폭이 바뀌어 최대 폭이 줄어도 범위 안에 두는 실제 칸 폭
    private var paneWidth: CGFloat {
        min(max(width, minimumWidth), maximumWidth)
    }

    func body(content: Content) -> some View {
        content
            .environment(\.paneWidth, paneWidth)
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
                    // 위쪽은 상태 표시줄 영역 구분선까지만 연결
                    .ignoresSafeArea(.container, edges: .bottom)
            }
            // 저장한 폭을 불러오거나 기본 폭으로 되돌리면 칸 폭도 맞춤
            .onChange(of: storedWidth) { _, value in
                width = max(value ?? idealWidth, minimumWidth)
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
                onResize?(width)
            }
    }
}
