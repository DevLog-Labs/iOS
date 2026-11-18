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
        var editor: TodoEditorFeature.State?
        var isDueDatePickerPresented = false
        var isFetchFailed = false
        let todoId: String
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
                 .editor(.binding(\.dueDate)),
                 .editor(.addTag),
                 .editor(.removeTag):
                guard state.isEditable else { break }
                return .send(.editor(.upsertTodo))
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
