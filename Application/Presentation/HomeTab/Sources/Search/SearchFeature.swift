//
//  SearchFeature.swift
//  HomeTab
//
//  Created by opfic on 6/12/26.
//

import Foundation
import Core
import Domain
import PresentationShared

@Reducer
struct SearchFeature {
    @ObservableState
    struct State: Equatable {
        @Presents var alert: AlertState<Never>?
        var loading = LoadingFeature.State()
        var isSearching = false
        var searchQuery = ""
        var todos: [SearchTodoItem] = []
        var recentQueries = OrderedSet<String>()
        var showAllTodos = false
        // Mac에서 사이드바까지 덮는 상세 판에 연 Todo
        var panelTodo: TodoIdItem?
        let contentsLimit = 5

        init(recentQueries: [String] = []) {
            self.recentQueries = OrderedSet(recentQueries)
        }

        var isLoading: Bool {
            loading.isLoading
        }

        var visibleTodos: [SearchTodoItem] {
            if showAllTodos {
                return todos
            }

            return Array(todos.prefix(contentsLimit))
        }

        var shouldShowMoreTodos: Bool {
            !showAllTodos && contentsLimit < todos.count
        }

        var isHashOnlyQuery: Bool {
            searchQuery.trimmingCharacters(in: .whitespacesAndNewlines) == "#"
        }
    }

    enum Action: BindableAction, Equatable {
        case onAppear
        case alert(PresentationAction<Never>)
        case binding(BindingAction<State>)
        case addRecentQuery(String)
        case removeRecentQuery(String)
        case clearRecentQueries
        case setShowAllTodos(Bool)
        case store(StoreAction)
        case loading(LoadingFeature.Action)

        enum StoreAction: Equatable {
            case fetchTodos([SearchTodoItem])
            case applySearchQuery(String)
            case setAlert(Bool)
        }
    }

    private enum CancelID: Hashable {
        case debounce
        case request
    }

    @Dependency(\.continuousClock) var clock
    @Dependency(\.searchFetchTodosUseCase) var fetchTodosUseCase
    @Dependency(\.searchUpdateRecentQueriesUseCase) var updateRecentSearchQueriesUseCase

    private let maxRecentQueries = 20
    private let searchDebounceDelay = Duration.seconds(0.4)

    var body: some ReducerOf<Self> {
        Scope(state: \.loading, action: \.loading) {
            LoadingFeature()
        }
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .run { send in
                    // `.searchable` 바인딩이 화면에 붙은 뒤 포커스를 요청하도록 main queue 다음 턴으로 넘긴다.
                    await withCheckedContinuation { continuation in
                        DispatchQueue.main.async { continuation.resume() }
                    }
                    await send(.binding(.set(\.isSearching, true)))
                }
            case .alert:
                break
            case .binding(\.isSearching):
                if !state.isSearching {
                    return Self.cancelSearchEffect(isLoading: state.isLoading)
                }
            case .binding(\.searchQuery):
                state.showAllTodos = false
                let trimmed = state.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty || trimmed == "#" {
                    state.todos = []
                    return Self.cancelSearchEffect(isLoading: state.isLoading)
                } else {
                    return .concatenate(
                        Self.cancelSearchEffect(isLoading: state.isLoading),
                        debounceFetchEffect(trimmed)
                    )
                }
            case .binding:
                break
            case .store(.fetchTodos(let items)):
                state.todos = items
            case .addRecentQuery(let query):
                let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { break }
                state.recentQueries.remove(trimmed)
                state.recentQueries.insert(trimmed, at: 0)
                if maxRecentQueries < state.recentQueries.count {
                    state.recentQueries = OrderedSet(state.recentQueries.prefix(maxRecentQueries))
                }
                return saveRecentQueriesEffect(state.recentQueries)
            case .removeRecentQuery(let query):
                state.recentQueries.remove(query)
                return saveRecentQueriesEffect(state.recentQueries)
            case .clearRecentQueries:
                state.recentQueries = []
                return saveRecentQueriesEffect([])
            case .store(.applySearchQuery(let query)):
                let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty || trimmed == "#" {
                    state.todos = []
                    return Self.cancelSearchEffect(isLoading: state.isLoading)
                } else {
                    return fetchEffect(trimmed, isLoading: state.isLoading)
                }
            case .store(.setAlert(let isPresented)):
                state.alert = isPresented ? Self.alertState() : nil
            case .setShowAllTodos(let shouldShowAll):
                state.showAllTodos = shouldShowAll
            case .loading:
                break
            }

            return .none
        }
        .ifLet(\.$alert, action: \.alert)
    }
}

extension DependencyValues {
    var searchFetchTodosUseCase: FetchTodosUseCase {
        get { self[SearchFetchTodosUseCaseKey.self] }
        set { self[SearchFetchTodosUseCaseKey.self] = newValue }
    }

    var searchUpdateRecentQueriesUseCase: UpdateRecentSearchQueriesUseCase {
        get { self[SearchUpdateRecentQueriesUseCaseKey.self] }
        set { self[SearchUpdateRecentQueriesUseCaseKey.self] = newValue }
    }
}

private enum SearchFetchTodosUseCaseKey: DependencyKey {
    static var liveValue: FetchTodosUseCase {
        preconditionFailure("FetchTodosUseCase must be provided.")
    }

    static var testValue: FetchTodosUseCase {
        liveValue
    }
}

private enum SearchUpdateRecentQueriesUseCaseKey: DependencyKey {
    static var liveValue: UpdateRecentSearchQueriesUseCase {
        preconditionFailure("UpdateRecentSearchQueriesUseCase must be provided.")
    }

    static var testValue: UpdateRecentSearchQueriesUseCase {
        liveValue
    }
}

private extension SearchFeature {
    static func cancelSearchEffect(isLoading: Bool) -> Effect<Action> {
        .merge(
            .cancel(id: CancelID.debounce),
            .cancel(id: CancelID.request),
            Self.endLoadingEffect(isLoading: isLoading)
        )
    }

    func debounceFetchEffect(_ query: String) -> Effect<Action> {
        .concatenate(
            .send(.loading(.begin(target: .default, mode: .immediate))),
            .run { [clock, searchDebounceDelay] send in
                try await clock.sleep(for: searchDebounceDelay)
                await send(.store(.applySearchQuery(query)))
            }
            .cancellable(id: CancelID.debounce, cancelInFlight: true)
        )
    }

    func fetchEffect(_ query: String, isLoading: Bool) -> Effect<Action> {
        .run { [fetchTodosUseCase] send in
            do {
                let todos = try await fetchTodosUseCase.execute(TodoQuery(keyword: query), cursor: nil)
                let todoItems = todos.items.map(SearchTodoItem.init(todo:))
                await send(.store(.fetchTodos(todoItems)))
                if isLoading {
                    await send(.loading(.end(target: .default, mode: .immediate)))
                }
            } catch is CancellationError {
                return
            } catch {
                if isLoading {
                    await send(.loading(.end(target: .default, mode: .immediate)))
                }
                await send(.store(.setAlert(true)))
            }
        }
        .cancellable(id: CancelID.request, cancelInFlight: true)
    }

    static func endLoadingEffect(isLoading: Bool) -> Effect<Action> {
        guard isLoading else { return .none }
        return .send(.loading(.end(target: .default, mode: .immediate)))
    }

    func saveRecentQueriesEffect(_ queries: OrderedSet<String>) -> Effect<Action> {
        let values = Array(queries)
        return .run { [updateRecentSearchQueriesUseCase] _ in
            updateRecentSearchQueriesUseCase.execute(values)
        }
    }

    static func alertState() -> AlertState<Never> {
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
}
