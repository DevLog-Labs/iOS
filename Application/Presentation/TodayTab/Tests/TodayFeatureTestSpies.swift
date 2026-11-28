//
//  TodayFeatureTestSpies.swift
//  TodayTabTests
//
//  Created by opfic on 6/14/26.
//

import Foundation
import Core
import Domain
@testable import TodayTab

final class TodayFetchTodosUseCaseSpy: FetchTodosUseCase {
    var pagesByFilter: [TodoQuery.DueDateFilter: TodoPage]
    var completedTodayPage: TodoPage
    var error: Error?
    private let recorder = FetchTodosUseCaseCallRecorder()

    init(
        pagesByFilter: [TodoQuery.DueDateFilter: TodoPage] = [
            .withDueDate: TodoPage(items: [], nextCursor: nil),
            .withoutDueDate: TodoPage(items: [], nextCursor: nil)
        ],
        completedTodayPage: TodoPage = TodoPage(items: [], nextCursor: nil)
    ) {
        self.pagesByFilter = pagesByFilter
        self.completedTodayPage = completedTodayPage
    }

    func execute(_ query: TodoQuery, cursor: TodoCursor?) async throws -> TodoPage {
        await recorder.append(query: query, cursor: cursor)

        if let error {
            throw error
        }

        if query.completionFilter == .completed {
            return completedTodayPage
        }

        return pagesByFilter[query.dueDateFilter] ?? TodoPage(items: [], nextCursor: nil)
    }

    func calledQueries() async -> [TodoQuery] {
        await recorder.queries()
    }

    func calledCursors() async -> [TodoCursor?] {
        await recorder.cursors()
    }
}

private actor FetchTodosUseCaseCallRecorder {
    var recordedQueries = [TodoQuery]()
    var recordedCursors = [TodoCursor?]()

    func append(query: TodoQuery, cursor: TodoCursor?) {
        recordedQueries.append(query)
        recordedCursors.append(cursor)
    }

    func queries() -> [TodoQuery] {
        recordedQueries
    }

    func cursors() -> [TodoCursor?] {
        recordedCursors
    }
}

final class TodayFetchReferenceItemsUseCaseStub: FetchReferenceItemsUseCase {
    func execute(_ numbers: [Int]) async throws -> [Int: TodoReference] {
        [:]
    }
}

final class TodayFetchTodoByIdUseCaseSpy: FetchTodoByIdUseCase {
    var todos: [Todo]
    var error: Error?
    private(set) var todoIds = [String]()

    init(todos: [Todo] = []) {
        self.todos = todos
    }

    func execute(_ todoId: String) async throws -> Todo {
        todoIds.append(todoId)

        if let error {
            throw error
        }

        return todos.first { $0.id == todoId } ?? makeTodayTodo(id: todoId)
    }
}

// 저장이 끝나지 않은 동안의 상태를 보기 위해 저장을 끝내지 않는 대역
final class TodayPendingUpsertTodoUseCase: UpsertTodoUseCase {
    func execute(_ todo: Todo) async throws {
        try await Task.sleep(for: .seconds(3600))
    }

    func execute(_ draft: TodoDraft) async throws {
        try await Task.sleep(for: .seconds(3600))
    }
}

final class TodayUpsertTodoUseCaseSpy: UpsertTodoUseCase {
    var error: Error?
    private(set) var todos = [Todo]()
    private(set) var todoDrafts = [TodoDraft]()

    func execute(_ todo: Todo) async throws {
        todos.append(todo)

        if let error {
            throw error
        }
    }

    func execute(_ todoDraft: TodoDraft) async throws {
        todoDrafts.append(todoDraft)

        if let error {
            throw error
        }
    }
}

final class TodayFetchCategoryPreferencesUseCaseSpy: FetchTodoCategoryPreferencesUseCase {
    var preferences: [TodoCategoryPreference]
    var error: Error?
    private(set) var callCount = 0

    init(preferences: [TodoCategoryPreference] = []) {
        self.preferences = preferences
    }

    func execute() async throws -> [TodoCategoryPreference] {
        callCount += 1
        if let error { throw error }
        return preferences
    }
}

final class TodayTrackAnalyticsEventUseCaseSpy: TrackAnalyticsEventUseCase {
    private(set) var events = [AnalyticsEvent]()

    var hasTrackedTodoComplete: Bool {
        events.contains {
            guard case .todoComplete = $0 else { return false }
            return true
        }
    }

    func execute(_ event: AnalyticsEvent) {
        events.append(event)
    }
}

func makeTodayTodo(
    id: String = "todo-1",
    isPinned: Bool = false,
    isCompleted: Bool = false,
    isChecked: Bool = false,
    number: Int = 1,
    title: String = "Todo",
    content: String = "content",
    dueDate: Date? = nil,
    category: TodoCategory = .system(.feature)
) -> Todo {
    let now = Date(timeIntervalSince1970: 0)
    return Todo(
        id: id,
        isPinned: isPinned,
        isCompleted: isCompleted,
        isChecked: isChecked,
        number: number,
        title: title,
        content: content,
        createdAt: now,
        updatedAt: now,
        completedAt: isCompleted ? now : nil,
        deletedAt: nil,
        dueDate: dueDate,
        tags: [],
        category: category
    )
}

func makeTodaySectionTodos() -> [Todo] {
    let calendar = Calendar.current
    let startOfToday = calendar.startOfDay(for: Date())

    func dueDate(_ dayOffset: Int) -> Date {
        calendar.date(byAdding: .day, value: dayOffset, to: startOfToday) ?? startOfToday
    }

    return [
        makeTodayTodo(id: "focused", isPinned: true, number: 1, dueDate: dueDate(1)),
        makeTodayTodo(id: "overdue", number: 2, dueDate: dueDate(-1)),
        makeTodayTodo(id: "due-soon", number: 3, dueDate: dueDate(2)),
        makeTodayTodo(id: "later", number: 4, dueDate: dueDate(10)),
        makeTodayTodo(id: "unscheduled", number: 5, dueDate: nil)
    ]
}
