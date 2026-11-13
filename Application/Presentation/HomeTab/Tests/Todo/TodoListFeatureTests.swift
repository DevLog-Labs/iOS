//
//  TodoListFeatureTests.swift
//  HomeTabTests
//
//  Created by opfic on 6/12/26.
//

import Testing
import Foundation
import Core
import Domain
import PresentationShared
@testable import HomeTab

@MainActor
struct TodoListFeatureTests {
    @Test("onAppear는 첫 페이지를 조회하고 목록과 hasMore 상태를 갱신한다")
    func onAppear는_첫_페이지를_조회하고_목록과_hasMore_상태를_갱신한다() async {
        let todos = (0..<20).map { makeTodoListTodo(id: "todo-\($0)", number: $0) }
        let cursor = makeTodoListCursor(documentID: "cursor-1")
        let fetchSpy = TodoListFetchTodosUseCaseSpy(pages: [
            TodoPage(items: todos, nextCursor: cursor)
        ])
        let adapter = TodoListStoreTestAdapter(fetchUseCase: fetchSpy)

        await adapter.onAppear()

        await waitUntil {
            adapter.todos.count == 20
        }

        #expect(fetchSpy.queries.map(\.categoryId) == ["feature"])
        #expect(fetchSpy.cursors.map { $0?.documentID } == [nil])
        #expect(adapter.todos == todos.compactMap(TodoListItem.init(from:)))
        #expect(adapter.hasMore)
    }

    @Test("loadNextPage는 다음 커서로 조회한 Todo를 기존 목록 뒤에 추가한다")
    func loadNextPage는_다음_커서로_조회한_Todo를_기존_목록_뒤에_추가한다() async {
        let firstTodos = (0..<20).map { makeTodoListTodo(id: "todo-\($0)", number: $0) }
        let nextTodo = makeTodoListTodo(id: "todo-next", number: 20)
        let cursor = makeTodoListCursor(documentID: "cursor-1")
        let fetchSpy = TodoListFetchTodosUseCaseSpy(pages: [
            TodoPage(items: firstTodos, nextCursor: cursor),
            TodoPage(items: [nextTodo], nextCursor: nil)
        ])
        let adapter = TodoListStoreTestAdapter(fetchUseCase: fetchSpy)

        await adapter.onAppear()

        await waitUntil {
            adapter.todos.count == 20
        }

        await adapter.loadNextPage()

        await waitUntil {
            adapter.todos.count == 21
        }

        #expect(fetchSpy.cursors.map { $0?.documentID } == [nil, "cursor-1"])
        #expect(adapter.todos.last == TodoListItem(from: nextTodo))
        #expect(!adapter.hasMore)
    }

    @Test("새 목록 조회는 이전 요청을 취소하고 마지막 응답만 반영한다")
    func 새_목록_조회는_이전_요청을_취소하고_마지막_응답만_반영한다() async {
        let firstTodo = makeTodoListTodo(id: "todo-first", number: 1)
        let secondTodo = makeTodoListTodo(id: "todo-second", number: 2)
        let fetchSpy = DelayedFirstFetchTodosUseCaseSpy(pages: [
            TodoPage(items: [firstTodo], nextCursor: nil),
            TodoPage(items: [secondTodo], nextCursor: nil)
        ])
        let clock = TestClock()
        let adapter = TodoListStoreTestAdapter(
            fetchUseCase: fetchSpy,
            configureDependencies: {
                $0.continuousClock = clock
            }
        )

        await adapter.onAppear()
        await fetchSpy.waitForCallCount(1)
        await adapter.setSortTarget(.updatedAt)

        await waitUntil(timeout: .seconds(2)) {
            adapter.todos == [TodoListItem(from: secondTodo)!]
        }

        let queries = await fetchSpy.calledQueries()
        let cancelledCalls = await fetchSpy.waitForCancelledCalls([0])

        #expect(adapter.todos == [TodoListItem(from: secondTodo)!])
        #expect(queries.map(\.sortTarget) == [.createdAt, .updatedAt])
        #expect(cancelledCalls == [0])
        #expect(!adapter.showAlert)

        await clock.advance(by: .milliseconds(300))

        #expect(!adapter.isLoading)
    }

    @Test("필터와 정렬 액션은 query와 적용 필터 수를 갱신한다")
    func 필터와_정렬_액션은_query와_적용_필터_수를_갱신한다() async {
        let adapter = TodoListStoreTestAdapter()

        await adapter.setSortTarget(.updatedAt)
        await adapter.setSortOrder(.oldest)
        await adapter.togglePinnedOnly()
        await adapter.setCompletionFilter(.completed)

        #expect(adapter.query.sortTarget == .updatedAt)
        #expect(adapter.query.sortOrder == .oldest)
        #expect(adapter.query.isPinned == true)
        #expect(adapter.query.completionFilter == .completed)
        #expect(adapter.appliedFilterCount == 4)

        await adapter.resetFilters()

        #expect(adapter.query == TodoQuery(categoryId: "feature"))
        #expect(adapter.appliedFilterCount == 0)
    }

    @Test("검색어는 디바운스 후 현재 카테고리 목록을 다시 조회한다")
    func 검색어는_디바운스_후_현재_카테고리_목록을_다시_조회한다() async {
        let todo = makeTodoListTodo(id: "todo-search", title: "Swift")
        let fetchSpy = TodoListFetchTodosUseCaseSpy(pages: [
            TodoPage(items: [todo], nextCursor: nil)
        ])
        let clock = TestClock()
        let adapter = TodoListStoreTestAdapter(
            fetchUseCase: fetchSpy,
            configureDependencies: {
                $0.continuousClock = clock
            }
        )

        await adapter.setSearchQuery(" swift ")
        await clock.advance(by: .milliseconds(400))
        await adapter.receiveSearchQueryDebounced()

        await waitUntil {
            fetchSpy.queries.count == 1
        }

        #expect(adapter.searchQuery == " swift ")
        #expect(fetchSpy.queries.map(\.categoryId) == ["feature"])
        #expect(fetchSpy.queries.map(\.keyword) == ["swift"])
        #expect(adapter.todos == [TodoListItem(from: todo)!])
    }

    @Test("검색 대기 중 다음 페이지를 요청해도 기존 목록에 검색 결과를 추가하지 않는다")
    func 검색_대기_중_다음_페이지를_요청해도_기존_목록에_검색_결과를_추가하지_않는다() async {
        let todos = (0..<20).map { makeTodoListTodo(id: "todo-\($0)", number: $0) }
        let todo = makeTodoListTodo(id: "todo-search", title: "Swift")
        let cursor = makeTodoListCursor(documentID: "cursor-1")
        let fetchSpy = TodoListFetchTodosUseCaseSpy(pages: [
            TodoPage(items: todos, nextCursor: cursor),
            TodoPage(items: [todo], nextCursor: nil)
        ])
        let clock = TestClock()
        let adapter = TodoListStoreTestAdapter(
            fetchUseCase: fetchSpy,
            configureDependencies: {
                $0.continuousClock = clock
            }
        )

        await adapter.onAppear()
        await waitUntil {
            adapter.hasMore && adapter.todos.count == 20
        }

        await adapter.setSearchQuery("swift")
        #expect(!adapter.hasMore)

        await adapter.loadNextPage()
        #expect(fetchSpy.queries.count == 1)
        #expect(adapter.todos == todos.compactMap(TodoListItem.init(from:)))

        await clock.advance(by: .milliseconds(400))
        await adapter.receiveSearchQueryDebounced()
        await waitUntil {
            adapter.todos == [TodoListItem(from: todo)!]
        }

        #expect(fetchSpy.queries.map(\.keyword) == [nil, "swift"])
        #expect(fetchSpy.cursors.map { $0?.documentID } == [nil, nil])
        #expect(!adapter.hasMore)
    }

    @Test("검색어 변경은 디바운스를 기다리지 않고 진행 중인 조회를 취소한다")
    func 검색어_변경은_디바운스를_기다리지_않고_진행_중인_조회를_취소한다() async throws {
        let firstTodo = makeTodoListTodo(id: "todo-first", number: 1)
        let todo = makeTodoListTodo(id: "todo-search", title: "Swift")
        let fetchSpy = DelayedFirstFetchTodosUseCaseSpy(pages: [
            TodoPage(items: [firstTodo], nextCursor: nil),
            TodoPage(items: [todo], nextCursor: nil)
        ])
        let clock = TestClock()
        let adapter = TodoListStoreTestAdapter(
            fetchUseCase: fetchSpy,
            configureDependencies: {
                $0.continuousClock = clock
            }
        )

        await adapter.onAppear()
        await fetchSpy.waitForCallCount(1)
        let target = try #require(adapter.loading.scheduledDelayedTargets.first)
        await clock.advance(by: .milliseconds(300))
        await adapter.receiveDelayedLoading(target: target)
        #expect(adapter.isLoading)

        await adapter.setSearchQuery("swift")

        let cancelledCalls = await fetchSpy.waitForCancelledCalls([0])
        #expect(cancelledCalls == [0])
        await adapter.receiveLoadingEnded(target: target)
        #expect(!adapter.isLoading)
        #expect(adapter.todos.isEmpty)

        await clock.advance(by: .milliseconds(400))
        await adapter.receiveSearchQueryDebounced()
        await waitUntil {
            adapter.todos == [TodoListItem(from: todo)!]
        }

        let queries = await fetchSpy.calledQueries()
        #expect(queries.map(\.keyword) == [nil, "swift"])
        #expect(!adapter.showAlert)
    }

    @Test("검색 조회가 끝나도 Todo 변경 작업의 로딩은 유지된다", arguments: [false, true])
    func 검색_조회가_끝나도_Todo_변경_작업의_로딩은_유지된다(togglesPinned: Bool) async {
        let todo = makeTodoListTodo(id: "todo-loading", title: "Swift")
        let item = TodoListItem(from: todo)!
        let fetchSpy = TodoListFetchTodosUseCaseSpy(pages: [
            TodoPage(items: [todo], nextCursor: nil)
        ])
        let fetchByIdSpy = TodoListFetchTodoByIdUseCaseSpy(todos: [todo])
        let upsertSpy = TodoListUpsertTodoUseCaseSpy()
        let completion = AsyncStream<Void>.makeStream()
        upsertSpy.completion = completion.stream
        defer { completion.continuation.finish() }
        let clock = TestClock()
        let adapter = TodoListStoreTestAdapter(
            fetchUseCase: fetchSpy,
            fetchTodoByIdUseCase: fetchByIdSpy,
            upsertUseCase: upsertSpy,
            configureDependencies: {
                $0.continuousClock = clock
            }
        )

        await adapter.appendTodos([item])
        if togglesPinned {
            await adapter.tapTogglePinned(item)
        } else {
            await adapter.tapToggleCompleted(item)
        }
        await waitUntil {
            upsertSpy.todos.count == 1
        }

        await clock.advance(by: .milliseconds(300))
        await adapter.receiveDelayedLoading()
        #expect(adapter.isLoading)

        await adapter.setSearchQuery("swift")
        await clock.advance(by: .milliseconds(400))
        await adapter.receiveSearchQueryDebounced()
        await waitUntil {
            fetchSpy.queries.count == 1
        }
        #expect(adapter.isLoading)

        completion.continuation.finish()
        await adapter.receiveLoadingEnded(target: .default)
        #expect(!adapter.isLoading)
    }

    @Test("검색 종료는 검색어를 지우고 현재 카테고리 목록을 다시 조회한다")
    func 검색_종료는_검색어를_지우고_현재_카테고리_목록을_다시_조회한다() async {
        let fetchSpy = TodoListFetchTodosUseCaseSpy()
        let clock = TestClock()
        let adapter = TodoListStoreTestAdapter(
            fetchUseCase: fetchSpy,
            configureDependencies: {
                $0.continuousClock = clock
            }
        )

        await adapter.setSearching(true)
        await adapter.setSearchQuery("swift")
        await adapter.setSearching(false)

        await waitUntil {
            fetchSpy.queries.count == 1
        }

        #expect(!adapter.isSearching)
        #expect(adapter.searchQuery.isEmpty)
        #expect(fetchSpy.queries.map(\.keyword) == [nil])
    }

    @Test("fullScreenCover 상태를 설정하고 dismiss 할 수 있다")
    func fullScreenCover_상태를_설정하고_dismiss_할_수_있다() async {
        let adapter = TodoListStoreTestAdapter()

        await adapter.setFullScreenCover(.editor)
        #expect(adapter.fullScreenCoverDestination == .editor)

        await adapter.dismissFullScreenCover()
        #expect(adapter.fullScreenCover == nil)
    }

    @Test("TodoEditor 생성 delegate는 editor를 닫고 목록을 새로 조회한다")
    func TodoEditor_생성_delegate는_editor를_닫고_목록을_새로_조회한다() async {
        let fetchSpy = TodoListFetchTodosUseCaseSpy()
        let trackSpy = TodoListTrackAnalyticsEventUseCaseSpy()
        let adapter = TodoListStoreTestAdapter(
            fetchUseCase: fetchSpy,
            trackAnalyticsEventUseCase: trackSpy
        )

        await adapter.setFullScreenCover(.editor)
        await adapter.todoEditorCreated()

        await waitUntil {
            fetchSpy.queries.count == 1 && trackSpy.hasTrackedTodoCreate
        }

        #expect(adapter.fullScreenCover == nil)
        #expect(fetchSpy.queries.map(\.categoryId) == ["feature"])
        #expect(fetchSpy.cursors.map { $0?.documentID } == [nil])
    }

    @Test("swipeTodo는 Todo를 숨기고 undoDelete와 finishDeleteToast는 숨김 상태를 되돌리거나 제거한다")
    func swipeTodo는_Todo를_숨기고_undoDelete와_finishDeleteToast는_숨김_상태를_되돌리거나_제거한다() async {
        let todo = makeTodoListTodo(id: "todo-delete")
        let item = TodoListItem(from: todo)!
        let deleteSpy = TodoListDeleteTodoUseCaseSpy()
        let undoSpy = TodoListUndoDeleteTodoUseCaseSpy()
        let adapter = TodoListStoreTestAdapter(
            deleteUseCase: deleteSpy,
            undoDeleteUseCase: undoSpy
        )

        await adapter.appendTodos([item])
        await adapter.swipeTodo(item)

        #expect(adapter.todos.first?.isHidden == true)

        await waitUntil {
            deleteSpy.todoIds == ["todo-delete"]
        }

        await adapter.undoDelete()

        #expect(adapter.todos.first?.isHidden == false)

        await waitUntil {
            undoSpy.todoIds == ["todo-delete"]
        }

        await adapter.swipeTodo(item)
        await adapter.finishDeleteToast("todo-delete")

        #expect(adapter.todos.isEmpty)
    }

    @Test("swipeTodo는 선택한 Todo를 지울 때만 선택을 해제한다")
    func swipeTodo는_선택한_Todo를_지울_때만_선택을_해제한다() async {
        let selected = TodoListItem(from: makeTodoListTodo(id: "todo-selected"))!
        let other = TodoListItem(from: makeTodoListTodo(id: "todo-other"))!
        let adapter = TodoListStoreTestAdapter()

        await adapter.appendTodos([selected, other])
        await adapter.selectTodo("todo-selected")
        await adapter.swipeTodo(other)

        #expect(adapter.selectedTodoId == "todo-selected")

        await adapter.swipeTodo(selected)

        #expect(adapter.selectedTodoId == nil)

        await adapter.undoDelete()

        #expect(adapter.selectedTodoId == nil)
    }

    @Test("tapToggleCompleted는 선택한 Todo일 때만 상세 칸을 다시 조회하도록 갱신한다")
    func tapToggleCompleted는_선택한_Todo일_때만_상세_칸을_다시_조회하도록_갱신한다() async {
        let todo = makeTodoListTodo(id: "todo-toggle", isPinned: false, isCompleted: false)
        let item = TodoListItem(from: todo)!
        let adapter = TodoListStoreTestAdapter(
            fetchTodoByIdUseCase: TodoListFetchTodoByIdUseCaseSpy(todos: [todo])
        )

        await adapter.appendTodos([item])
        await adapter.tapToggleCompleted(item)

        await waitUntil {
            adapter.todos.first?.isCompleted == true
        }

        #expect(adapter.detailRevision == 0)

        await adapter.selectTodo("todo-toggle")
        await adapter.tapToggleCompleted(adapter.todos[0])

        await waitUntil {
            adapter.detailRevision == 1
        }

        #expect(adapter.detailRevision == 1)
    }

    @Test("tapToggleCompleted와 tapTogglePinned는 조회한 Todo를 갱신해 목록에 반영한다")
    func tapToggleCompleted와_tapTogglePinned는_조회한_Todo를_갱신해_목록에_반영한다() async {
        let todo = makeTodoListTodo(id: "todo-toggle", isPinned: false, isCompleted: false)
        let item = TodoListItem(from: todo)!
        let fetchByIdSpy = TodoListFetchTodoByIdUseCaseSpy(todos: [todo])
        let upsertSpy = TodoListUpsertTodoUseCaseSpy()
        let trackSpy = TodoListTrackAnalyticsEventUseCaseSpy()
        let adapter = TodoListStoreTestAdapter(
            fetchTodoByIdUseCase: fetchByIdSpy,
            upsertUseCase: upsertSpy,
            trackAnalyticsEventUseCase: trackSpy
        )

        await adapter.appendTodos([item])
        await adapter.tapToggleCompleted(item)

        await waitUntil {
            adapter.todos.first?.isCompleted == true
        }

        #expect(upsertSpy.todos.first?.isCompleted == true)
        #expect(trackSpy.hasTrackedTodoComplete)

        fetchByIdSpy.todos = [upsertSpy.todos[0]]
        await adapter.tapTogglePinned(adapter.todos[0])

        await waitUntil {
            adapter.todos.first?.isPinned == true
        }

        #expect(upsertSpy.todos.last?.isPinned == true)
    }

    @Test("Todo 조회 실패 시 공통 에러 알림 상태를 표시한다")
    func Todo_조회_실패_시_공통_에러_알림_상태를_표시한다() async {
        let fetchSpy = TodoListFetchTodosUseCaseSpy()
        fetchSpy.error = ListTestError.failure
        let adapter = TodoListStoreTestAdapter(fetchUseCase: fetchSpy)

        await adapter.onAppear()

        await waitUntil {
            adapter.showAlert
        }

        #expect(adapter.showAlert)
        #expect(adapter.alert == expectedTodoListErrorAlert())
    }
}
