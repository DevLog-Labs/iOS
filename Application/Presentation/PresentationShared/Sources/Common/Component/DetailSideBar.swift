//
//  DetailSideBar.swift
//  PresentationShared
//
//  Created by opfic on 11/15/26.
//

import SwiftUI

// 세부 정보 사이드바에 속성을 표시할 대상
public enum DetailSideBarTarget: Hashable {
    // 고칠 수 없는 활동 기록 Todo는 읽기 전용
    // 다른 곳에서 바꾼 Todo를 다시 조회하도록 목록이 올리는 revision
    case todo(id: String, isEditable: Bool, revision: Int = 0)
}

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

public extension DetailSideBar where Content == DetailSideBarTargetContent {
    init(
        target: DetailSideBarTarget?,
        windowEvent: TodoEditorWindowEvent?,
        onClose: @escaping () -> Void
    ) {
        self.init(onClose: onClose) {
            DetailSideBarTargetContent(target: target, windowEvent: windowEvent)
        }
    }
}

// 창이 그리는 사이드바의 대상별 내용
public struct DetailSideBarTargetContent: View {
    let target: DetailSideBarTarget?
    let windowEvent: TodoEditorWindowEvent?

    public var body: some View {
        switch target {
        case .todo(let id, let isEditable, _):
            TodoDetailSideBarView(todoId: id, isEditable: isEditable, windowEvent: windowEvent)
                .id(target)
        case nil:
            DetailSideBarPlaceholder()
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
    // 지금 고른 대상을 세부 정보 사이드바에 표시
    func detailSideBarTarget(_ target: DetailSideBarTarget?) -> some View {
        modifier(DetailSideBarTargetModifier(target: target))
    }

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

private struct DetailSideBarTargetModifier: ViewModifier {
    @Environment(\.selectDetailSideBarTarget) private var selectDetailSideBarTarget
    @Environment(\.removeDetailSideBarTarget) private var removeDetailSideBarTarget
    @State private var owner = UUID()
    let target: DetailSideBarTarget?

    func body(content: Content) -> some View {
        content
            .onAppear { selectDetailSideBarTarget?(target, owner) }
            .onChange(of: target) { _, target in
                selectDetailSideBarTarget?(target, owner)
            }
            // 화면을 벗어나면 고른 대상 해제
            .onDisappear { removeDetailSideBarTarget?(owner) }
    }
}

private struct CompositionRightModifier<SideBarContent: View>: ViewModifier {
    @Environment(\.selectDetailSideBarTarget) private var selectDetailSideBarTarget
    @State private var id = UUID()
    // 화면을 벗어나 가려진 동안은 내용을 올리지 않음
    @State private var isAppeared = false
    let isActive: Bool
    let sideBarContent: () -> SideBarContent

    func body(content: Content) -> some View {
        // 세부 정보 사이드바 대상을 고를 수 없는 곳(상세 판, 좁은 창 시트)은 내용을 올리지 않음
        let isShown = isActive && isAppeared && selectDetailSideBarTarget != nil

        content
            .transformPreference(DetailSideBarContentPreferenceKey.self) { value in
                guard isShown, value == nil else { return }
                value = DetailSideBarContent(id: id) { AnyView(sideBarContent()) }
            }
            .onAppear { isAppeared = true }
            .onDisappear { isAppeared = false }
    }
}
