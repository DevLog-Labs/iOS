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
    // 칸 화면이 사이드바 내용을 직접 그리는 대상
    case hosted
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
        case .hosted, nil:
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

    // 창 오른쪽 끝 칸 화면이 세부 정보 사이드바 내용을 직접 그림, 사이드바가 있는 창에서만 표시
    func detailSideBar<Content: View>(
        isActive: Bool = true,
        @ViewBuilder content: () -> Content
    ) -> some View {
        modifier(HostedDetailSideBarModifier(isActive: isActive, sideBarContent: content()))
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

private struct HostedDetailSideBarModifier<SideBarContent: View>: ViewModifier {
    @Environment(\.selectDetailSideBarTarget) private var selectDetailSideBarTarget
    @Environment(\.removeDetailSideBarTarget) private var removeDetailSideBarTarget
    @Environment(\.isDetailSideBarPresented) private var isDetailSideBarPresented
    @Environment(\.setDetailSideBarPresented) private var setDetailSideBarPresented
    @State private var owner = UUID()
    let isActive: Bool
    let sideBarContent: SideBarContent

    func body(content: Content) -> some View {
        HStack(spacing: 0) {
            content
            if isActive && isDetailSideBarPresented && selectDetailSideBarTarget != nil {
                DetailSideBar {
                    setDetailSideBarPresented?(false)
                } content: {
                    sideBarContent
                }
                // 왼쪽 사이드바를 펴는 버튼은 창 오른쪽 사이드바 제목 줄에 두지 않음
                .environment(\.expandSideBar, nil)
            }
        }
        // 창이 그리는 사이드바 대신 이 화면의 사이드바 표시
        .onAppear {
            if isActive { selectDetailSideBarTarget?(.hosted, owner) }
        }
        .onChange(of: isActive) { _, isActive in
            selectDetailSideBarTarget?(isActive ? .hosted : nil, owner)
        }
        .onDisappear { removeDetailSideBarTarget?(owner) }
    }
}
