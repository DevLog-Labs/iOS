//
//  TodayFeatureTests.swift
//  TodayTabTests
//
//  Created by opfic on 6/14/26.
//

import Testing
import Foundation
import Core
import Domain
@testable import TodayTab

@MainActor
struct TodayFeatureTests {
    @Test("TodayFeature groupedSectionItems는 중요 여부와 무관하게 날짜로 분류한다")
    func todayFeature_groupedSectionItems는_중요_여부와_무관하게_날짜로_분류한다() throws {
        let now = try #require(makeFixedTodayNow())
        let items = makeFixedTodayTodoItems(now: now)
        let interval = TodayFeature.dayInterval(containing: now)

        let sections = TodayFeature.groupedSectionItems(from: items, interval: interval)

        #expect(sections.overdue.map(\.id) == ["overdue"])
        #expect(sections.today.isEmpty)
        #expect(sections.upcoming.map(\.id) == ["focused", "due-soon"])
        #expect(sections.later.map(\.id) == ["later"])
        #expect(sections.unscheduled.map(\.id) == ["unscheduled"])
    }

    @Test("TodayFeature filteredTodos는 보기와 카테고리 조건을 함께 적용한다")
    func todayFeature_filteredTodos는_보기와_카테고리_조건을_함께_적용한다() throws {
        let now = try #require(makeFixedTodayNow())
        let todos = [
            makeTodayTodo(
                id: "match",
                isPinned: true,
                dueDate: now,
                category: .system(.feature)
            ),
            makeTodayTodo(
                id: "other-scope",
                dueDate: now,
                category: .system(.feature)
            ),
            makeTodayTodo(
                id: "other-category",
                isPinned: true,
                dueDate: now,
                category: .system(.doc)
            )
        ].compactMap(TodayTodoItem.init(from:))

        let filtered = TodayFeature.filteredTodos(
            todos,
            scope: .important,
            categoryID: SystemTodoCategory.feature.rawValue
        )

        #expect(filtered.map(\.id) == ["match"])
    }

    @Test("TodayFeature는 선택한 Todo로 Inspector 편집 상태를 구성하고 닫는다")
    func todayFeature는_선택한_Todo로_Inspector_편집_상태를_구성하고_닫는다() async throws {
        let todo = makeTodayTodo(id: "inspector", title: "수정 전")
        let item = try #require(TodayTodoItem(from: todo))
        let adapter = TodayStoreTestAdapter()
        await adapter.receiveUpdatedTodo(item)

        await adapter.showTodoInspector(item)

        #expect(adapter.isTodoInspectorPresented)
        #expect(adapter.todoEditorTitle == "수정 전")

        await adapter.setTodoInspectorPresented(false)

        #expect(!adapter.isTodoInspectorPresented)
        #expect(adapter.todoEditorTitle == nil)
    }

    @Test("TodayFeature는 Inspector에서 수정한 Todo를 목록에 반영하고 닫는다")
    func todayFeature는_Inspector에서_수정한_Todo를_목록에_반영하고_닫는다() async throws {
        var todo = makeTodayTodo(id: "inspector", title: "수정 전")
        let item = try #require(TodayTodoItem(from: todo))
        let adapter = TodayStoreTestAdapter()
        await adapter.receiveUpdatedTodo(item)
        await adapter.showTodoInspector(item)
        todo.title = "수정 후"

        await adapter.updateTodoFromInspector(todo)

        #expect(adapter.todos.first?.title == "수정 후")
        #expect(!adapter.isTodoInspectorPresented)
        #expect(adapter.todoEditorTitle == nil)
    }

    @Test("넓은 창으로 바뀌면 세부 정보에서 고친 값을 저장하고 닫은 뒤 같은 Todo를 고른다")
    func 넓은_창으로_바뀌면_세부_정보에서_고친_값을_저장하고_닫은_뒤_같은_Todo를_고른다() async throws {
        let item = try #require(TodayTodoItem(from: makeTodayTodo(id: "inspector", title: "수정 전")))
        let upsertSpy = TodayUpsertTodoUseCaseSpy()
        let adapter = TodayStoreTestAdapter(upsertUseCase: upsertSpy)
        await adapter.receiveUpdatedTodo(item)
        await adapter.showTodoInspector(item)
        await adapter.setTodoEditorTitle("수정 후")

        await adapter.moveTodoInspectorToSideBar()

        #expect(upsertSpy.todos.map(\.title) == ["수정 후"])
        #expect(adapter.todos.first?.title == "수정 후")
        #expect(!adapter.isTodoInspectorPresented)
        #expect(adapter.selectedTodoId == item.id)
        #expect(!adapter.showAlert)
    }

    @Test("넓은 창으로 바뀔 때 세부 정보 저장에 실패하면 알림을 띄우고 닫은 뒤 같은 Todo를 고른다")
    func 넓은_창으로_바뀔_때_세부_정보_저장에_실패하면_알림을_띄우고_닫은_뒤_같은_Todo를_고른다() async throws {
        let item = try #require(TodayTodoItem(from: makeTodayTodo(id: "inspector", title: "수정 전")))
        let upsertSpy = TodayUpsertTodoUseCaseSpy()
        upsertSpy.error = TodayTestError.failure
        let adapter = TodayStoreTestAdapter(upsertUseCase: upsertSpy)
        await adapter.receiveUpdatedTodo(item)
        await adapter.showTodoInspector(item)
        await adapter.setTodoEditorTitle("수정 후")

        await adapter.moveTodoInspectorToSideBar()

        #expect(adapter.todos.first?.title == "수정 전")
        #expect(!adapter.isTodoInspectorPresented)
        #expect(adapter.selectedTodoId == item.id)
        #expect(adapter.showAlert)
    }

    @Test("넓은 창으로 바뀔 때 세부 정보에서 고친 값이 없으면 저장하지 않고 닫은 뒤 같은 Todo를 고른다")
    func 넓은_창으로_바뀔_때_세부_정보에서_고친_값이_없으면_저장하지_않고_닫은_뒤_같은_Todo를_고른다() async throws {
        let item = try #require(TodayTodoItem(from: makeTodayTodo(id: "inspector", title: "수정 전")))
        let upsertSpy = TodayUpsertTodoUseCaseSpy()
        let adapter = TodayStoreTestAdapter(upsertUseCase: upsertSpy)
        await adapter.receiveUpdatedTodo(item)
        await adapter.showTodoInspector(item)

        await adapter.moveTodoInspectorToSideBar()

        #expect(upsertSpy.todos.isEmpty)
        #expect(!adapter.isTodoInspectorPresented)
        #expect(adapter.selectedTodoId == item.id)
    }

    @Test("TodayFeature fetchData는 요약과 섹션 상태를 갱신한다")
    func todayFeature_fetchData는_요약과_섹션_상태를_갱신한다() async throws {
        let todos = makeTodaySectionTodos()
        let fetchSpy = TodayFetchTodosUseCaseSpy(
            pagesByFilter: [
                .withDueDate: .init(items: todos.filter { $0.dueDate != nil }, nextCursor: nil),
                .withoutDueDate: .init(items: todos.filter { $0.dueDate == nil }, nextCursor: nil)
            ]
        )
        let adapter = TodayStoreTestAdapter(fetchUseCase: fetchSpy)

        try await verifyTodayFetchData(adapter: adapter, fetchUseCaseSpy: fetchSpy)
    }

    @Test("TodayFeature fetchData는 오늘 완료 Todo를 별도 조회해 달성 상태를 만든다")
    func todayFeature_fetchData는_오늘_완료_Todo를_별도_조회해_달성_상태를_만든다() async throws {
        let now = try #require(makeFixedTodayNow())
        let incompleteToday = makeTodayTodo(id: "incomplete-today", dueDate: now)
        let completedToday = makeTodayTodo(id: "completed-today", isCompleted: true, dueDate: now)
        let fetchSpy = TodayFetchTodosUseCaseSpy(
            pagesByFilter: [
                .withDueDate: TodoPage(items: [incompleteToday], nextCursor: nil),
                .withoutDueDate: TodoPage(items: [], nextCursor: nil)
            ],
            completedTodayPage: TodoPage(items: [completedToday], nextCursor: nil)
        )
        let adapter = TodayStoreTestAdapter(fetchUseCase: fetchSpy, now: now)

        await adapter.fetchData()

        #expect(adapter.completedTodayTodos.map(\.id) == ["completed-today"])
        #expect(adapter.todayTodos.map(\.id) == ["incomplete-today", "completed-today"])
        #expect(adapter.todayAchievement?.completedCount == 1)
        #expect(adapter.todayAchievement?.totalCount == 2)
        #expect(adapter.summaryCounts[.remaining] == 1)
    }

    @Test("TodayFeature checkCurrentDate는 날짜가 바뀔 때만 오늘 완료 Todo를 다시 조회한다")
    func todayFeature_checkCurrentDate는_날짜가_바뀔_때만_오늘_완료_Todo를_다시_조회한다() async throws {
        let now = try #require(makeFixedTodayNow())
        let calendar = Calendar.current
        let nextDay = try #require(calendar.date(byAdding: .day, value: 1, to: now))
        let fetchSpy = TodayFetchTodosUseCaseSpy()
        let adapter = TodayStoreTestAdapter(fetchUseCase: fetchSpy, now: now)
        await adapter.fetchData()

        await adapter.checkCurrentDate(now)
        let sameDayQueries = await fetchSpy.calledQueries()
        let sameDayQueryCount = sameDayQueries.count
        #expect(sameDayQueryCount == 3)

        fetchSpy.completedTodayPage = TodoPage(
            items: [makeTodayTodo(id: "next-day", isCompleted: true, dueDate: nextDay)],
            nextCursor: nil
        )
        await adapter.checkCurrentDate(nextDay)

        let queries = await fetchSpy.calledQueries()
        let lastQuery = try #require(queries.last)
        #expect(queries.count == 4)
        #expect(lastQuery.completionFilter == .completed)
        #expect(lastQuery.sortDateFrom == adapter.todayInterval.start)
        #expect(lastQuery.sortDateTo == adapter.todayInterval.end)
        #expect(adapter.completedTodayTodos.map(\.id) == ["next-day"])
        #expect(adapter.todayAchievement?.completedCount == 1)
        #expect(adapter.todayAchievement?.totalCount == 1)
    }

    @Test("TodayFeature는 이전 날짜의 완료 조회 결과를 반영하지 않는다")
    func todayFeature는_이전_날짜의_완료_조회_결과를_반영하지_않는다() async throws {
        let now = try #require(makeFixedTodayNow())
        let calendar = Calendar.current
        let previousDay = try #require(calendar.date(byAdding: .day, value: -1, to: now))
        let adapter = TodayStoreTestAdapter(now: now)
        let previousInterval = TodayFeature.dayInterval(containing: previousDay)
        let staleItem = try #require(TodayTodoItem(from: makeTodayTodo(
            id: "stale",
            isCompleted: true,
            dueDate: previousDay
        )))

        await adapter.receiveCompletedTodayTodos([staleItem], interval: previousInterval)

        #expect(adapter.completedTodayTodos.isEmpty)
        #expect(!adapter.isTodayDataLoaded)
        #expect(adapter.todayAchievement == nil)
    }

    @Test("TodayFeature는 최초 조회 중 날짜가 바뀌면 새 날짜 전체 데이터를 다시 조회한다")
    func todayFeature는_최초_조회_중_날짜가_바뀌면_새_날짜_전체_데이터를_다시_조회한다() async throws {
        let now = try #require(makeFixedTodayNow())
        let calendar = Calendar.current
        let nextDay = try #require(calendar.date(byAdding: .day, value: 1, to: now))
        let previousInterval = TodayFeature.dayInterval(containing: now)
        let incompleteTodo = makeTodayTodo(id: "next-incomplete", dueDate: nextDay)
        let completedTodo = makeTodayTodo(
            id: "next-completed",
            isCompleted: true,
            dueDate: nextDay
        )
        let fetchSpy = TodayFetchTodosUseCaseSpy(
            pagesByFilter: [
                .withDueDate: TodoPage(items: [incompleteTodo], nextCursor: nil),
                .withoutDueDate: TodoPage(items: [], nextCursor: nil)
            ],
            completedTodayPage: TodoPage(items: [completedTodo], nextCursor: nil)
        )
        let adapter = TodayStoreTestAdapter(fetchUseCase: fetchSpy, now: now)

        await adapter.checkCurrentDate(nextDay)

        let queries = await fetchSpy.calledQueries()
        let queryCount = queries.count
        #expect(queryCount == 3)
        #expect(adapter.isTodayDataLoaded)
        #expect(adapter.todayTodos.map(\.id) == ["next-incomplete", "next-completed"])
        #expect(adapter.todayAchievement?.completedCount == 1)
        #expect(adapter.todayAchievement?.totalCount == 2)

        let staleItem = try #require(TodayTodoItem(from: makeTodayTodo(
            id: "stale",
            dueDate: nextDay
        )))

        await adapter.receiveTodos(
            incomplete: [staleItem],
            completedToday: [],
            interval: previousInterval
        )

        #expect(adapter.isTodayDataLoaded)
        #expect(adapter.todayTodos.map(\.id) == ["next-incomplete", "next-completed"])
        #expect(adapter.todayAchievement?.completedCount == 1)
        #expect(adapter.todayAchievement?.totalCount == 2)
    }

    @Test("TodayFeature completeTodo는 오늘 Todo를 완료 목록으로 한 번만 이동한다")
    func todayFeature_completeTodo는_오늘_Todo를_완료_목록으로_한_번만_이동한다() async throws {
        let now = try #require(makeFixedTodayNow())
        let todo = makeTodayTodo(id: "today", dueDate: now)
        let fetchSpy = TodayFetchTodosUseCaseSpy(
            pagesByFilter: [
                .withDueDate: TodoPage(items: [todo], nextCursor: nil),
                .withoutDueDate: TodoPage(items: [], nextCursor: nil)
            ]
        )
        let fetchByIdSpy = TodayFetchTodoByIdUseCaseSpy(todos: [todo])
        let adapter = TodayStoreTestAdapter(
            fetchUseCase: fetchSpy,
            fetchTodoByIdUseCase: fetchByIdSpy,
            now: now
        )
        await adapter.fetchData()
        let item = try #require(adapter.todos.first)

        await adapter.completeTodo(item)

        let completedItem = try #require(adapter.completedTodayTodos.first)
        await adapter.receiveUpdatedTodo(completedItem)
        await adapter.receiveUpdatedTodo(completedItem)

        #expect(adapter.todos.isEmpty)
        #expect(adapter.completedTodayTodos.map(\.id) == ["today"])
        #expect(adapter.todayAchievement?.completedCount == 1)
        #expect(adapter.todayAchievement?.totalCount == 1)
    }

    @Test("TodayFeature completeTodo는 저장된 최신 마감일로 오늘 완료 목록을 갱신한다")
    func todayFeature_completeTodo는_저장된_최신_마감일로_오늘_완료_목록을_갱신한다() async throws {
        let now = try #require(makeFixedTodayNow())
        let tomorrow = try #require(Calendar.current.date(byAdding: .day, value: 1, to: now))
        let original = makeTodayTodo(id: "today", dueDate: now)
        let latest = makeTodayTodo(id: "today", dueDate: tomorrow)
        let fetchSpy = TodayFetchTodosUseCaseSpy(
            pagesByFilter: [
                .withDueDate: TodoPage(items: [original], nextCursor: nil),
                .withoutDueDate: TodoPage(items: [], nextCursor: nil)
            ]
        )
        let adapter = TodayStoreTestAdapter(
            fetchUseCase: fetchSpy,
            fetchTodoByIdUseCase: TodayFetchTodoByIdUseCaseSpy(todos: [latest]),
            now: now
        )
        await adapter.fetchData()
        let item = try #require(adapter.todos.first)

        await adapter.completeTodo(item)

        #expect(adapter.todos.isEmpty)
        #expect(adapter.completedTodayTodos.isEmpty)
        #expect(adapter.todayAchievement?.completedCount == 0)
        #expect(adapter.todayAchievement?.totalCount == 0)
    }

    @Test("TodayFeature completeTodo 실패는 오늘 달성 상태를 유지한다")
    func todayFeature_completeTodo_실패는_오늘_달성_상태를_유지한다() async throws {
        let now = try #require(makeFixedTodayNow())
        let todo = makeTodayTodo(id: "today", dueDate: now)
        let fetchSpy = TodayFetchTodosUseCaseSpy(
            pagesByFilter: [
                .withDueDate: TodoPage(items: [todo], nextCursor: nil),
                .withoutDueDate: TodoPage(items: [], nextCursor: nil)
            ]
        )
        let upsertSpy = TodayUpsertTodoUseCaseSpy()
        upsertSpy.error = TodayTestError.failure
        let adapter = TodayStoreTestAdapter(
            fetchUseCase: fetchSpy,
            fetchTodoByIdUseCase: TodayFetchTodoByIdUseCaseSpy(todos: [todo]),
            upsertUseCase: upsertSpy,
            now: now
        )
        await adapter.fetchData()
        let item = try #require(adapter.todos.first)

        await adapter.completeTodo(item)

        #expect(adapter.todos.map(\.id) == ["today"])
        #expect(adapter.completedTodayTodos.isEmpty)
        #expect(adapter.todayAchievement?.completedCount == 0)
        #expect(adapter.todayAchievement?.totalCount == 1)
        #expect(adapter.showAlert)
    }

    @Test("TodayFeature 달성 상태는 목록 필터의 영향을 받지 않는다")
    func todayFeature_달성_상태는_목록_필터의_영향을_받지_않는다() async throws {
        let now = try #require(makeFixedTodayNow())
        let checkedTodo = makeTodayTodo(id: "checked", isChecked: true, dueDate: now)
        let completedTodo = makeTodayTodo(id: "completed", isCompleted: true, dueDate: now)
        let fetchSpy = TodayFetchTodosUseCaseSpy(
            pagesByFilter: [
                .withDueDate: TodoPage(items: [checkedTodo], nextCursor: nil),
                .withoutDueDate: TodoPage(items: [], nextCursor: nil)
            ],
            completedTodayPage: TodoPage(items: [completedTodo], nextCursor: nil)
        )
        let adapter = TodayStoreTestAdapter(fetchUseCase: fetchSpy, now: now)
        await adapter.fetchData()

        await adapter.setTodoScope(.important)
        await adapter.setCategory(SystemTodoCategory.doc.rawValue)

        #expect(adapter.todayAchievement?.completedCount == 1)
        #expect(adapter.todayAchievement?.totalCount == 2)
        #expect(adapter.todayAchievement?.status == .inProgress)
    }

}

private func makeFixedTodayNow() -> Date? {
    Calendar.current.date(
        from: DateComponents(
            year: 2026,
            month: 6,
            day: 14,
            hour: 12
        )
    )
}

private func makeFixedTodayTodoItems(now: Date) -> [TodayTodoItem] {
    let calendar = Calendar.current

    func dueDate(_ dayOffset: Int) -> Date {
        calendar.date(byAdding: .day, value: dayOffset, to: now) ?? now
    }

    return [
        TodayTodoItem(from: makeTodayTodo(id: "focused", isPinned: true, dueDate: dueDate(1)))!,
        TodayTodoItem(from: makeTodayTodo(id: "overdue", dueDate: dueDate(-1)))!,
        TodayTodoItem(from: makeTodayTodo(id: "due-soon", dueDate: dueDate(2)))!,
        TodayTodoItem(from: makeTodayTodo(id: "later", dueDate: dueDate(10)))!,
        TodayTodoItem(from: makeTodayTodo(id: "unscheduled", dueDate: nil))!
    ]
}
