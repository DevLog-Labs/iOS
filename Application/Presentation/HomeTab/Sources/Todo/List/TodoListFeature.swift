//
//  TodoListFeature.swift
//  HomeTab
//
//  Created by opfic on 6/12/26.
//

import ComposableArchitecture
import Core
import Domain
import Foundation
import PresentationShared

@Reducer
struct TodoListFeature {
    @ObservableState
    struct State: Equatable {
        @Presents var alert: AlertState<Never>?
        @Presents var fullScreenCover: FullScreenCoverState?
        // 연 Todo 상세, 좁은 창은 내비게이션에 쌓고 사이드바가 있는 창은 상세 판이나 오른쪽 칸에 표시
        @Presents var detail: TodoDetailFeature.State?
        // 사이드바가 있는 창에서 상세 판 대신 목록 오른쪽 칸에 표시
        var showsDetailInPane = false
        var category: TodoCategory
        var todos: [TodoListItem] = []
        var query: TodoQuery
        var hasMore = false
        var isSearching = false
        var loading = LoadingFeature.State()
        var searchQuery = ""
        // Mac에서 마우스를 올린 행, 선택 행처럼 둥글게 표시하고 맞닿는 구분선을 숨김
        var hoveredTodoId: String?
        var undoTodoId: String?
        var nextCursor: TodoCursor?

        init(category: TodoCategory) {
            self.category = category
            self.query = TodoQuery(categoryId: category.storageValue)
        }

        var isLoading: Bool {
            loading.isLoading
        }

        var appliedFilterCount: Int {
            var count = 0
            if query.sortTarget != .createdAt { count += 1 }
            if query.sortOrder != .latest { count += 1 }
            if query.isPinned { count += 1 }
            if query.completionFilter != .all { count += 1 }
            return count
        }
    }

    @ObservableState
    struct FullScreenCoverState: Equatable {
        var destination: Destination
        var todoEditor: TodoEditorFeature.State?

        enum Destination: Equatable {
            case editor
        }

        static let editor = Self(destination: .editor)

        static func editor(_ category: TodoCategory) -> Self {
            Self(
                destination: .editor,
                todoEditor: TodoEditorFeature.State(category: category)
            )
        }
    }

    enum Action: BindableAction {
        case alert(PresentationAction<Never>)
        case fullScreenCover(PresentationAction<FullScreenCover>)
        case detail(PresentationAction<TodoDetailFeature.Action>)
        case binding(BindingAction<State>)
        case view(ViewAction)
        case store(StoreAction)
        case loading(LoadingFeature.Action)

        @CasePathable
        enum FullScreenCover: Equatable {
            case todoEditor(TodoEditorFeature.Action)
        }

        enum ViewAction: Equatable {
            case refresh
            // 사이드바가 있는 창은 연 곳(상세 판이나 오른쪽 칸)의 내용을 바꿈
            case selectTodo(String)
            case openTodo(String, inPane: Bool)
            case swipeTodo(TodoListItem)
            case resetFilters
            case finishDeleteToast(String)
            case tapToggleCompleted(TodoListItem)
            case tapTogglePinned(TodoListItem)
            case undoDelete
            case onAppear
            case windowTodoUpdated
            case loadNextPage
            case searchQueryDebounced
            case setSearching(Bool)
        }

        enum StoreAction: Equatable {
            case setFullScreenCover(FullScreenCoverState?)
            case setAlert(Bool)
            case didToggleCompleted(TodoListItem)
            case didTogglePinned(TodoListItem)
            case setTodoHidden(String, Bool)
            case appendTodos([TodoListItem], nextCursor: TodoCursor?)
            case setTodos([TodoListItem], nextCursor: TodoCursor?, hasMore: Bool)
            case setHasMore(Bool)
        }
    }

    enum CancelID: Hashable {
        case fetch
        case searchDebounce
    }

    private static let fetchLoadingTarget = LoadingFeature.Target("todoList.fetch")

    @Dependency(\.continuousClock) var clock
    @Dependency(\.todoListFetchTodosUseCase) var fetchTodosUseCase
    @Dependency(\.fetchTodoByIdUseCase) var fetchTodoByIdUseCase
    @Dependency(\.upsertTodoUseCase) var upsertTodoUseCase
    @Dependency(\.todoListDeleteTodoUseCase) var deleteTodoUseCase
    @Dependency(\.todoListUndoDeleteTodoUseCase) var undoDeleteTodoUseCase
    @Dependency(\.trackAnalyticsEventUseCase) var trackAnalyticsEventUseCase

    init() { }

    var body: some ReducerOf<Self> {
        Scope(state: \.loading, action: \.loading) {
            LoadingFeature()
        }
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .alert:
                break
            case .fullScreenCover(.presented(.todoEditor(.delegate(.created)))):
                state.fullScreenCover = nil
                return .merge(
                    trackTodoCreateEffect(),
                    fetchEffect(query: state.query, cursor: nil, showsIndicator: false)
                )
            case .fullScreenCover(.dismiss):
                state.fullScreenCover = nil
            case .fullScreenCover:
                break
            case .detail(.dismiss):
                state.showsDetailInPane = false
            case .detail:
                break
            case .binding(\.query.sortTarget), .binding(\.query.sortOrder), .binding(\.query.isPinned),
                    .binding(\.query.completionFilter):
                state.nextCursor = nil
                return .merge(
                    .cancel(id: CancelID.searchDebounce),
                    fetchEffect(query: state.query, cursor: nil)
                )
            case .binding(\.searchQuery):
                let keyword = state.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
                state.query.keyword = keyword.isEmpty ? nil : keyword
                state.nextCursor = nil
                state.hasMore = false
                if keyword.isEmpty {
                    return .merge(
                        .cancel(id: CancelID.searchDebounce),
                        fetchEffect(query: state.query, cursor: nil)
                    )
                }
                return .concatenate(
                    .cancel(id: CancelID.fetch),
                    .send(.loading(.end(target: Self.fetchLoadingTarget, mode: .delayed))),
                    .cancel(id: CancelID.searchDebounce),
                    debounceSearchEffect()
                )
            case .binding:
                break
            case .view(let action):
                return reduce(action, state: &state)
            case .store(let action):
                return reduce(action, state: &state)
            case .loading:
                break
            }

            return .none
        }
        .ifLet(\.$alert, action: \.alert)
        .ifLet(\.$fullScreenCover, action: \.fullScreenCover) {
            FullScreenCoverFeature()
        }
        .ifLet(\.$detail, action: \.detail) {
            TodoDetailFeature()
        }
    }
}

private struct FullScreenCoverFeature: Reducer {
    typealias State = TodoListFeature.FullScreenCoverState
    typealias Action = TodoListFeature.Action.FullScreenCover

    var body: some ReducerOf<Self> {
        EmptyReducer()
            .ifLet(\.todoEditor, action: \.todoEditor) {
                TodoEditorFeature()
            }
    }
}

extension DependencyValues {
    var todoListFetchTodosUseCase: FetchTodosUseCase {
        get { self[FetchTodosUseCaseKey.self] }
        set { self[FetchTodosUseCaseKey.self] = newValue }
    }

    var todoListDeleteTodoUseCase: DeleteTodoUseCase {
        get { self[DeleteTodoUseCaseKey.self] }
        set { self[DeleteTodoUseCaseKey.self] = newValue }
    }

    var todoListUndoDeleteTodoUseCase: UndoDeleteTodoUseCase {
        get { self[UndoDeleteTodoUseCaseKey.self] }
        set { self[UndoDeleteTodoUseCaseKey.self] = newValue }
    }
}

private enum FetchTodosUseCaseKey: DependencyKey {
    static var liveValue: FetchTodosUseCase {
        preconditionFailure("FetchTodosUseCase must be provided.")
    }

    static var testValue: FetchTodosUseCase {
        liveValue
    }
}

private enum DeleteTodoUseCaseKey: DependencyKey {
    static var liveValue: DeleteTodoUseCase {
        preconditionFailure("DeleteTodoUseCase must be provided.")
    }

    static var testValue: DeleteTodoUseCase {
        liveValue
    }
}

private enum UndoDeleteTodoUseCaseKey: DependencyKey {
    static var liveValue: UndoDeleteTodoUseCase {
        preconditionFailure("UndoDeleteTodoUseCase must be provided.")
    }

    static var testValue: UndoDeleteTodoUseCase {
        liveValue
    }
}

private extension TodoListFeature {
    func fetchEffect(
        query: TodoQuery,
        cursor: TodoCursor?,
        resetsPagination: Bool = true,
        showsIndicator: Bool = true
    ) -> Effect<Action> {
        .concatenate(
            .send(.loading(.end(target: Self.fetchLoadingTarget, mode: .delayed))),
            showsIndicator ? .send(.loading(.begin(target: Self.fetchLoadingTarget, mode: .delayed))) : .none,
            .run { [fetchTodosUseCase] send in
                do {
                    let page = try await fetchTodosUseCase.execute(query, cursor: cursor)
                    let todos = page.items.compactMap(TodoListItem.init(from:))
                    let hasMore = page.items.count == query.pageSize && page.nextCursor != nil
                    // 비운 목록이나 이전 다음 페이지 여부가 한 번 그려지지 않도록 첫 페이지는 한 번에 교체
                    if resetsPagination {
                        await send(.store(.setTodos(todos, nextCursor: page.nextCursor, hasMore: hasMore)))
                    } else {
                        await send(.store(.appendTodos(todos, nextCursor: page.nextCursor)))
                        await send(.store(.setHasMore(hasMore)))
                    }
                    if showsIndicator {
                        await send(.loading(.end(target: Self.fetchLoadingTarget, mode: .delayed)))
                    }
                } catch is CancellationError {
                    return
                } catch {
                    await send(.store(.setAlert(true)))
                    if showsIndicator {
                        await send(.loading(.end(target: Self.fetchLoadingTarget, mode: .delayed)))
                    }
                }
            }
        )
        .cancellable(id: CancelID.fetch, cancelInFlight: true)
    }

    func debounceSearchEffect() -> Effect<Action> {
        .run { [clock] send in
            try await clock.sleep(for: .milliseconds(400))
            await send(.view(.searchQueryDebounced))
        }
        .cancellable(id: CancelID.searchDebounce, cancelInFlight: true)
    }

    func reduce(
        _ action: Action.ViewAction,
        state: inout State
    ) -> Effect<Action> {
        switch action {
        case .refresh:
            return fetchEffect(query: state.query, cursor: nil, showsIndicator: false)
        case .selectTodo(let todoId):
            // 이미 연 Todo는 불러온 상세와 열어 둔 시트를 그대로 둠
            if state.detail?.todoId != todoId {
                state.detail = TodoDetailFeature.State(todoId: todoId, showEditButton: true)
            }
        case .openTodo(let todoId, let inPane):
            state.showsDetailInPane = inPane
            return reduce(.selectTodo(todoId), state: &state)
        case .onAppear:
            return fetchEffect(query: state.query, cursor: nil)
        case .windowTodoUpdated:
            // 편집으로 목록 조건에서 벗어난 Todo도 반영되도록 다시 조회
            return fetchEffect(query: state.query, cursor: nil, showsIndicator: false)
        case .swipeTodo(let todo):
            return swipeTodoEffect(todo, state: &state)
        case .resetFilters:
            state.query = TodoQuery(
                categoryId: state.category.storageValue,
                keyword: state.query.keyword
            )
            state.nextCursor = nil
            return .merge(
                .cancel(id: CancelID.searchDebounce),
                fetchEffect(query: state.query, cursor: nil)
            )
        case .finishDeleteToast(let todoId):
            state.todos.removeAll { $0.id == todoId && $0.isHidden }
            if state.undoTodoId == todoId {
                state.undoTodoId = nil
            }
        case .tapToggleCompleted(let todo):
            return toggleCompletedEffect(todo)
        case .tapTogglePinned(let todo):
            return togglePinnedEffect(todo)
        case .undoDelete:
            guard let undoTodoId = state.undoTodoId else { return .none }
            Self.setTodoHidden(&state, todoId: undoTodoId, isHidden: false)
            state.undoTodoId = nil
            return undoDeleteEffect(undoTodoId)
        case .loadNextPage:
            guard state.hasMore, !state.isLoading else { return .none }
            return fetchEffect(query: state.query, cursor: state.nextCursor, resetsPagination: false)
        case .searchQueryDebounced:
            return fetchEffect(query: state.query, cursor: nil)
        case .setSearching(let isSearching):
            state.isSearching = isSearching
            guard !isSearching, !state.searchQuery.isEmpty else { return .none }
            state.searchQuery = ""
            state.query.keyword = nil
            state.nextCursor = nil
            state.hasMore = false
            return .merge(
                .cancel(id: CancelID.searchDebounce),
                fetchEffect(query: state.query, cursor: nil)
            )
        }

        return .none
    }

    func reduce(
        _ action: Action.StoreAction,
        state: inout State
    ) -> Effect<Action> {
        switch action {
        case .setFullScreenCover(let cover):
            // 칸에 그린 작성 화면은 계속 누를 수 있는 사이드바에서 다시 열어도 초안을 바꾸지 않음
            if cover?.destination == .editor && state.fullScreenCover?.todoEditor != nil { break }
            state.fullScreenCover = cover?.destination == .editor ? .editor(state.category) : nil
        case .setAlert(let value):
            Self.setAlert(&state, isPresented: value)
        case .didToggleCompleted(let todo), .didTogglePinned(let todo):
            if let index = state.todos.firstIndex(where: { $0.id == todo.id }) {
                state.todos[index] = todo
            }
            // 연 상세와 세부 정보 사이드바가 바뀐 완료, 중요 상태를 다시 조회
            if todo.id == state.detail?.todoId {
                return .send(.detail(.presented(.fetch)))
            }
        case .setTodoHidden(let todoId, let isHidden):
            Self.setTodoHidden(&state, todoId: todoId, isHidden: isHidden)
        case .appendTodos(let todos, let nextCursor):
            state.todos.append(contentsOf: todos)
            state.nextCursor = nextCursor
        case .setTodos(let todos, let nextCursor, let hasMore):
            state.todos = todos
            state.nextCursor = nextCursor
            state.hasMore = hasMore
        case .setHasMore(let value):
            state.hasMore = value
        }

        return .none
    }
}
