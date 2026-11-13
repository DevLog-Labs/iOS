//
//  TodoListFeature+Effects.swift
//  HomeTab
//
//  Created by opfic on 6/12/26.
//

import ComposableArchitecture
import Core
import Domain
import Foundation
import PresentationShared

extension TodoListFeature {
    func toggleCompletedEffect(_ item: TodoListItem) -> Effect<Action> {
        .concatenate(
            .send(.loading(.begin(target: .default, mode: .delayed))),
            .run { [fetchTodoByIdUseCase, upsertTodoUseCase, trackAnalyticsEventUseCase] send in
                do {
                    var todo = try await fetchTodoByIdUseCase.execute(item.id)
                    let now = Date()
                    todo.isCompleted.toggle()
                    todo.completedAt = todo.isCompleted ? now : nil
                    todo.updatedAt = now
                    try await upsertTodoUseCase.execute(todo)
                    if todo.isCompleted {
                        trackAnalyticsEventUseCase.execute(.todoComplete)
                    }
                    guard let todoListItem = TodoListItem(from: todo) else {
                        await send(.store(.setAlert(true)))
                        await send(.loading(.end(target: .default, mode: .delayed)))
                        return
                    }
                    await send(.store(.didToggleCompleted(todoListItem)))
                    await send(.loading(.end(target: .default, mode: .delayed)))
                } catch {
                    await send(.store(.setAlert(true)))
                    await send(.loading(.end(target: .default, mode: .delayed)))
                }
            }
        )
    }

    func trackTodoCreateEffect() -> Effect<Action> {
        .run { [trackAnalyticsEventUseCase] _ in
            trackAnalyticsEventUseCase.execute(.todoCreate)
        }
    }

    func togglePinnedEffect(_ item: TodoListItem) -> Effect<Action> {
        .concatenate(
            .send(.loading(.begin(target: .default, mode: .delayed))),
            .run { [fetchTodoByIdUseCase, upsertTodoUseCase] send in
                do {
                    var todo = try await fetchTodoByIdUseCase.execute(item.id)
                    todo.isPinned.toggle()
                    todo.updatedAt = Date()
                    try await upsertTodoUseCase.execute(todo)
                    guard let todoListItem = TodoListItem(from: todo) else {
                        await send(.store(.setAlert(true)))
                        await send(.loading(.end(target: .default, mode: .delayed)))
                        return
                    }
                    await send(.store(.didTogglePinned(todoListItem)))
                    await send(.loading(.end(target: .default, mode: .delayed)))
                } catch {
                    await send(.store(.setAlert(true)))
                    await send(.loading(.end(target: .default, mode: .delayed)))
                }
            }
        )
    }

    func swipeTodoEffect(_ todo: TodoListItem, state: inout State) -> Effect<Action> {
        guard state.todos.contains(where: { $0.id == todo.id }) else { return .none }
        state.undoTodoId = todo.id
        // 지운 Todo의 상세 칸은 되돌리기와 관계없이 바로 닫음
        if state.selectedTodoId == todo.id {
            state.selectedTodoId = nil
        }
        Self.setTodoHidden(&state, todoId: todo.id, isHidden: true)
        return deleteEffect(todo)
    }

    func deleteEffect(_ item: TodoListItem) -> Effect<Action> {
        .run { [deleteTodoUseCase] send in
            do {
                try await deleteTodoUseCase.execute(item.id)
            } catch {
                await send(.store(.setTodoHidden(item.id, false)))
                await send(.store(.setAlert(true)))
            }
        }
    }

    func undoDeleteEffect(_ todoId: String) -> Effect<Action> {
        .run { [undoDeleteTodoUseCase] send in
            do {
                try await undoDeleteTodoUseCase.execute(todoId)
            } catch {
                await send(.store(.setTodoHidden(todoId, true)))
                await send(.store(.setAlert(true)))
            }
        }
    }

    static func setAlert(
        _ state: inout State,
        isPresented: Bool
    ) {
        state.alert = isPresented ? Self.alertState() : nil
    }

    static func alertState() -> AlertState<Never> {
        AlertState {
            TextState(String(localized: "common_error_title", bundle: PresentationResources.bundle))
        } actions: {
            ButtonState(role: .cancel) {
                TextState(String(localized: "common_close", bundle: PresentationResources.bundle))
            }
        } message: {
            TextState(String(localized: "common_error_message", bundle: PresentationResources.bundle))
        }
    }

    static func setTodoHidden(
        _ state: inout State,
        todoId: String,
        isHidden: Bool
    ) {
        if let todoIndex = state.todos.firstIndex(where: { $0.id == todoId }) {
            state.todos[todoIndex].isHidden = isHidden
        }
    }
}
