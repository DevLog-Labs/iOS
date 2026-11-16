//
//  TodoDetailPanel.swift
//  PresentationShared
//
//  Created by opfic on 11/16/26.
//

import SwiftUI
import Combine
import ComposableArchitecture

// Mac 상세 판에 연 보기 전용 Todo
// 위쪽 막대의 버튼으로 판 안 오른쪽 세부 정보 열을 열고 닫음
public struct TodoDetailPanel: View {
    @Environment(\.dismiss) private var dismiss
    @State private var store: StoreOf<TodoDetailPanelFeature>
    private let location: Text
    private let windowEvent: TodoEditorWindowEvent?
    // 목록 | 상세 두 칸을 쓰는 화면만 오른쪽 칸으로 옮기기 표시
    private let onMoveToPane: (() -> Void)?
    private let onDelete: (() -> Void)?

    public init(
        todoId: String,
        location: Text,
        isEditable: Bool,
        windowEvent: TodoEditorWindowEvent? = nil,
        onMoveToPane: (() -> Void)? = nil,
        onDelete: (() -> Void)? = nil
    ) {
        self._store = State(initialValue: Store(
            initialState: TodoDetailPanelFeature.State(todoId: todoId, isEditable: isEditable)
        ) {
            TodoDetailPanelFeature()
        })
        self.location = location
        self.windowEvent = windowEvent
        self.onMoveToPane = onMoveToPane
        self.onDelete = onDelete
    }

    public var body: some View {
        VStack(spacing: 0) {
            DetailPanelBar(
                location: location,
                title: Text(verbatim: store.detail.todo.map { "#\($0.number)" } ?? "")
            ) {
                Button {
                    store.send(.binding(.set(\.isDetailColumnPresented, !store.isDetailColumnPresented)))
                } label: {
                    Image(systemName: "sidebar.right")
                }
                .topBarButtonStyle()
            } menu: {
                menu
            }

            HStack(spacing: 0) {
                TodoDetailView(
                    store: store.scope(state: \.detail, action: \.detail),
                    windowEvent: windowEvent
                )
                if store.isDetailColumnPresented {
                    VStack(spacing: 0) {
                        PaneTitleBar(background: .secondaryBackground) {
                            Text("todo_details", bundle: PresentationResources.bundle)
                        } actions: {
                            EmptyView()
                        }
                        // 저장 결과 전달과 다른 곳에서 고친 값 반영은 판이 맡음
                        TodoDetailSideBarView(
                            store: store.scope(state: \.sideBar, action: \.sideBar),
                            windowEvent: nil
                        )
                    }
                    .frame(width: 280 * AdaptiveSize.boardScale)
                    .background(Color.secondaryBackground)
                    .overlay(alignment: .leading) {
                        Rectangle()
                            .fill(Color.separator)
                            .frame(width: 1)
                    }
                }
            }
        }
        // 세부 정보 열을 닫아 둔 동안 판 메뉴로 저장하다 실패하면 판에서 알림 표시
        .background {
            if !store.isDetailColumnPresented,
               let editorStore = store.scope(state: \.sideBar.editor, action: \.sideBar.editor) {
                Color.clear
                    .prominentAlert(editorStore, state: \.alert, action: \.alert)
            }
        }
        // 세부 정보 열을 닫아 둔 동안에도 판 메뉴로 중요 표시와 완료를 바꾸도록 속성을 불러옴
        .onAppear { store.send(.sideBar(.onAppear)) }
        .onChange(of: store.sideBar.editor?.saveResult) { _, result in
            // 판에서 저장한 Todo를 목록과 판 상세에도 반영
            guard case .updated(let todo)? = result else { return }
            windowEvent?.submitUpdate(value: TodoEditorWindowValue(todo: todo), todo: todo)
        }
        .onReceive(windowSubmits) { submit in
            // 판이 저장해 보낸 Todo는 다시 받지 않음
            guard case .update(let value, let todo) = submit,
                  value.matchesEdit(todoId: store.sideBar.todoId),
                  store.sideBar.editor?.saveResult != .updated(todo) else { return }
            store.send(.sideBar(.setTodo(todo)))
        }
    }

    private var windowSubmits: AnyPublisher<TodoEditorWindowSubmit, Never> {
        windowEvent?.submits ?? Empty().eraseToAnyPublisher()
    }

    @ViewBuilder
    private var menu: some View {
        if let onMoveToPane {
            Button(action: onMoveToPane) {
                Label {
                    Text("detail_panel_move_to_pane", bundle: PresentationResources.bundle)
                } icon: {
                    Image(systemName: "sidebar.left")
                }
            }
            Divider()
        }
        if store.sideBar.isEditable, let editor = store.sideBar.editor {
            Button {
                store.send(.sideBar(.editor(.binding(.set(\.isPinned, !editor.isPinned)))))
            } label: {
                Label {
                    Text(editor.isPinned ? "todo_action_unpin" : "todo_action_pin", bundle: PresentationResources.bundle)
                } icon: {
                    Image(systemName: editor.isPinned ? "star.slash" : "star")
                }
            }
            Button {
                store.send(.sideBar(.editor(.binding(.set(\.isCompleted, !editor.isCompleted)))))
            } label: {
                Label {
                    Text(
                        editor.isCompleted ? "todo_action_uncomplete" : "todo_action_complete",
                        bundle: PresentationResources.bundle
                    )
                } icon: {
                    Image(systemName: editor.isCompleted ? "arrow.uturn.backward" : "checkmark")
                }
            }
            Divider()
        }
        if let onDelete {
            Button(role: .destructive, action: onDelete) {
                Label {
                    Text("common_delete", bundle: PresentationResources.bundle)
                } icon: {
                    Image(systemName: "trash")
                }
            }
            Divider()
        }
        Button {
            dismiss()
        } label: {
            Label {
                Text("common_close", bundle: PresentationResources.bundle)
            } icon: {
                Image(systemName: "xmark")
            }
        }
    }
}
