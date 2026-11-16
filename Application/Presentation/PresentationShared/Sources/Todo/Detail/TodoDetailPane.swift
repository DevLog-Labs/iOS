//
//  TodoDetailPane.swift
//  PresentationShared
//
//  Created by opfic on 11/13/26.
//

import SwiftUI
import ComposableArchitecture

// 사이드바가 있는 창에서 목록 오른쪽 칸의 Todo 상세, 선택 전에는 선택 안내
public struct TodoDetailPane: View {
    private let todoId: String?
    private let showEditButton: Bool
    private let windowEvent: TodoEditorWindowEvent?

    public init(
        todoId: String?,
        showEditButton: Bool,
        windowEvent: TodoEditorWindowEvent? = nil
    ) {
        self.todoId = todoId
        self.showEditButton = showEditButton
        self.windowEvent = windowEvent
    }

    public var body: some View {
        if let todoId {
            TodoDetailView(
                store: Store(
                    initialState: TodoDetailFeature.State(todoId: todoId, showEditButton: showEditButton)
                ) {
                    TodoDetailFeature()
                },
                windowEvent: windowEvent
            )
            .environment(\.showsPaneTitleBar, true)
            .id(todoId)
        } else {
            PanePlaceholder()
        }
    }
}

// 상세 칸에서 고른 항목이 없을 때 표시하는 안내
public struct PanePlaceholder: View {
    public init() {}

    public var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.adaptive(.largeTitle))
                .foregroundStyle(Color.tertiaryLabel)
            Text("pane_select_detail", bundle: PresentationResources.bundle)
                .font(.adaptive(.callout))
                .foregroundStyle(Color.secondaryLabel)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // 목록 칸 제목 줄과 구분선 높이 맞춤
        .safeAreaInset(edge: .top, spacing: 0) {
            PaneTitleBar(Text(verbatim: ""))
        }
        .background(Color.background)
    }
}
