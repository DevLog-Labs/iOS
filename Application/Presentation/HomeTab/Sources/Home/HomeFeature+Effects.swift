//
//  HomeFeature+Effects.swift
//  HomeTab
//
//  Created by opfic on 6/14/26.
//

import Combine
import Core
import Domain
import Foundation
import PresentationShared

extension HomeFeature {
    private enum CancelID: Hashable {
        case delayedTodoEditor
        case delayedDevelopmentGoalCreate
        case delayedTodoCategoryPreferencesUpdate
        case networkConnectivity
    }

    func observeNetworkConnectivityEffect() -> Effect<Action> {
        .publisher { [networkConnectivityUseCase] in
            networkConnectivityUseCase.observe()
                .map { .store(.networkStatusChanged($0)) }
        }
        .cancellable(id: CancelID.networkConnectivity, cancelInFlight: true)
    }

    func fetchTodoCategoryPreferencesEffect() -> Effect<Action> {
        .run { [fetchPreferencesUseCase] send in
            await send(.loading(.begin(target: LoadingTarget.preferences.target, mode: .immediate)))
            do {
                let preferences = try await fetchPreferencesUseCase.execute()
                await send(.store(.setTodoCategory(preferences.map(TodoCategoryItem.init(from:)))))
            } catch {
                await send(.store(.setAlert(isPresented: true)))
            }
            await send(.loading(.end(target: LoadingTarget.preferences.target, mode: .immediate)))
        }
    }

    func fetchDevelopmentGoalsEffect() -> Effect<Action> {
        let goalsUseCase = fetchDevelopmentGoalsUseCase
        let todosUseCase = fetchTodosUseCase

        return .run { [goalsUseCase, recentRecordUseCase, todosUseCase] send in
            await send(.loading(.begin(target: LoadingTarget.developmentGoals.target, mode: .immediate)))
            do {
                let goals = try await goalsUseCase.execute(.init(status: .inProgress))
                if goals.isEmpty {
                    await send(.store(.developmentGoalsLoaded([])))
                } else {
                    async let todos = todosUseCase.execute(
                        TodoQuery(
                            sortTarget: .updatedAt,
                            sortOrder: .latest,
                            pageSize: 100,
                            fetchAllPages: true
                        ),
                        cursor: nil
                    )
                    let goalItems = try await Self.makeDevelopmentGoalItems(
                        goals,
                        recentRecordUseCase: recentRecordUseCase
                    )
                    let todoProgressByGoalID = Self.makeTodoProgressByGoalID((try await todos).items)
                    let items = goalItems.map { item in
                        DevelopmentGoalItem(
                            goal: item.goal,
                            recentRecord: item.recentRecord,
                            todoProgress: todoProgressByGoalID[item.goal.id] ?? .empty
                        )
                    }
                    await send(.store(.developmentGoalsLoaded(items)))
                }
            } catch {
                await send(.store(.developmentGoalsLoadFailed))
            }
            await send(.loading(.end(target: LoadingTarget.developmentGoals.target, mode: .immediate)))
        }
    }

    func trackTodoCreateEffect() -> Effect<Action> {
        .run { [trackAnalyticsEventUseCase] _ in
            trackAnalyticsEventUseCase.execute(.todoCreate)
        }
    }

    // 이름을 입력하는 동안 글자마다 저장하지 않도록 마지막 변경만 저장
    func delayedTodoCategoryPreferencesUpdateEffect(_ items: [TodoCategoryItem]) -> Effect<Action> {
        .run { [clock, updatePreferencesUseCase] send in
            try await clock.sleep(for: .seconds(0.3))
            do {
                try await updatePreferencesUseCase.execute(items.map(\.preference))
            } catch {
                await send(.store(.setAlert(isPresented: true)))
            }
        }
        .cancellable(id: CancelID.delayedTodoCategoryPreferencesUpdate, cancelInFlight: true)
    }

    func delayedTodoEditorEffect() -> Effect<Action> {
        .run { [clock] send in
            // iOS 17에서 시트 dismiss 직후 fullScreenCover를 바로 올리지 않도록 하기 위해서 0.1초 딜레이
            try await clock.sleep(for: .seconds(0.1))
            await send(.store(.setPresentation(.todoEditor, true)))
        }
        .cancellable(id: CancelID.delayedTodoEditor, cancelInFlight: true)
    }

    func delayedDevelopmentGoalCreateEffect() -> Effect<Action> {
        .run { [clock] send in
            // 콘텐츠 선택 시트 dismiss 직후 개발 목표 생성 시트를 바로 올리지 않도록 하기 위해서 0.1초 딜레이
            try await clock.sleep(for: .seconds(0.1))
            await send(.view(.tapCreateDevelopmentGoal))
        }
        .cancellable(id: CancelID.delayedDevelopmentGoalCreate, cancelInFlight: true)
    }

    static func setPresentation(
        _ state: inout State,
        presentation: Presentation,
        isPresented: Bool
    ) {
        switch presentation {
        case .todoEditor:
            // 칸에 그린 작성 화면은 계속 누를 수 있는 사이드바에서 다시 열어도 초안을 바꾸지 않음
            if isPresented && state.fullScreenCover?.todoEditor != nil { break }
            state.fullScreenCover = isPresented ? state.selectedTodoCategory.map(FullScreenCoverState.todoEditor) : nil
            if !isPresented {
                state.selectedTodoCategory = nil
            }
        case .contentPicker:
            state.sheet = isPresented ? .contentPicker : state.showContentPicker ? nil : state.sheet
        }
    }

    static func setAlert(
        _ state: inout State,
        isPresented: Bool
    ) {
        guard isPresented else {
            state.alert = nil
            return
        }

        state.alert = alertState()
    }

    static func discardGoalDraftAlertState(isEditing: Bool) -> AlertState<Action.Alert> {
        AlertState {
            TextState(String(
                localized: isEditing ? "development_goal_edit_discard_title" : "development_goal_create_discard_title",
                bundle: PresentationResources.bundle
            ))
        } actions: {
            ButtonState(role: .destructive, action: .discardGoalDraft) {
                TextState(String(localized: "development_goal_create_discard", bundle: PresentationResources.bundle))
            }
            ButtonState(role: .cancel) {
                TextState(String(localized: "common_cancel", bundle: PresentationResources.bundle))
            }
        } message: {
            TextState(String(localized: "development_goal_create_discard_message", bundle: PresentationResources.bundle))
        }
    }

    static func alertState() -> AlertState<Action.Alert> {
        return AlertState<Action.Alert> {
            TextState(String(localized: "common_error_title", bundle: PresentationResources.bundle))
        } actions: {
            ButtonState(role: .cancel) {
                TextState(String(localized: "common_close", bundle: PresentationResources.bundle))
            }
        } message: {
            TextState(String(localized: "common_error_message", bundle: PresentationResources.bundle))
        }
    }

    static func makeDevelopmentGoalItems(
        _ goals: [DevelopmentGoal],
        recentRecordUseCase useCase: FetchRecentDevelopmentRecordUseCase
    ) async throws -> [DevelopmentGoalItem] {
        var items = [DevelopmentGoalItem]()

        try await withThrowingTaskGroup(of: DevelopmentGoalItem.self) { group in
            for goal in goals {
                group.addTask {
                    let version = try await useCase.execute(goalId: goal.id)
                    return DevelopmentGoalItem(goal: goal, recentRecord: version)
                }
            }

            for try await item in group {
                items.append(item)
            }
        }

        return items.sorted { lhs, rhs in
            if lhs.goal.createdAt == rhs.goal.createdAt {
                return lhs.id < rhs.id
            }
            return lhs.goal.createdAt < rhs.goal.createdAt
        }
    }

    static func makeTodoProgressByGoalID(
        _ todos: [Todo]
    ) -> [String: DevelopmentGoalTodoProgress] {
        var progressByGoalID = [String: DevelopmentGoalTodoProgress]()

        for todo in todos {
            guard let goalID = todo.goalId else { continue }
            let currentProgress = progressByGoalID[goalID] ?? .empty
            progressByGoalID[goalID] = DevelopmentGoalTodoProgress(
                completedCount: currentProgress.completedCount + (todo.isCompleted ? 1 : 0),
                totalCount: currentProgress.totalCount + 1
            )
        }

        return progressByGoalID
    }

}
