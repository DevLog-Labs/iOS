//
//  TodoDetailSideBarFeature.swift
//  PresentationShared
//
//  Created by opfic on 11/15/26.
//

import ComposableArchitecture
import Domain
import Foundation

// 세부 정보 사이드바와 좁은 창 세부 정보 시트의 Todo 속성, 고친 값은 바로 저장
@Reducer
public struct TodoDetailSideBarFeature {
    @ObservableState
    public struct State: Equatable {
        public var editor: TodoEditorFeature.State?
        // 마지막으로 저장된 Todo
        // 저장에 실패하면 속성 값을 이 Todo로 되돌림
        var todo: Todo?
        var isDueDatePickerPresented = false
        var isFetchFailed = false
        // 좁은 창 세부 정보 시트를 속성 칸 높이만큼 열기 위해 잰 위쪽 줄과 속성 칸 높이
        var sheetBarHeight = CGFloat.zero
        var sheetContentHeight = CGFloat.zero
        public let todoId: String
        let isEditable: Bool

        public init(todoId: String, isEditable: Bool) {
            self.todoId = todoId
            self.isEditable = isEditable
        }
    }

    public enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case onAppear
        case setTodo(Todo)
        case fetchFailed
        case editor(TodoEditorFeature.Action)
    }

    @Dependency(\.fetchTodoByIdUseCase) var fetchTodoUseCase

    public init() { }

    public var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                break
            case .onAppear:
                guard state.editor == nil else { break }
                return fetchTodoEffect(todoId: state.todoId)
            case .setTodo(let todo):
                // 다른 곳에서 고친 Todo를 다시 받아도 불러온 카테고리는 유지
                let categories = state.editor?.categories ?? []
                state.todo = todo
                state.editor = TodoEditorFeature.State(todo: todo)
                state.editor?.categories = categories
                if categories.isEmpty {
                    return .send(.editor(.onAppear))
                }
            case .fetchFailed:
                state.isFetchFailed = true
            case .editor(.binding(\.selectedCategoryID)),
                 .editor(.binding(\.isCompleted)),
                 .editor(.binding(\.isPinned)),
                 .editor(.binding(\.selectedDueDate)),
                 .editor(.binding(\.dueDate)):
                guard state.isEditable else { break }
                return .send(.editor(.upsertTodo))
            case .editor(.updateSucceeded(let todo)):
                state.todo = todo
            case .editor(.saveFailed):
                // 저장에 실패한 값이 남아 다음 저장에 함께 실리지 않도록 마지막으로 저장된 값으로 되돌림
                guard let todo = state.todo else { break }
                state.editor?.isCompleted = todo.isCompleted
                state.editor?.completedAt = todo.completedAt
                state.editor?.isPinned = todo.isPinned
                state.editor?.dueDate = todo.dueDate
                state.editor?.category = TodoCategoryItem(from: todo.category)
            case .editor:
                break
            }

            return .none
        }
        .ifLet(\.editor, action: \.editor) {
            TodoEditorFeature()
        }
    }
}

private extension TodoDetailSideBarFeature {
    func fetchTodoEffect(todoId: String) -> Effect<Action> {
        .run { [fetchTodoUseCase] send in
            do {
                let todo = try await fetchTodoUseCase.execute(todoId)
                await send(.setTodo(todo))
            } catch {
                await send(.fetchFailed)
            }
        }
    }
}
