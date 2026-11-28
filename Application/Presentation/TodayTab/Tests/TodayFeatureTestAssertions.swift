//
//  TodayFeatureTestAssertions.swift
//  TodayTabTests
//
//  Created by opfic on 6/14/26.
//

import Testing
import Core
import Domain
@testable import TodayTab

@MainActor
func waitUntilTodayMainActor(
    timeout: Duration = .seconds(1),
    pollInterval: Duration = .milliseconds(20),
    _ condition: @escaping @MainActor () -> Bool
) async {
    let continuousClock = ContinuousClock()
    let deadline = continuousClock.now + timeout

    while !condition() && continuousClock.now < deadline {
        try? await Task.sleep(for: pollInterval)
    }
}

@MainActor
func verifyTodayFetchData<Adapter: TodayStateDriving>(
    adapter: Adapter,
    fetchUseCaseSpy: TodayFetchTodosUseCaseSpy
) async throws {
    await adapter.fetchData()

    await waitUntilTodayMainActor {
        adapter.todos.count == 5 && adapter.isTodayDataLoaded
    }

    let queries = await fetchUseCaseSpy.calledQueries()
    let incompleteDueDateQuery = queries.first {
        $0.completionFilter == .incomplete && $0.dueDateFilter == .withDueDate
    }
    let incompleteWithoutDueDateQuery = queries.first {
        $0.completionFilter == .incomplete && $0.dueDateFilter == .withoutDueDate
    }
    let completedTodayQuery = queries.first { $0.completionFilter == .completed }
    let cursors = await fetchUseCaseSpy.calledCursors()

    #expect(queries.count == 3)
    #expect(incompleteDueDateQuery?.sortTarget == .dueDate)
    #expect(incompleteDueDateQuery?.sortOrder == .oldest)
    #expect(incompleteWithoutDueDateQuery?.sortTarget == .updatedAt)
    #expect(incompleteWithoutDueDateQuery?.sortOrder == .latest)
    #expect(completedTodayQuery?.dueDateFilter == .withDueDate)
    #expect(completedTodayQuery?.sortDateFrom == adapter.todayInterval.start)
    #expect(completedTodayQuery?.sortDateTo == adapter.todayInterval.end)
    #expect(completedTodayQuery?.sortTarget == .dueDate)
    #expect(completedTodayQuery?.sortOrder == .oldest)
    #expect(queries.map(\.pageSize).allSatisfy { $0 == 20 })
    #expect(queries.map(\.fetchAllPages).allSatisfy { $0 })
    #expect(cursors.count == 3)
    #expect(cursors.allSatisfy { $0 == nil })
    #expect(adapter.todos.map(\.id) == ["focused", "overdue", "due-soon", "later", "unscheduled"])
    #expect(adapter.summaryCounts == [
        .remaining: 5,
        .important: 1
    ])
    #expect(adapter.displayedSections == [
        TodayDisplayedSection(category: .overdue, itemIds: ["overdue"]),
        TodayDisplayedSection(category: .upcoming, itemIds: ["focused", "due-soon"]),
        TodayDisplayedSection(category: .later, itemIds: ["later"]),
        TodayDisplayedSection(category: .unscheduled, itemIds: ["unscheduled"])
    ])
}

@MainActor
func verifyTodayTodoScope<Adapter: TodayStateDriving>(
    adapter: Adapter,
    fetchUseCaseSpy: TodayFetchTodosUseCaseSpy
) async throws {
    try await verifyTodayFetchData(adapter: adapter, fetchUseCaseSpy: fetchUseCaseSpy)

    await adapter.setTodoScope(.important)

    #expect(adapter.selectedTodoScope == .important)
    #expect(adapter.displayedSections == [
        TodayDisplayedSection(category: .upcoming, itemIds: ["focused"])
    ])

    await adapter.setTodoScope(.remaining)

    #expect(adapter.selectedTodoScope == .remaining)
    #expect(adapter.displayedSections.count == 4)
}

@MainActor
func verifyTodayCompleteTodo<Adapter: TodayStateDriving>(
    adapter: Adapter,
    fetchUseCaseSpy: TodayFetchTodosUseCaseSpy,
    fetchTodoByIdUseCaseSpy: TodayFetchTodoByIdUseCaseSpy,
    upsertTodoUseCaseSpy: TodayUpsertTodoUseCaseSpy,
    trackAnalyticsEventUseCaseSpy: TodayTrackAnalyticsEventUseCaseSpy
) async throws {
    try await verifyTodayFetchData(adapter: adapter, fetchUseCaseSpy: fetchUseCaseSpy)

    let item = try #require(adapter.todos.first { $0.id == "due-soon" })
    await adapter.completeTodo(item)

    await waitUntilTodayMainActor {
        !adapter.todos.map(\.id).contains("due-soon")
    }

    #expect(fetchTodoByIdUseCaseSpy.todoIds == ["due-soon"])
    #expect(upsertTodoUseCaseSpy.todos.last?.id == "due-soon")
    #expect(upsertTodoUseCaseSpy.todos.last?.isCompleted == true)
    #expect(trackAnalyticsEventUseCaseSpy.hasTrackedTodoComplete)
    #expect(adapter.summaryCounts == [
        .remaining: 4,
        .important: 1
    ])
    #expect(adapter.displayedSections == [
        TodayDisplayedSection(category: .overdue, itemIds: ["overdue"]),
        TodayDisplayedSection(category: .upcoming, itemIds: ["focused"]),
        TodayDisplayedSection(category: .later, itemIds: ["later"]),
        TodayDisplayedSection(category: .unscheduled, itemIds: ["unscheduled"])
    ])
}

@MainActor
func verifyTodayFetchFailureShowsAlert<Adapter: TodayStateDriving>(
    adapter: Adapter
) async {
    await adapter.fetchData()

    await waitUntilTodayMainActor {
        adapter.showAlert
    }

    #expect(adapter.showAlert)
}
