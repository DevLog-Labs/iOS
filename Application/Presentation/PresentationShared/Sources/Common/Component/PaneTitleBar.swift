//
//  PaneTitleBar.swift
//  PresentationShared
//
//  Created by opfic on 11/12/26.
//

import SwiftUI

// 사이드바가 있는 창과 Duo 펼침에서 화면 칸 맨 위에 두는 제목 줄
public struct PaneTitleBar<Title: View, Actions: View>: View {
    @Environment(\.expandSideBar) private var expandSideBar
    @Environment(\.showDetailSideBar) private var showDetailSideBar
    @Environment(\.usesDesktopLayout) private var usesDesktopLayout
    @Environment(\.deviceType) private var deviceType
    @State private var windowControlsWidth = CGFloat.zero
    private let background: Color
    private let onBack: (() -> Void)?
    // 덮는 화면을 칸에 그릴 때 닫는 버튼, Duo는 앞쪽 끝 글자 버튼, 그 밖은 뒤쪽 끝 버튼
    private let onClose: (() -> Void)?
    private let title: Title
    private let actions: Actions

    public init(
        background: Color = .background,
        onBack: (() -> Void)? = nil,
        onClose: (() -> Void)? = nil,
        @ViewBuilder title: () -> Title,
        @ViewBuilder actions: () -> Actions
    ) {
        self.background = background
        self.onBack = onBack
        self.onClose = onClose
        self.title = title()
        self.actions = actions()
    }

    public var body: some View {
        ZStack(alignment: .leading) {
            // 버튼이 없는 제목 줄도 사이드바 맨 위 줄과 같은 높이 유지
            Image(systemName: "circle")
                .topBarButtonStyle()
                .hidden()

            if deviceType == .duo {
                // iOS 내비게이션 막대처럼 뒤로 버튼은 앞쪽 끝, 제목은 칸 가운데, 버튼은 뒤쪽 끝에 배치
                HStack(spacing: 6) {
                    HStack(spacing: 6) {
                        backButton
                        if let onClose {
                            Button(action: onClose) {
                                Text("common_close", bundle: PresentationResources.bundle)
                                    .font(.adaptive(.body))
                                    .foregroundStyle(Color.accent)
                            }
                            .buttonStyle(.plain)
                            .padding(.leading, 8)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    // 양옆 묶음보다 먼저 폭을 받아 남는 자리까지 제목을 표시
                    title
                        .font(.adaptive(.headline))
                        .lineLimit(1)
                        .layoutPriority(1)
                    HStack(spacing: 6) {
                        actions
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
            } else {
                HStack(spacing: 4) {
                    if let expandSideBar {
                        Button(action: expandSideBar) {
                            Image(systemName: "sidebar.left")
                        }
                        .topBarButtonStyle()
                    }
                    backButton
                    title
                        .font(.adaptive(.headline))
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    actions
                    if let onClose {
                        Button(action: onClose) {
                            Image(systemName: "xmark")
                        }
                        .topBarButtonStyle()
                    }
                    // 열린 세부 정보 사이드바의 닫는 버튼과 같은 자리
                    if let showDetailSideBar {
                        Button(action: showDetailSideBar) {
                            Image(systemName: "sidebar.right")
                        }
                        .topBarButtonStyle()
                    }
                }
            }
        }
        .environment(\.isInPaneTitleBar, true)
        // 사이드바를 접어 창 왼쪽 위에 놓인 제목 줄은 창 버튼 자리만큼 비움
        .padding(.leading, windowControlsWidth)
        .padding(.leading, deviceType == .duo ? 6 : 16)
        .padding(.trailing, deviceType == .duo ? 8 : 16)
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

    // 사이드바가 있는 창은 사이드바에서 위치를 고르므로 뒤로 버튼 없음
    @ViewBuilder
    private var backButton: some View {
        if let onBack, !usesDesktopLayout {
            NavigationBackButton(action: onBack)
        }
    }
}

public extension PaneTitleBar where Title == Text {
    init(
        _ title: Text,
        onBack: (() -> Void)? = nil,
        onClose: (() -> Void)? = nil,
        @ViewBuilder actions: () -> Actions
    ) {
        self.init(onBack: onBack, onClose: onClose, title: { title }, actions: actions)
    }
}

public extension PaneTitleBar where Title == Text, Actions == EmptyView {
    init(_ title: Text, onBack: (() -> Void)? = nil) {
        self.init(title, onBack: onBack) { EmptyView() }
    }
}
