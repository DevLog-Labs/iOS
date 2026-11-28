//
//  TodoDetailPanel.swift
//  PresentationShared
//
//  Created by opfic on 11/16/26.
//

import SwiftUI
import ComposableArchitecture

// 사이드바가 있는 창의 상세 판에 연 보기 전용 Todo
// 위쪽 막대의 버튼으로 판 안 오른쪽 세부 정보 열을 열고 닫음
// 판 메뉴의 중요 표시와 완료도 세부 정보 열과 같은 속성 상태로 바로 저장
public struct TodoDetailPanel: View {
    @Environment(\.dismiss) private var dismiss
    @State private var store: StoreOf<TodoDetailFeature>
    private let location: Text
    private let windowEvent: TodoEditorWindowEvent?
    // 목록 | 상세 두 칸을 쓰는 화면만 오른쪽 칸으로 옮기기 표시
    private let onMoveToPane: (() -> Void)?
    private let onDelete: (() -> Void)?

    // 상세 상태는 연 화면의 Feature가 갖고, 창 폭이 바뀌면 같은 상태를 다른 화면이 이어 그림
    public init(
        store: StoreOf<TodoDetailFeature>,
        location: Text,
        windowEvent: TodoEditorWindowEvent? = nil,
        onMoveToPane: (() -> Void)? = nil,
        onDelete: (() -> Void)? = nil
    ) {
        self._store = State(initialValue: store)
        self.location = location
        self.windowEvent = windowEvent
        self.onMoveToPane = onMoveToPane
        self.onDelete = onDelete
    }

    // 프로필 탭이 상세 상태를 Feature로 옮기기 전까지 Todo 식별자로 상세 상태를 만들어 여는 init
    public init(
        todoId: String,
        location: Text,
        isEditable: Bool,
        windowEvent: TodoEditorWindowEvent? = nil,
        onMoveToPane: (() -> Void)? = nil,
        onDelete: (() -> Void)? = nil
    ) {
        self.init(
            store: Store(initialState: TodoDetailFeature.State(todoId: todoId, showEditButton: isEditable)) {
                TodoDetailFeature()
            },
            location: location,
            windowEvent: windowEvent,
            onMoveToPane: onMoveToPane,
            onDelete: onDelete
        )
    }

    public var body: some View {
        VStack(spacing: 0) {
            DetailPanelBar(
                location: location,
                title: Text(verbatim: store.todo.map { "#\($0.number)" } ?? "")
            ) {
                Button {
                    store.send(.setDetailColumnPresented(!store.isDetailColumnPresented))
                } label: {
                    Image(systemName: "sidebar.right")
                }
                .topBarButtonStyle()
            } menu: {
                menu
            }

            HStack(spacing: 0) {
                TodoDetailView(store: store, windowEvent: windowEvent)
                if store.isDetailColumnPresented {
                    VStack(spacing: 0) {
                        PaneTitleBar(background: .secondaryBackground) {
                            Text("todo_details", bundle: PresentationResources.bundle)
                        } actions: {
                            EmptyView()
                        }
                        // 저장 결과 전달과 다른 곳에서 고친 값 반영은 판 안 상세가 맡음
                        TodoDetailSideBarView(store: store)
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
        // 세부 정보 열을 닫아 둔 동안에도 판 메뉴로 중요 표시와 완료를 바꾸도록 속성을 불러옴
        .onAppear { store.send(.info(.onAppear)) }
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
        if store.info.isEditable, let editor = store.info.editor {
            Button {
                store.send(.info(.editor(.binding(.set(\.isPinned, !editor.isPinned)))))
            } label: {
                Label {
                    Text(editor.isPinned ? "todo_action_unpin" : "todo_action_pin", bundle: PresentationResources.bundle)
                } icon: {
                    Image(systemName: editor.isPinned ? "star.slash" : "star")
                }
            }
            Button {
                store.send(.info(.editor(.binding(.set(\.isCompleted, !editor.isCompleted)))))
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
