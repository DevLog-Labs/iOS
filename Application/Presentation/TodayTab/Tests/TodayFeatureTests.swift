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

    @Test("TodayFeature는 선택한 Todo로 세부 정보 시트를 열고 닫는다")
    func todayFeature는_선택한_Todo로_세부_정보_시트를_열고_닫는다() async throws {
        let todo = makeTodayTodo(id: "inspector", title: "수정 전")
        let item = try #require(TodayTodoItem(from: todo))
        let adapter = TodayStoreTestAdapter()
        await adapter.receiveUpdatedTodo(item)

        await adapter.showTodoInspector(item)

        #expect(adapter.isTodoInspectorPresented)
        #expect(adapter.todoInfoTitle == "수정 전")

        await adapter.setTodoInspectorPresented(false)

        #expect(!adapter.isTodoInspectorPresented)
    }

    @Test("TodayFeature는 세부 정보에서 저장한 Todo를 시트를 연 채 목록에 반영한다")
    func todayFeature는_세부_정보에서_저장한_Todo를_시트를_연_채_목록에_반영한다() async throws {
        var todo = makeTodayTodo(id: "inspector", title: "수정 전")
        let item = try #require(TodayTodoItem(from: todo))
        let adapter = TodayStoreTestAdapter()
        await adapter.receiveUpdatedTodo(item)
        await adapter.showTodoInspector(item)
        todo.isPinned = true

        await adapter.receiveTodoInfoSaved(todo)

        #expect(adapter.todos.first?.isPinned == true)
        #expect(adapter.isTodoInspectorPresented)
    }

    @Test("시트를 닫은 뒤 실패한 세부 정보 저장은 오늘 화면에서 알린다")
    func 시트를_닫은_뒤_실패한_세부_정보_저장은_오늘_화면에서_알린다() async throws {
        let item = try #require(TodayTodoItem(from: makeTodayTodo(id: "inspector", title: "수정 전")))
        let adapter = TodayStoreTestAdapter()
        await adapter.receiveUpdatedTodo(item)
        await adapter.showTodoInspector(item)

        await adapter.receiveTodoInfoSaveFailed()

        #expect(!adapter.showAlert)

        await adapter.setTodoInspectorPresented(false)
        await adapter.receiveTodoInfoSaveFailed()

        #expect(adapter.showAlert)
    }

    @Test("상세가 저장해 보낸 Todo는 목록 행만 바꾸고 상세는 다시 조회하지 않는다")
    func 상세가_저장해_보낸_Todo는_목록_행만_바꾸고_상세는_다시_조회하지_않는다() async throws {
        var todo = makeTodayTodo(id: "detail", title: "수정 전")
        let fetchByIdSpy = TodayFetchTodoByIdUseCaseSpy(todos: [todo])
        let adapter = TodayStoreTestAdapter(fetchTodoByIdUseCase: fetchByIdSpy)
        await adapter.receiveUpdatedTodo(try #require(TodayTodoItem(from: todo)))
        await adapter.openTodo("detail")

        todo.title = "상세에서 수정"
        await adapter.receiveDetailTodo(try #require(TodayTodoItem(from: todo)))

        #expect(adapter.todos.first?.title == "상세에서 수정")
        #expect(fetchByIdSpy.todoIds.isEmpty)

        todo.title = "목록에서 수정"
        await adapter.receiveUpdatedTodo(try #require(TodayTodoItem(from: todo)))

        await waitUntilTodayMainActor {
            !fetchByIdSpy.todoIds.isEmpty
        }

        #expect(adapter.todos.first?.title == "목록에서 수정")
        #expect(fetchByIdSpy.todoIds == ["detail"])
    }

    @Test("오른쪽 칸을 연 동안만 세부 정보로 고른 Todo가 칸의 Todo도 바꾼다")
    func 오른쪽_칸을_연_동안만_세부_정보로_고른_Todo가_칸의_Todo도_바꾼다() async {
        let adapter = TodayStoreTestAdapter()

        await adapter.openTodo("panel")
        await adapter.inspectTodo("inspected")

        #expect(adapter.detailTodoId == "panel")
        #expect(adapter.selectedTodoId == "inspected")

        await adapter.moveDetailToPane()
        await adapter.inspectTodo("next")

        #expect(adapter.showsDetailInPane)
        #expect(adapter.detailTodoId == "next")
        #expect(adapter.selectedTodoId == "next")

        await adapter.dismissDetail()

        #expect(adapter.detailTodoId == nil)
        #expect(!adapter.showsDetailInPane)
        #expect(adapter.selectedTodoId == "next")
    }

    @Test("넓은 창으로 바뀌면 세부 정보 시트를 저장 없이 닫고 같은 Todo를 고른다")
    func 넓은_창으로_바뀌면_세부_정보_시트를_저장_없이_닫고_같은_Todo를_고른다() async throws {
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

    @Test("넓은 창으로 바뀔 때 세부 정보를 저장하는 중이면 저장이 끝날 때까지 고른 Todo를 비워 둔다")
    func 넓은_창으로_바뀔_때_세부_정보를_저장하는_중이면_저장이_끝날_때까지_고른_Todo를_비워_둔다() async throws {
        let item = try #require(TodayTodoItem(from: makeTodayTodo(id: "inspector", title: "수정 전")))
        let adapter = TodayStoreTestAdapter(upsertUseCase: TodayPendingUpsertTodoUseCase())
        await adapter.receiveUpdatedTodo(item)
        await adapter.selectTodo(item.id)
        await adapter.showTodoInspector(item)
        await adapter.setTodoInfoPinned(true)

        await adapter.moveTodoInspectorToSideBar()

        #expect(adapter.selectedTodoId == nil)
        #expect(!adapter.isTodoInspectorPresented)
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
