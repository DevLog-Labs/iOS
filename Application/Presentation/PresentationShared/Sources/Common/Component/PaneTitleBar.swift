//
//  PaneTitleBar.swift
//  PresentationShared
//
//  Created by opfic on 11/12/26.
//

import SwiftUI

// 사이드바가 있는 창에서 화면 칸 맨 위에 두는 제목 줄
public struct PaneTitleBar<Title: View, Actions: View>: View {
    @Environment(\.expandSideBar) private var expandSideBar
    @Environment(\.showDetailSideBar) private var showDetailSideBar
    @State private var windowControlsWidth = CGFloat.zero
    private let background: Color
    private let title: Title
    private let actions: Actions

    public init(
        background: Color = .background,
        @ViewBuilder title: () -> Title,
        @ViewBuilder actions: () -> Actions
    ) {
        self.background = background
        self.title = title()
        self.actions = actions()
    }

    public var body: some View {
        ZStack(alignment: .leading) {
            // 버튼이 없는 제목 줄도 사이드바 맨 위 줄과 같은 높이 유지
            Image(systemName: "circle")
                .topBarButtonStyle()
                .hidden()

            HStack(spacing: 4) {
                if let expandSideBar {
                    Button(action: expandSideBar) {
                        Image(systemName: "sidebar.left")
                    }
                    .topBarButtonStyle()
                }
                title
                    .font(.adaptive(.headline))
                    .lineLimit(1)
                Spacer(minLength: 8)
                actions
                // 열린 세부 정보 사이드바의 닫는 버튼과 같은 자리
                if let showDetailSideBar {
                    Button(action: showDetailSideBar) {
                        Image(systemName: "sidebar.right")
                    }
                    .topBarButtonStyle()
                }
            }
        }
        // 사이드바를 접어 창 왼쪽 위에 놓인 제목 줄은 창 버튼 자리만큼 비움
        .padding(.leading, windowControlsWidth)
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(background, ignoresSafeAreaEdges: .top)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.separator)
                .frame(height: 1)
        }
        .onGeometryChange(for: CGFloat.self) { proxy in
            guard #available(iOS 26.0, *) else { return 0 }
            return proxy.containerCornerInsets.topLeading.width
        } action: { width in
            windowControlsWidth = width
        }
    }
}

public extension PaneTitleBar where Title == Text {
    init(
        _ title: Text,
        @ViewBuilder actions: () -> Actions
    ) {
        self.init(title: { title }, actions: actions)
    }
}

public extension PaneTitleBar where Title == Text, Actions == EmptyView {
    init(_ title: Text) {
        self.init(title) { EmptyView() }
    }
}
