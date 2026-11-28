//
//  DetailSideBar.swift
//  PresentationShared
//
//  Created by opfic on 11/15/26.
//

import SwiftUI

// 사이드바가 있는 창 오른쪽에 두는 세부 정보 사이드바
public struct DetailSideBar<Content: View>: View {
    private let onClose: () -> Void
    private let content: Content

    public init(
        onClose: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.onClose = onClose
        self.content = content()
    }

    public var body: some View {
        VStack(spacing: 0) {
            // 닫힌 사이드바를 여는 버튼과 같은 자리에 닫는 버튼 표시
            PaneTitleBar(background: .secondaryBackground) {
                Text("todo_details", bundle: PresentationResources.bundle)
            } actions: {
                Button(action: onClose) {
                    Image(systemName: "sidebar.right")
                }
                .topBarButtonStyle()
            }
            content
                .frame(maxHeight: .infinity, alignment: .top)
        }
        .frame(width: 280 * AdaptiveSize.boardScale)
        .background {
            Color.secondaryBackground
                .ignoresSafeArea(.container, edges: .vertical)
        }
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Color.separator)
                .frame(width: 1)
                .ignoresSafeArea(.container, edges: .vertical)
        }
    }
}

// 고른 대상이 없을 때의 안내
public struct DetailSideBarPlaceholder: View {
    public init() { }

    public var body: some View {
        VStack(spacing: 10 * AdaptiveSize.boardScale) {
            Image(systemName: "doc.text")
                .font(.adaptive(.largeTitle))
            Text("detail_sidebar_empty", bundle: PresentationResources.bundle)
                .font(.adaptive(.body))
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(Color.secondaryLabel)
        .padding(.horizontal, 14 * AdaptiveSize.boardScale)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

public extension View {
    // 이 화면의 세부 정보 사이드바 내용, 사이드바가 있는 창에서 SplitShell 오른쪽에 표시
    // 화면은 내용만 올리고 사이드바는 CompositionView가 그림
    func compositionRight<Content: View>(
        isActive: Bool = true,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        modifier(CompositionRightModifier(isActive: isActive, sideBarContent: content))
    }
}

// 화면이 올린 세부 정보 사이드바 내용
// 같은 화면이 올린 동안은 같은 값으로 보고, 내용이 읽는 상태가 바뀌면 이 View만 다시 그림
public struct DetailSideBarContent: View, Equatable {
    let id: UUID
    let content: () -> AnyView

    public var body: some View {
        content()
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }
}

// 탭 화면이 올린 세부 정보 사이드바 내용, 나중에 나타난 화면의 내용을 표시
public struct DetailSideBarContentPreferenceKey: PreferenceKey {
    public static var defaultValue: DetailSideBarContent? { nil }

    public static func reduce(value: inout DetailSideBarContent?, nextValue: () -> DetailSideBarContent?) {
        value = nextValue() ?? value
    }
}

private struct CompositionRightModifier<SideBarContent: View>: ViewModifier {
    @State private var id = UUID()
    // 화면을 벗어나 가려진 동안은 내용을 올리지 않음
    @State private var isAppeared = false
    let isActive: Bool
    let sideBarContent: () -> SideBarContent

    func body(content: Content) -> some View {
        // 상세 판과 시트는 따로 덮는 화면이라 그 안에서 올린 내용은 창까지 오지 않음
        let isShown = isActive && isAppeared

        content
            .transformPreference(DetailSideBarContentPreferenceKey.self) { value in
                guard isShown, value == nil else { return }
                value = DetailSideBarContent(id: id) { AnyView(sideBarContent()) }
            }
            .onAppear { isAppeared = true }
            .onDisappear { isAppeared = false }
    }
}
