//
//  PaneTitleBar.swift
//  PresentationShared
//
//  Created by opfic on 11/12/26.
//

import SwiftUI

// Mac 창에서 화면 칸 맨 위에 두는 제목 줄
public struct PaneTitleBar<Title: View, Actions: View>: View {
    private let background: Color
    private let title: Title
    private let actions: Actions

    public init(
        background: Color = .appBackground,
        @ViewBuilder title: () -> Title,
        @ViewBuilder actions: () -> Actions
    ) {
        self.background = background
        self.title = title()
        self.actions = actions()
    }

    public var body: some View {
        ZStack(alignment: .leading) {
            // 버튼이 없는 제목 줄도 사이드바 ← → 줄과 같은 높이 유지
            Image(systemName: "circle")
                .topBarButtonStyle()
                .hidden()

            HStack(spacing: 4) {
                title
                    .font(.headline)
                    .lineLimit(1)
                Spacer(minLength: 8)
                actions
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(background, ignoresSafeAreaEdges: .top)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.border)
                .frame(height: 1)
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
