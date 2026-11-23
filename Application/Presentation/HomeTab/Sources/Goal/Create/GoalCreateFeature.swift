//
//  GoalCreateFeature.swift
//  Development
//
//  Created by opfic on 9/20/26.
//

import Core
import Domain
import Foundation
import PresentationShared

@Reducer
struct GoalCreateFeature {
    @ObservableState
    struct State: Equatable {
        @Presents var alert: AlertState<Action.Alert>?
        @Presents var todoSelection: GoalCreateTodoSelectionFeature.State?
        var title = ""
        var content = ""
        var selectedTodoIDs = Set<String>()
        var pendingGoal: DevelopmentGoal?
        var result: DevelopmentGoal?
        var isSaving = false

        var isReadyToSave: Bool {
            !isSaving && !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        // 버리기 전에 확인할 입력 내용이 있는지 여부
        var hasDraft: Bool {
            !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || !selectedTodoIDs.isEmpty
        }
    }

    enum Action: BindableAction, Equatable {
        case alert(PresentationAction<Alert>)
        case binding(BindingAction<State>)
        case todoSelection(PresentationAction<GoalCreateTodoSelectionFeature.Action>)
        case view(ViewAction)
        case store(StoreAction)
        case delegate(Delegate)

        enum Alert: Equatable {
            case completeAfterTodoLinkFailure
        }

        enum ViewAction: Equatable {
            case save
            case selectTodos
        }

        enum StoreAction: Equatable {
            case created(DevelopmentGoal)
            case linkedTodos
            case todoLinkFailed
            case failed
        }

        enum Delegate: Equatable {
            case saved(DevelopmentGoal)
        }
    }

    @Dependency(\.developmentCreateGoalUseCase) private var createGoalUseCase
    @Dependency(\.developmentUpdateTodoGoalUseCase) private var updateTodoGoalUseCase

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .alert(.presented(.completeAfterTodoLinkFailure)):
                guard let goal = state.pendingGoal else { break }
                state.alert = nil
                state.pendingGoal = nil
                state.result = goal
                return .send(.delegate(.saved(goal)))
            case .alert, .binding, .delegate:
                break
            case .todoSelection(.dismiss):
                state.todoSelection = nil
            case .todoSelection(.presented(.delegate(.close))):
                state.todoSelection = nil
            case .todoSelection(.presented(.delegate(.selected(let todoIDs)))):
                state.selectedTodoIDs = todoIDs
                state.todoSelection = nil
            case .todoSelection:
                break
            case .view(.save):
                guard state.isReadyToSave else { break }
                state.isSaving = true
                state.pendingGoal = nil
                state.result = nil
                return createGoalEffect(title: state.title, description: state.content)
            case .view(.selectTodos):
                guard !state.isSaving, state.todoSelection == nil else { break }
                state.todoSelection = GoalCreateTodoSelectionFeature.State(
                    selectedTodoIDs: state.selectedTodoIDs
                )
            case .store(.created(let goal)):
                state.pendingGoal = goal
                guard !state.selectedTodoIDs.isEmpty else {
                    state.pendingGoal = nil
                    state.result = goal
                    state.isSaving = false
                    return .send(.delegate(.saved(goal)))
                }
                return linkTodosEffect(goalId: goal.id, todoIDs: state.selectedTodoIDs)
            case .store(.linkedTodos):
                guard let goal = state.pendingGoal else { break }
                state.pendingGoal = nil
                state.result = goal
                state.isSaving = false
                return .send(.delegate(.saved(goal)))
            case .store(.todoLinkFailed):
                state.isSaving = false
                state.alert = Self.todoLinkFailureAlert
            case .store(.failed):
                state.isSaving = false
                state.alert = Self.errorAlert
            }

            return .none
        }
        .ifLet(\.$alert, action: \.alert)
        .ifLet(\.$todoSelection, action: \.todoSelection) {
            GoalCreateTodoSelectionFeature()
        }
    }
}

private extension GoalCreateFeature {
    func createGoalEffect(title: String, description: String) -> Effect<Action> {
        .run { [createGoalUseCase] send in
            do {
                let goal = try await createGoalUseCase.execute(
                    title: title,
                    description: description
                )
                await send(.store(.created(goal)))
            } catch {
                await send(.store(.failed))
            }
        }
    }

    func linkTodosEffect(goalId: String, todoIDs: Set<String>) -> Effect<Action> {
        .run { [updateTodoGoalUseCase] send in
            do {
                for todoID in todoIDs {
                    try await updateTodoGoalUseCase.execute(todoId: todoID, goalId: goalId)
                }
                await send(.store(.linkedTodos))
            } catch {
                await send(.store(.todoLinkFailed))
            }
        }
    }

    static var errorAlert: AlertState<Action.Alert> {
        AlertState {
            TextState(String(localized: "common_error_title", bundle: PresentationResources.bundle))
        } actions: {
            ButtonState(role: .cancel) {
                TextState(String(localized: "common_close", bundle: PresentationResources.bundle))
            }
        } message: {
            TextState(String(
                localized: "development_goal_create_error_message",
                bundle: PresentationResources.bundle
            ))
        }
    }

    static var todoLinkFailureAlert: AlertState<Action.Alert> {
        AlertState {
            TextState(String(localized: "common_error_title", bundle: PresentationResources.bundle))
        } actions: {
            ButtonState(action: .completeAfterTodoLinkFailure) {
                TextState(String(localized: "common_close", bundle: PresentationResources.bundle))
            }
        } message: {
            TextState(String(
                localized: "development_goal_create_todo_link_error_message",
                bundle: PresentationResources.bundle
            ))
        }
    }
}
