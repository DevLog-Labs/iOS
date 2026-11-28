//
//  GoalDetailTodoFeatureTests.swift
//  DevelopmentTests
//
//  Created by opfic on 9/15/26.
//

import Testing
import Core
import Domain
import PresentationShared
@testable import HomeTab

@MainActor
struct GoalDetailTodoFeatureTests {
    @Test("Todo 조회는 전체 항목을 최신 수정순으로 불러오고 현재 목표 연결을 분류한다")
    func Todo_조회는_전체_항목을_최신_수정순으로_불러오고_현재_목표_연결을_분류한다() async {
        let linked = makeTodo(id: "linked", number: 1, title: "연결됨", goalId: "goal")
        let unlinked = makeTodo(id: "unlinked", number: 2, title: "연결 안 됨")
        let spy = FetchTodosUseCaseSpy(
            page: TodoPage(items: [linked, unlinked], nextCursor: nil)
        )
        let store = TestStore(
            initialState: GoalDetailFeature.State(goalId: "goal")
        ) {
            GoalDetailFeature()
        } withDependencies: {
            $0.developmentFetchTodosUseCase = spy
        }

        await store.send(.view(.retryTodos)) {
            $0.isTodoLoading = true
        }
        await store.receive(.store(.loadedTodos([linked, unlinked]))) {
            $0.todos = [linked, unlinked]
            $0.linkedTodos = [linked]
            $0.isTodoLoading = false
            $0.hasLoadedTodos = true
        }

        let queries = await spy.queries()
        #expect(queries.count == 1)
        #expect(queries.first?.sortTarget == .updatedAt)
        #expect(queries.first?.sortOrder == .latest)
        #expect(queries.first?.pageSize == 100)
        #expect(queries.first?.fetchAllPages == true)
    }

    @Test("Todo 관리 시트를 표시하고 저장 결과를 상세 상태에 반영한다")
    func Todo_관리_시트를_표시하고_저장_결과를_상세_상태에_반영한다() async throws {
        let goal = try makeDevelopmentGoal()
        let linked = makeTodo(id: "linked", number: 1, title: "기존", goalId: goal.id)
        let unlinked = makeTodo(id: "unlinked", number: 2, title: "신규")
        var state = GoalDetailFeature.State(goalId: goal.id)
        state.goal = goal
        state.todos = [linked, unlinked]
        state.linkedTodos = [linked]
        state.hasLoadedTodos = true
        let store = TestStore(initialState: state) {
            GoalDetailFeature()
        }

        await store.send(.view(.manageTodos)) {
            $0.todoLinkSheet = GoalTodoLinkFeature.State(
                goalId: goal.id,
                todos: [linked, unlinked]
            )
        }

        var newlyUnlinked = linked
        newlyUnlinked.goalId = nil
        var newlyLinked = unlinked
        newlyLinked.goalId = goal.id
        await store.send(
            .todoLinkSheet(.presented(.delegate(.saved([newlyUnlinked, newlyLinked]))))
        ) {
            $0.todos = [newlyUnlinked, newlyLinked]
            $0.linkedTodos = [newlyLinked]
            $0.todoLinkSheet = nil
        }
    }

    @Test("연결된 Todo 선택은 상세 목적지를 표시한다")
    func 연결된_Todo_선택은_상세_목적지를_표시한다() async {
        let todo = makeTodo(id: "linked", number: 1, title: "기존", goalId: "goal")
        var state = GoalDetailFeature.State(goalId: "goal")
        state.linkedTodos = [todo]
        let store = TestStore(initialState: state) {
            GoalDetailFeature()
        }

        await store.send(.view(.selectTodo(todo.id))) {
            $0.todoDetail = TodoDetailFeature.State(todoId: todo.id, showEditButton: false)
        }
    }

    @Test("Todo 조회 실패는 상세 화면과 분리된 재시도 상태를 만든다")
    func Todo_조회_실패는_상세_화면과_분리된_재시도_상태를_만든다() async {
        var state = GoalDetailFeature.State(goalId: "goal")
        state.hasLoaded = true
        let store = TestStore(initialState: state) {
            GoalDetailFeature()
        } withDependencies: {
            $0.developmentFetchTodosUseCase = FetchTodosUseCaseStub(
                result: .failure(RecordTestError.failed)
            )
        }

        await store.send(.view(.retryTodos)) {
            $0.isTodoLoading = true
        }
        await store.receive(.store(.todosFailed)) {
            $0.isTodoLoading = false
            $0.hasTodoLoadFailure = true
        }

        #expect(store.state.hasLoaded)
    }
}
