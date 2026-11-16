//
//  DetailPanel.swift
//  PresentationShared
//
//  Created by opfic on 11/16/26.
//

import SwiftUI

public extension EnvironmentValues {
    // 사이드바까지 창 전체를 덮는 상세 판 안의 화면인지 여부
    var isInDetailPanel: Bool {
        get { self[IsInDetailPanelKey.self] }
        set { self[IsInDetailPanelKey.self] = newValue }
    }

    private struct IsInDetailPanelKey: EnvironmentKey {
        static let defaultValue = false
    }
}

public extension View {
    // Mac에서 항목을 열면 사이드바까지 창 전체를 덮는 상세 판
    // 위치와 크기는 고정하고 위쪽 막대는 내용이 DetailPanelBar로 그림
    func detailPanel<Item: Identifiable, Content: View>(
        item: Binding<Item?>,
        @ViewBuilder content: @escaping (Item) -> Content
    ) -> some View {
        modifier(
            ProminentPresentation(item: item) { item, isShown, dismiss in
                DetailPanelFrame(isShown: isShown, dismiss: dismiss) {
                    content(item)
                }
            }
        )
    }
}

private struct DetailPanelFrame<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    let isShown: Bool
    let dismiss: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        ZStack {
            if isShown {
                Color.dimming
                    .ignoresSafeArea()
                    .contentShape(.rect)
                    .onTapGesture(perform: dismiss)
                    .transition(.opacity)

                content
                    .environment(\.isInDetailPanel, true)
                    // 판 안 제목 줄은 창 사이드바를 펴거나 세부 정보 사이드바를 여는 버튼 없이 표시
                    .environment(\.expandSideBar, nil)
                    .environment(\.showDetailSideBar, nil)
                    .environment(\.selectDetailSideBarTarget, nil)
                    .environment(\.windowControlsInset, 0)
                    .environment(\.showsPaneTitleBar, false)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.background)
                    .clipShape(.rect(cornerRadius: CornerRadius.dialog))
                    .overlay {
                        RoundedRectangle(cornerRadius: CornerRadius.dialog)
                            .strokeBorder(Color.separator)
                    }
                    .shadow(
                        color: Color.black.opacity(colorScheme == .dark ? 0.55 : 0.3),
                        radius: 36 * AdaptiveSize.boardScale,
                        y: 24 * AdaptiveSize.boardScale
                    )
                    // 창 가장자리에서 띄운 판 위치, 디자인 캔버스 값
                    .padding(.horizontal, 48 * AdaptiveSize.boardScale)
                    .padding(.vertical, 28 * AdaptiveSize.boardScale)
                    .transition(.scale(scale: 0.98).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// 상세 판 위쪽 막대, "위치 / 항목" 경로와 버튼, 닫기 버튼 표시
// 막대를 우클릭하면 판 메뉴 표시
public struct DetailPanelBar<Actions: View, Menu: View>: View {
    @Environment(\.dismiss) private var dismiss
    private let location: Text
    private let title: Text
    private let actions: Actions
    private let menu: Menu

    public init(
        location: Text,
        title: Text,
        @ViewBuilder actions: () -> Actions,
        @ViewBuilder menu: () -> Menu
    ) {
        self.location = location
        self.title = title
        self.actions = actions()
        self.menu = menu()
    }

    public var body: some View {
        let bar = PaneTitleBar {
            HStack(spacing: 8) {
                location
                    .fontWeight(.medium)
                    .foregroundStyle(Color.secondaryLabel)
                Text(verbatim: "/")
                    .fontWeight(.regular)
                    .foregroundStyle(Color.secondaryLabel)
                title
            }
        } actions: {
            actions
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
            }
            .topBarButtonStyle()
        }

        if Menu.self == EmptyView.self {
            bar
        } else {
            bar
                .contentShape(.rect)
                .contextMenu { menu }
        }
    }
}

public extension DetailPanelBar where Actions == EmptyView, Menu == EmptyView {
    init(location: Text, title: Text) {
        self.init(location: location, title: title, actions: { EmptyView() }, menu: { EmptyView() })
    }
}
