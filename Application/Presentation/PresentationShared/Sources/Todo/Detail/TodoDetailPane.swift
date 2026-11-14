//
//  TodoDetailPane.swift
//  PresentationShared
//
//  Created by opfic on 11/13/26.
//

import SwiftUI
import ComposableArchitecture

// Mac 목록 오른쪽 칸의 Todo 상세, 선택 전에는 선택 안내
public struct TodoDetailPane: View {
    private let todoId: String?
    private let showEditButton: Bool
    private let placeholder: Text
    private let windowEvent: TodoEditorWindowEvent?

    public init(
        todoId: String?,
        showEditButton: Bool,
        placeholder: Text,
        windowEvent: TodoEditorWindowEvent? = nil
    ) {
        self.todoId = todoId
        self.showEditButton = showEditButton
        self.placeholder = placeholder
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
            VStack(spacing: 12) {
                Image(systemName: "doc.text")
                    .font(.largeTitle)
                    .foregroundStyle(Color.tertiaryLabel)
                placeholder
                    .font(.callout)
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
}
