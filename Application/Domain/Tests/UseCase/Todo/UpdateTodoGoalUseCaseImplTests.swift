//
//  UpdateTodoGoalUseCaseImplTests.swift
//  DomainTests
//
//  Created by opfic on 8/27/26.
//

import Foundation
import Testing
import Core
@testable import Domain

struct UpdateTodoGoalUseCaseImplTests {
    @Test("목표 연결은 목표를 확인한 뒤 Todo를 저장한다")
    func 목표_연결은_목표를_확인한_뒤_Todo를_저장한다() async throws {
        let todoRepository = TodoRepositorySpy(todo: makeTodo())
        let goalRepository = DevelopmentGoalRepositorySpy(goal: try makeGoal(id: "goal-1"))
        let useCase = UpdateTodoGoalUseCaseImpl(todoRepository, goalRepository)

        try await useCase.execute(todoId: "todo-1", goalId: "goal-1")

        #expect(await goalRepository.fetchedGoalIds() == ["goal-1"])
        #expect(await todoRepository.savedTodos().map(\.goalId) == ["goal-1"])
    }

    @Test("목표 변경은 기존 Todo의 연결 대상을 대체한다")
    func 목표_변경은_기존_Todo의_연결_대상을_대체한다() async throws {
        let todoRepository = TodoRepositorySpy(todo: makeTodo(goalId: "goal-1"))
        let goalRepository = DevelopmentGoalRepositorySpy(goal: try makeGoal(id: "goal-2"))
        let useCase = UpdateTodoGoalUseCaseImpl(todoRepository, goalRepository)

        try await useCase.execute(todoId: "todo-1", goalId: "goal-2")

        #expect(await todoRepository.savedTodos().map(\.goalId) == ["goal-2"])
    }

    @Test("목표 해제는 목표 조회 없이 Todo를 저장한다")
    func 목표_해제는_목표_조회_없이_Todo를_저장한다() async throws {
        let todoRepository = TodoRepositorySpy(todo: makeTodo(goalId: "goal-1"))
        let goalRepository = DevelopmentGoalRepositorySpy(goal: try makeGoal(id: "goal-1"))
        let useCase = UpdateTodoGoalUseCaseImpl(todoRepository, goalRepository)

        try await useCase.execute(todoId: "todo-1", goalId: nil)

        #expect(await goalRepository.fetchedGoalIds().isEmpty)
        #expect(await todoRepository.savedTodos().map(\.goalId) == [nil])
    }

    @Test("존재하지 않는 목표는 Todo 저장 전에 거부한다")
    func 존재하지_않는_목표는_Todo_저장_전에_거부한다() async throws {
        let todoRepository = TodoRepositorySpy(todo: makeTodo())
        let goalRepository = DevelopmentGoalRepositorySpy(error: .notFound)
        let useCase = UpdateTodoGoalUseCaseImpl(todoRepository, goalRepository)

        await #expect(throws: DevelopmentGoalRepositorySpyError.notFound) {
            try await useCase.execute(todoId: "todo-1", goalId: "missing-goal")
        }
        #expect(await todoRepository.savedTodos().isEmpty)
    }
}

private actor TodoRepositorySpy: TodoRepository {
    private let todo: Todo
    private var recordedSavedTodos = [Todo]()

    init(todo: Todo) {
        self.todo = todo
    }

    func fetchTodos(_ query: TodoQuery, cursor: TodoCursor?) async throws -> TodoPage {
        fatalError()
    }

    func fetchTodo(_ todoId: String) async throws -> Todo {
        todo
    }

    func fetchReferences(_ numbers: [Int]) async throws -> [Int: TodoReference] {
        fatalError()
    }

    func upsertTodo(_ todo: Todo) async throws {
        recordedSavedTodos.append(todo)
    }

    func upsertTodo(_ todoDraft: TodoDraft) async throws {
        fatalError()
    }

    func deleteTodo(_ todoId: String) async throws {
        fatalError()
    }

    func undoDeleteTodo(_ todoId: String) async throws {
        fatalError()
    }

    func savedTodos() -> [Todo] {
        recordedSavedTodos
    }
}

private actor DevelopmentGoalRepositorySpy: DevelopmentGoalRepository {
    private let result: Result<DevelopmentGoal, DevelopmentGoalRepositorySpyError>
    private var recordedFetchedGoalIds = [String]()

    init(goal: DevelopmentGoal) {
        self.result = .success(goal)
    }

    init(error: DevelopmentGoalRepositorySpyError) {
        self.result = .failure(error)
    }

    func createGoal(
        id: String,
        title: String,
        description: String
    ) async throws -> DevelopmentGoal {
        try result.get()
    }

    func updateGoal(
        _ goalId: String,
        title: String,
        description: String
    ) async throws -> DevelopmentGoal {
        try result.get()
    }

    func fetchGoal(_ goalId: String) async throws -> DevelopmentGoal {
        recordedFetchedGoalIds.append(goalId)
        return try result.get()
    }

    func fetchGoals(_ query: DevelopmentGoal.Query) async throws -> [DevelopmentGoal] {
        [try result.get()]
    }

    func fetchCompletionSnapshot(for goalId: String) async throws -> DevelopmentGoal.CompletionSnapshot {
        .init(goal: try result.get(), records: [])
    }

    func transitionGoalStatus(
        _ goalId: String,
        to status: DevelopmentGoal.Status,
        completionSnapshot: DevelopmentGoal.CompletionSnapshot?
    ) async throws { }

    func fetchedGoalIds() -> [String] {
        recordedFetchedGoalIds
    }
}

private enum DevelopmentGoalRepositorySpyError: Error, Equatable {
    case notFound
}

private func makeTodo(goalId: String? = nil) -> Todo {
    Todo(
        id: "todo-1",
        isPinned: false,
        isCompleted: false,
        isChecked: false,
        number: 1,
        title: "할 일",
        content: "내용",
        createdAt: .distantPast,
        updatedAt: .distantPast,
        completedAt: nil,
        deletedAt: nil,
        dueDate: nil,
        tags: [],
        category: .system(.feature),
        goalId: goalId
    )
}

private func makeGoal(id: String) throws -> DevelopmentGoal {
    try DevelopmentGoal(
        id: id,
        title: "개발 목표",
        description: "설명",
        status: .inProgress,
        createdAt: .distantPast,
        updatedAt: .distantPast,
        completedAt: nil
    )
}
