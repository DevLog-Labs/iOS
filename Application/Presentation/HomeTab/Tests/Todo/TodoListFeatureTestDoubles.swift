//
//  TodoListFeatureTestDoubles.swift
//  HomeTabTests
//
//  Created by opfic on 6/12/26.
//

import Foundation
import Core
import Domain
import PresentationShared
@testable import HomeTab

@MainActor
final class TodoListStoreTestAdapter {
    private let store: TestStoreOf<TodoListFeature>

    var todos: [TodoListItem] { store.state.todos }
    var query: TodoQuery { store.state.query }
    var isSearching: Bool { store.state.isSearching }
    var searchQuery: String { store.state.searchQuery }
    var isLoading: Bool { store.state.isLoading }
    var loading: LoadingFeature.State { store.state.loading }
    var hasMore: Bool { store.state.hasMore }
    var alert: AlertState<Never>? { store.state.alert }
    var fullScreenCover: TodoListFeature.FullScreenCoverState? { store.state.fullScreenCover }
    var fullScreenCoverDestination: TodoListFeature.FullScreenCoverState.Destination? {
        store.state.fullScreenCover?.destination
    }
    var showAlert: Bool { store.state.alert != nil }
    var appliedFilterCount: Int { store.state.appliedFilterCount }
    var selectedTodoId: String? { store.state.selectedTodoId }
    var detailRevision: Int { store.state.detailRevision }

    init(
        fetchUseCase: FetchTodosUseCase = TodoListFetchTodosUseCaseSpy(),
        fetchTodoByIdUseCase: FetchTodoByIdUseCase = TodoListFetchTodoByIdUseCaseSpy(),
        upsertUseCase: UpsertTodoUseCase = TodoListUpsertTodoUseCaseSpy(),
        deleteUseCase: DeleteTodoUseCase = TodoListDeleteTodoUseCaseSpy(),
        undoDeleteUseCase: UndoDeleteTodoUseCase = TodoListUndoDeleteTodoUseCaseSpy(),
        trackAnalyticsEventUseCase: TrackAnalyticsEventUseCase = TodoListTrackAnalyticsEventUseCaseSpy(),
        category: TodoCategory = .system(.feature),
        configureDependencies: ((inout DependencyValues) -> Void)? = nil
    ) {
        store = TestStore(initialState: TodoListFeature.State(category: category)) {
            TodoListFeature()
        } withDependencies: {
            $0.todoListFetchTodosUseCase = fetchUseCase
            $0.fetchTodoByIdUseCase = fetchTodoByIdUseCase
            $0.upsertTodoUseCase = upsertUseCase
            $0.todoListDeleteTodoUseCase = deleteUseCase
            $0.todoListUndoDeleteTodoUseCase = undoDeleteUseCase
            $0.trackAnalyticsEventUseCase = trackAnalyticsEventUseCase
            $0.continuousClock = ContinuousClock()
            configureDependencies?(&$0)
        }
        store.exhaustivity = .off(showSkippedAssertions: false)
    }

    func onAppear() async {
        await store.send(.view(.onAppear))
        await drainReceivedActions()
    }

    func loadNextPage() async {
        await store.send(.view(.loadNextPage))
        await drainReceivedActions()
    }

    func setSortTarget(_ target: TodoQuery.SortTarget) async {
        await store.send(.binding(.set(\.query.sortTarget, target)))
        await drainReceivedActions()
    }

    func setSortOrder(_ order: TodoQuery.SortOrder) async {
        await store.send(.binding(.set(\.query.sortOrder, order)))
        await drainReceivedActions()
    }

    func togglePinnedOnly() async {
        await store.send(.binding(.set(\.query.isPinned, !store.state.query.isPinned)))
        await drainReceivedActions()
    }

    func setCompletionFilter(_ filter: TodoQuery.CompletionFilter) async {
        await store.send(.binding(.set(\.query.completionFilter, filter)))
        await drainReceivedActions()
    }

    func setSearchQuery(_ query: String) async {
        let keyword = query.trimmingCharacters(in: .whitespacesAndNewlines)
        await store.send(.binding(.set(\.searchQuery, query))) {
            $0.searchQuery = query
            $0.query.keyword = keyword.isEmpty ? nil : keyword
            $0.nextCursor = nil
            $0.hasMore = false
        }
    }

    func receiveSearchQueryDebounced() async {
        await store.receive(\.view, .searchQueryDebounced)
        await drainReceivedActions()
    }

    func receiveDelayedLoading(target: LoadingFeature.Target = .default) async {
        await store.receive(\.loading, .delayedLoadingDidBecomeVisible(target: target))
        await drainReceivedActions()
    }

    func receiveLoadingEnded(target: LoadingFeature.Target) async {
        await store.receive(\.loading, .end(target: target, mode: .delayed))
        await drainReceivedActions()
    }

    func setSearching(_ value: Bool) async {
        await store.send(.view(.setSearching(value)))
        await drainReceivedActions()
    }

    func resetFilters() async {
        await store.send(.view(.resetFilters))
        await drainReceivedActions()
    }

    func appendTodos(_ todos: [TodoListItem]) async {
        await store.send(.store(.appendTodos(todos, nextCursor: nil)))
    }

    func setFullScreenCover(_ cover: TodoListFeature.FullScreenCoverState?) async {
        await store.send(.store(.setFullScreenCover(cover)))
    }

    func dismissFullScreenCover() async {
        await store.send(.fullScreenCover(.dismiss))
    }

    func todoEditorCreated() async {
        await store.send(.fullScreenCover(.presented(.todoEditor(.delegate(.created)))))
        await drainReceivedActions()
    }

    func swipeTodo(_ todo: TodoListItem) async {
        await store.send(.view(.swipeTodo(todo)))
        await drainReceivedActions()
    }

    func undoDelete() async {
        await store.send(.view(.undoDelete))
        await drainReceivedActions()
    }

    func finishDeleteToast(_ todoId: String) async {
        await store.send(.view(.finishDeleteToast(todoId)))
    }

    func resetPagination() async {
        await store.send(.store(.resetPagination))
    }

    func selectTodo(_ todoId: String?) async {
        await store.send(.binding(.set(\.selectedTodoId, todoId)))
    }

    func tapToggleCompleted(_ todo: TodoListItem) async {
        await store.send(.view(.tapToggleCompleted(todo)))
        await drainReceivedActions()
    }

    func tapTogglePinned(_ todo: TodoListItem) async {
        await store.send(.view(.tapTogglePinned(todo)))
        await drainReceivedActions()
    }

    private func drainReceivedActions() async {
        for _ in 0..<8 {
            await store.skipReceivedActions(strict: false)
        }
    }
}

func expectedTodoListErrorAlert() -> AlertState<Never> {
    AlertState {
        TextState(String(localized: "common_error_title", bundle: PresentationResources.bundle))
    } actions: {
        ButtonState(role: .cancel) {
            TextState(String(localized: "common_close", bundle: PresentationResources.bundle))
        }
    } message: {
        TextState(String(localized: "common_error_message", bundle: PresentationResources.bundle))
    }
}

final class TodoListFetchTodosUseCaseSpy: FetchTodosUseCase {
    var pages: [TodoPage]
    var error: Error?
    private(set) var queries = [TodoQuery]()
    private(set) var cursors = [TodoCursor?]()

    init(pages: [TodoPage] = [TodoPage(items: [], nextCursor: nil)]) {
        self.pages = pages
    }

    func execute(_ query: TodoQuery, cursor: TodoCursor?) async throws -> TodoPage {
        queries.append(query)
        cursors.append(cursor)

        if let error {
            throw error
        }

        if pages.count <= queries.count - 1 {
            return pages.last ?? TodoPage(items: [], nextCursor: nil)
        }

        return pages[queries.count - 1]
    }
}

actor DelayedFirstFetchTodosUseCaseSpy: FetchTodosUseCase {
    private let pages: [TodoPage]
    private var queries = [TodoQuery]()
    private var cursors = [TodoCursor?]()
    private var cancelledCallIndices = [Int]()

    init(pages: [TodoPage]) {
        self.pages = pages
    }

    func execute(_ query: TodoQuery, cursor: TodoCursor?) async throws -> TodoPage {
        let callIndex = queries.count
        queries.append(query)
        cursors.append(cursor)

        if callIndex == 0 {
            do {
                try await Task.sleep(for: .seconds(1))
            } catch is CancellationError {
                cancelledCallIndices.append(callIndex)
                throw CancellationError()
            }
        }

        if pages.count <= callIndex {
            return pages.last ?? TodoPage(items: [], nextCursor: nil)
        }

        return pages[callIndex]
    }

    func calledQueries() -> [TodoQuery] {
        queries
    }

    func calledCursors() -> [TodoCursor?] {
        cursors
    }

    func waitForCallCount(_ count: Int, timeout: Duration = .seconds(2)) async {
        let clock = ContinuousClock()
        let deadline = clock.now + timeout

        while queries.count < count && clock.now < deadline {
            try? await Task.sleep(for: .milliseconds(20))
        }
    }

    func waitForCancelledCalls(_ expected: [Int], timeout: Duration = .seconds(2)) async -> [Int] {
        let clock = ContinuousClock()
        let deadline = clock.now + timeout

        while cancelledCallIndices != expected && clock.now < deadline {
            try? await Task.sleep(for: .milliseconds(20))
        }

        return cancelledCallIndices
    }

    func cancelledCalls() -> [Int] {
        cancelledCallIndices
    }
}

final class TodoListFetchTodoByIdUseCaseSpy: FetchTodoByIdUseCase {
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

        return todos.first { $0.id == todoId } ?? makeTodoListTodo(id: todoId)
    }
}

final class TodoListUpsertTodoUseCaseSpy: UpsertTodoUseCase {
    var error: Error?
    var completion: AsyncStream<Void>?
    private(set) var todos = [Todo]()
    private(set) var todoDrafts = [TodoDraft]()

    func execute(_ todo: Todo) async throws {
        todos.append(todo)

        if let error {
            throw error
        }

        if let completion {
            for await _ in completion {
                break
            }
        }
    }

    func execute(_ todoDraft: TodoDraft) async throws {
        todoDrafts.append(todoDraft)

        if let error {
            throw error
        }
    }
}

final class TodoListDeleteTodoUseCaseSpy: DeleteTodoUseCase {
    var error: Error?
    private(set) var todoIds = [String]()

    func execute(_ todoId: String) async throws {
        todoIds.append(todoId)

        if let error {
            throw error
        }
    }
}

final class TodoListUndoDeleteTodoUseCaseSpy: UndoDeleteTodoUseCase {
    var error: Error?
    private(set) var todoIds = [String]()

    func execute(_ todoId: String) async throws {
        todoIds.append(todoId)

        if let error {
            throw error
        }
    }
}

final class TodoListTrackAnalyticsEventUseCaseSpy: TrackAnalyticsEventUseCase {
    private(set) var events = [AnalyticsEvent]()
    var hasTrackedTodoCreate: Bool {
        events.contains {
            guard case .todoCreate = $0 else { return false }
            return true
        }
    }
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

enum ListTestError: Error {
    case failure
}

func makeTodoListTodo(
    id: String = "todo-1",
    isPinned: Bool = false,
    isCompleted: Bool = false,
    number: Int = 1,
    title: String = "Todo"
) -> Todo {
    Todo(
        id: id,
        isPinned: isPinned,
        isCompleted: isCompleted,
        isChecked: false,
        number: number,
        title: title,
        content: "content",
        createdAt: Date(timeIntervalSince1970: 0),
        updatedAt: Date(timeIntervalSince1970: 0),
        completedAt: isCompleted ? Date(timeIntervalSince1970: 0) : nil,
        deletedAt: nil,
        dueDate: nil,
        tags: [],
        category: .system(.feature)
    )
}

func makeTodoListCursor(documentID: String) -> TodoCursor {
    TodoCursor(
        primarySortDate: Date(timeIntervalSince1970: 0),
        secondarySortDate: Date(timeIntervalSince1970: 0),
        documentID: documentID
    )
}
