//
//  GoalCreateFeatureTests.swift
//  DevelopmentTests
//
//  Created by opfic on 9/20/26.
//

import Testing
import Domain
import PresentationShared
@testable import HomeTab

@MainActor
struct GoalCreateFeatureTests {
    @Test("Todo를 선택하지 않으면 목표 생성 뒤 즉시 완료한다")
    func Todo를_선택하지_않으면_목표_생성_뒤_즉시_완료한다() async throws {
        let goal = try makeDevelopmentGoal(title: "버전 이력 완성")
        let spy = CreateDevelopmentGoalUseCaseSpy(result: .success(goal))
        var state = GoalCreateFeature.State()
        state.title = goal.title
        state.content = "# 목표"
        let store = TestStore(initialState: state) {
            GoalCreateFeature()
        } withDependencies: {
            $0.developmentCreateGoalUseCase = spy
        }

        await store.send(.view(.save)) {
            $0.isSaving = true
        }
        await store.receive(.store(.created(goal))) {
            $0.result = goal
            $0.isSaving = false
        }
        await store.receive(.delegate(.saved(goal)))

        #expect(await spy.requests() == [
            .init(title: goal.title, description: "# 목표")
        ])
    }

    @Test("선택한 Todo는 생성된 목표 ID로 연결한다")
    func 선택한_Todo는_생성된_목표_ID로_연결한다() async throws {
        let goal = try makeDevelopmentGoal()
        let createSpy = CreateDevelopmentGoalUseCaseSpy(result: .success(goal))
        let todoSpy = UpdateTodoGoalUseCaseSpy(results: [.success(())])
        var state = GoalCreateFeature.State()
        state.title = goal.title
        state.selectedTodoIDs = ["todo"]
        let store = TestStore(initialState: state) {
            GoalCreateFeature()
        } withDependencies: {
            $0.developmentCreateGoalUseCase = createSpy
            $0.developmentUpdateTodoGoalUseCase = todoSpy
        }

        await store.send(.view(.save)) {
            $0.isSaving = true
        }
        await store.receive(.store(.created(goal))) {
            $0.pendingGoal = goal
        }
        await store.receive(.store(.linkedTodos)) {
            $0.pendingGoal = nil
            $0.result = goal
            $0.isSaving = false
        }
        await store.receive(.delegate(.saved(goal)))

        #expect(await todoSpy.requests() == [
            .init(todoId: "todo", goalId: goal.id)
        ])
    }

    @Test("Todo 연결 실패 뒤에도 생성된 목표를 완료 결과로 전달한다")
    func Todo_연결_실패_뒤에도_생성된_목표를_완료_결과로_전달한다() async throws {
        let goal = try makeDevelopmentGoal()
        let createSpy = CreateDevelopmentGoalUseCaseSpy(result: .success(goal))
        let todoSpy = UpdateTodoGoalUseCaseSpy(results: [.failure(RecordTestError.failed)])
        var state = GoalCreateFeature.State()
        state.title = goal.title
        state.selectedTodoIDs = ["todo"]
        let store = TestStore(initialState: state) {
            GoalCreateFeature()
        } withDependencies: {
            $0.developmentCreateGoalUseCase = createSpy
            $0.developmentUpdateTodoGoalUseCase = todoSpy
        }

        await store.send(.view(.save)) {
            $0.isSaving = true
        }
        await store.receive(.store(.created(goal))) {
            $0.pendingGoal = goal
        }
        await store.receive(.store(.todoLinkFailed)) {
            $0.isSaving = false
            $0.alert = makeTodoLinkFailureAlert()
        }
        await store.send(.alert(.presented(.completeAfterTodoLinkFailure))) {
            $0.alert = nil
            $0.pendingGoal = nil
            $0.result = goal
        }
        await store.receive(.delegate(.saved(goal)))
    }

    @Test("Todo 선택 화면의 결과를 저장 상태에 반영한다")
    func Todo_선택_화면의_결과를_저장_상태에_반영한다() async {
        let store = TestStore(initialState: GoalCreateFeature.State()) {
            GoalCreateFeature()
        }

        await store.send(.view(.selectTodos)) {
            $0.todoSelection = GoalCreateTodoSelectionFeature.State(selectedTodoIDs: [])
        }
        await store.send(.todoSelection(.presented(.delegate(.selected(["todo"])))) ) {
            $0.selectedTodoIDs = ["todo"]
            $0.todoSelection = nil
        }
    }

    private func makeTodoLinkFailureAlert() -> AlertState<GoalCreateFeature.Action.Alert> {
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
