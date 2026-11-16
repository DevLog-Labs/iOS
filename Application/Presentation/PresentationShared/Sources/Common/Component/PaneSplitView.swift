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
    @State private var width = CGFloat.infinity
    // 경계선을 끌어 정한 목록 칸 폭, 없으면 기본 폭
    @State private var primaryWidth: CGFloat?
    // 상세 칸이 편집 화면처럼 화면을 덮는 표시를 띄운 동안
    @State private var isDetailPresenting = false
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
        // 두 칸이 기본 폭으로 함께 들어가지 않는 창은 반씩 나눠 처음부터 상세 칸이 잘리지 않게 함
        let paneWidth = min(400, width / 2)

        HStack(spacing: 0) {
            // 넓은 창과 좁은 창을 오가도 목록 칸을 다시 만들지 않도록 같은 구조로 두고 사이드바 구조에서만 폭 조절
            // 경계선은 사이드바 경계선부터 창 오른쪽 끝까지 이동
            primary
                .resizablePane(
                    width: primaryWidth,
                    minimumWidth: 0,
                    idealWidth: paneWidth,
                    maximumWidth: width,
                    isEnabled: usesDesktopLayout
                ) { width in
                    primaryWidth = width
                }
                // 세부 정보 사이드바 여는 버튼은 오른쪽 칸 제목 줄에만 표시
                .environment(\.showDetailSideBar, nil)
            // 좁은 창으로 바뀌어도 상세 칸이 띄운 편집 화면이 닫히지 않도록 폭 0으로 남겨 두고 닫히면 해제
            if usesDesktopLayout || isDetailPresenting {
                // 상세 칸이 기본 폭보다 좁으면 내용을 줄이지 않고 잘라서 표시
                Color.clear
                    .overlay(alignment: .leading) {
                        detail
                            .frame(minWidth: paneWidth, maxWidth: .infinity)
                            // 사이드바 펴기 버튼은 왼쪽 칸 제목 줄에만 표시
                            .environment(\.expandSideBar, nil)
                            .onPreferenceChange(PaneDetailPresentingPreferenceKey.self) { isPresenting in
                                isDetailPresenting = isPresenting
                            }
                    }
                    .frame(maxWidth: usesDesktopLayout ? .infinity : 0)
                    .clipped()
                    .contentShape(.rect)
            }
        }
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width
        } action: { width in
            self.width = width
        }
        // 잘라 낸 칸 바탕이 닿지 않는 아래쪽 안전 영역을 칸 바탕과 같은 색으로 채움
        .background(usesDesktopLayout ? Color.background : .clear, ignoresSafeAreaEdges: .bottom)
    }
}

public extension View {
    // 사이드바 구조로 바뀌면 좁은 창에서 쌓아 연 상세 화면을 내리는 동작
    // 상세 화면이 편집 화면을 띄운 동안에는 닫힌 뒤 실행
    func closesPushedDetail(_ action: @escaping () -> Void) -> some View {
        modifier(PushedDetailCloser(action: action))
    }
}

private struct PushedDetailCloser: ViewModifier {
    @Environment(\.usesDesktopLayout) private var usesDesktopLayout
    @State private var isDetailPresenting = false
    let action: () -> Void

    func body(content: Content) -> some View {
        content
            .onPreferenceChange(PaneDetailPresentingPreferenceKey.self) { isPresenting in
                isDetailPresenting = isPresenting
                if usesDesktopLayout && !isPresenting {
                    action()
                }
            }
            .onChange(of: usesDesktopLayout) { _, isDesktop in
                if isDesktop && !isDetailPresenting {
                    action()
                }
            }
    }
}

// 상세 칸이 편집 화면처럼 화면을 덮는 표시를 띄웠는지 전달
struct PaneDetailPresentingPreferenceKey: PreferenceKey {
    static let defaultValue = false

    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = value || nextValue()
    }
}

public extension View {
    // 오른쪽 경계선을 끌어 폭을 바꾸는 칸
    // 폭을 바깥 상태에 두어 칸을 다시 만들어도 같은 폭으로 표시하고, 끌기를 마치면 바뀐 폭 전달
    // 꺼 두면 폭을 정하지 않고 칸을 자르지 않음
    func resizablePane(
        width: CGFloat?,
        minimumWidth: CGFloat,
        idealWidth: CGFloat,
        maximumWidth: CGFloat,
        isEnabled: Bool = true,
        onResize: @escaping (CGFloat) -> Void
    ) -> some View {
        modifier(ResizablePaneModifier(
            width: width,
            minimumWidth: minimumWidth,
            idealWidth: idealWidth,
            maximumWidth: maximumWidth,
            isEnabled: isEnabled,
            onResize: onResize
        ))
    }
}

private struct ResizablePaneModifier: ViewModifier {
    @Environment(\.layoutDirection) private var layoutDirection
    // 끌거나 바깥에서 정한 폭, 없으면 기본 폭을 따름
    @State private var width: CGFloat?
    @State private var dragStartWidth: CGFloat?
    // 바깥에서 정한 폭, 없으면 기본 폭
    private let storedWidth: CGFloat?
    private let minimumWidth: CGFloat
    private let idealWidth: CGFloat
    private let maximumWidth: CGFloat
    private let isEnabled: Bool
    private let onResize: (CGFloat) -> Void

    init(
        width: CGFloat?,
        minimumWidth: CGFloat,
        idealWidth: CGFloat,
        maximumWidth: CGFloat,
        isEnabled: Bool,
        onResize: @escaping (CGFloat) -> Void
    ) {
        self.storedWidth = width
        self.minimumWidth = minimumWidth
        self.idealWidth = idealWidth
        self.maximumWidth = maximumWidth
        self.isEnabled = isEnabled
        self.onResize = onResize
        self._width = State(initialValue: width)
    }

    // 창 폭이 바뀌어 최대 폭이 줄어도 범위 안에 두는 실제 칸 폭
    private var paneWidth: CGFloat {
        min(max(width ?? idealWidth, minimumWidth), maximumWidth)
    }

    func body(content: Content) -> some View {
        // 켜고 끌 때 칸 내용을 다시 만들지 않도록 수정자 구성은 그대로 두고 값만 바꿈
        content
            .transformEnvironment(\.paneWidth) { value in
                if isEnabled {
                    value = paneWidth
                }
            }
            // 칸이 기본 폭보다 좁으면 내용을 줄이지 않고 기본 폭 그대로 두고 잘라서 표시
            .frame(width: isEnabled ? max(paneWidth, idealWidth) : nil, alignment: .leading)
            .frame(width: isEnabled ? paneWidth : nil, alignment: .leading)
            // 꺼 두면 안전 영역까지 그린 내용도 자르지 않음
            .mask {
                Rectangle()
                    .ignoresSafeArea(edges: isEnabled ? [] : .all)
            }
            // 잘린 영역 밖 내용이 입력을 받지 않도록 칸 영역으로 제한
            .contentShape(.rect)
            .overlay(alignment: .trailing) {
                if isEnabled {
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
            }
            // 저장한 폭을 불러오거나 기본 폭으로 되돌리면 칸 폭도 맞춤
            .onChange(of: storedWidth) { _, value in
                width = value
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
                onResize(paneWidth)
            }
    }
}
