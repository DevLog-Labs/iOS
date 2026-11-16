//
//  TodayFeature.swift
//  TodayTab
//
//  Created by opfic on 6/14/26.
//

import Core
import Domain
import Foundation
import PresentationShared

@Reducer
struct TodayFeature {
    enum TodoScope: Hashable, CaseIterable {
        case remaining
        case important
    }

    enum SectionCategory: Hashable {
        case later
        case unscheduled
        case today
        case overdue
        case upcoming
    }

    struct SectionContent: Identifiable, Equatable {
        var id: SectionCategory { category }
        let category: SectionCategory
        let title: String
        let items: [TodayTodoItem]
    }

    struct SectionCollection {
        var overdue: [TodayTodoItem] = []
        var today: [TodayTodoItem] = []
        var upcoming: [TodayTodoItem] = []
        var later: [TodayTodoItem] = []
        var unscheduled: [TodayTodoItem] = []
    }

    enum Action: BindableAction, Equatable {
        case alert(PresentationAction<Never>)
        case binding(BindingAction<State>)
        case refresh
        case fetchData
        case checkCurrentDate(Date)
        case setTodoScope(TodoScope)
        case setCategory(String?)
        case completeTodo(TodayTodoItem)
        case showTodoInspector(TodayTodoItem)
        case dismissTodoInspector
        case moveTodoInspectorToSideBar
        case todoEditor(TodoEditorFeature.Action)
        case store(StoreAction)
        case loading(LoadingFeature.Action)

        enum StoreAction: Equatable {
            case setAlert
            case setTodos(
                incomplete: [TodayTodoItem],
                completedToday: [TodayTodoItem],
                interval: DateInterval
            )
            case setCompletedTodayTodos([TodayTodoItem], interval: DateInterval)
            case setCategories([TodoCategoryItem])
            case updateTodo(TodayTodoItem)
            case removeTodo(String)
        }
    }

    @Dependency(\.todayFetchTodosUseCase) var fetchTodosUseCase
    @Dependency(\.fetchTodoCategoryPreferencesUseCase) var fetchCategoryPreferencesUseCase
    @Dependency(\.fetchTodoByIdUseCase) var fetchTodoByIdUseCase
    @Dependency(\.upsertTodoUseCase) var upsertTodoUseCase
    @Dependency(\.trackAnalyticsEventUseCase) var trackAnalyticsEventUseCase
    @Dependency(\.date.now) var now

    static let pageSize = 20
    static let upcomingWindowDays = 7

    var body: some ReducerOf<Self> {
        Scope(state: \.loading, action: \.loading) {
            LoadingFeature()
        }
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .alert:
                break
            case .binding(\.isTodoInspectorPresented):
                if !state.isTodoInspectorPresented {
                    dismissTodoInspector(state: &state)
                }
            case .binding:
                break
            case .refresh:
                let interval = prepareTodayInterval(state: &state, now: now)
                return .concatenate(
                    fetchTodosEffect(interval: interval, showsIndicator: false),
                    fetchCategoriesEffect()
                )
            case .fetchData:
                let interval = prepareTodayInterval(state: &state, now: now)
                return .concatenate(
                    fetchTodosEffect(interval: interval),
                    fetchCategoriesEffect()
                )
            case .checkCurrentDate(let date):
                let interval = Self.dayInterval(containing: date)
                guard state.todayInterval != interval else { break }
                let requiresFullFetch = !state.isIncompleteDataLoaded
                state.todayInterval = interval
                state.completedTodayTodos = []
                state.isCompletedTodayDataLoaded = false
                if requiresFullFetch {
                    return fetchTodosEffect(interval: interval, showsIndicator: false)
                }
                return fetchCompletedTodayTodosEffect(interval: interval)
            case .setTodoScope(let scope):
                state.selectedTodoScope = scope
            case .setCategory(let categoryID):
                state.selectedCategoryID = categoryID
            case .completeTodo(let item):
                return completeTodoEffect(item)
            case .showTodoInspector(let item):
                guard let item = latestItem(id: item.id, state: state) else { break }
                state.todoEditor = TodoEditorFeature.State(todo: item.todo)
                state.dismissesTodoInspectorAfterSaving = false
                state.isTodoInspectorPresented = true
            case .dismissTodoInspector:
                dismissTodoInspector(state: &state)
            case .moveTodoInspectorToSideBar:
                guard state.isTodoInspectorPresented, let editor = state.todoEditor else { break }
                // 고친 값이 없으면 바로 닫고 같은 Todo를 목록에서 고름
                guard editor.isReadyToSubmit || editor.isLoading else {
                    state.selectedTodoId = editor.id
                    dismissTodoInspector(state: &state)
                    break
                }
                // 세부 정보 사이드바가 저장 전 Todo를 불러오지 않도록 저장이 끝날 때까지 고른 Todo를 비워 둠
                state.selectedTodoId = nil
                state.todoIdToSelectAfterSaving = editor.id
                // 저장 버튼으로 이미 저장 중이면 그 저장이 끝나기를 기다림
                guard !editor.isLoading else { break }
                // 고친 값은 저장 버튼과 같이 저장한 뒤 닫음
                return .send(.todoEditor(.upsertTodo))
            case .todoEditor(.delegate(.updated(let todo))):
                guard let item = TodayTodoItem(from: todo) else {
                    return .send(.store(.setAlert))
                }
                state.dismissesTodoInspectorAfterSaving = true
                return .send(.store(.updateTodo(item)))
            case .todoEditor(.loading(.end(target: .default, mode: .immediate))):
                if let id = state.todoIdToSelectAfterSaving {
                    // 가려진 시트 대신 오늘 화면에서 저장 실패를 알림
                    if state.todoEditor?.saveResult == nil {
                        state.alert = Self.alertState()
                    }
                    state.selectedTodoId = id
                    dismissTodoInspector(state: &state)
                    break
                }
                guard state.dismissesTodoInspectorAfterSaving else { break }
                return .send(.dismissTodoInspector)
            case .todoEditor:
                break
            case .store(.setAlert):
                state.alert = Self.alertState()
            case .store(.setTodos(let incomplete, let completedToday, let interval)):
                guard state.todayInterval == interval else { break }
                state.todos = incomplete
                state.isIncompleteDataLoaded = true
                state.completedTodayTodos = completedToday
                state.isCompletedTodayDataLoaded = true
            case .store(.setCompletedTodayTodos(let todos, let interval)):
                guard state.todayInterval == interval else { break }
                state.completedTodayTodos = todos
                state.isCompletedTodayDataLoaded = true
            case .store(.setCategories(let categories)):
                state.categories = categories
                let visibleCategoryIDs = Set(state.visibleCategories.map(\.id))
                if let categoryID = state.selectedCategoryID,
                   !visibleCategoryIDs.contains(categoryID) {
                    state.selectedCategoryID = nil
                }
            case .store(.updateTodo(let item)):
                if item.isCompleted {
                    state.todos.removeAll { $0.id == item.id }
                    if Self.isDue(item, in: state.todayInterval) {
                        if let index = state.completedTodayTodos.firstIndex(where: { $0.id == item.id }) {
                            state.completedTodayTodos[index] = item
                        } else {
                            state.completedTodayTodos.append(item)
                        }
                    } else {
                        state.completedTodayTodos.removeAll { $0.id == item.id }
                    }
                } else {
                    state.completedTodayTodos.removeAll { $0.id == item.id }
                    if let index = state.todos.firstIndex(where: { $0.id == item.id }) {
                        state.todos[index] = item
                    } else {
                        state.todos.append(item)
                    }
                }
            case .store(.removeTodo(let todoId)):
                state.todos.removeAll { $0.id == todoId }
                state.completedTodayTodos.removeAll { $0.id == todoId }
            case .loading:
                break
            }

            return .none
        }
        .ifLet(\.$alert, action: \.alert)
        .ifLet(\.todoEditor, action: \.todoEditor) {
            TodoEditorFeature()
        }
    }
}

extension DependencyValues {
    var todayFetchTodosUseCase: FetchTodosUseCase {
        get { self[FetchTodosUseCaseKey.self] }
        set { self[FetchTodosUseCaseKey.self] = newValue }
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

private extension TodayFeature {
    func latestItem(id: String, state: State) -> TodayTodoItem? {
        state.todos.first { $0.id == id }
            ?? state.completedTodayTodos.first { $0.id == id }
    }

    func dismissTodoInspector(state: inout State) {
        state.isTodoInspectorPresented = false
        state.todoEditor = nil
        state.dismissesTodoInspectorAfterSaving = false
        state.todoIdToSelectAfterSaving = nil
    }

    func prepareTodayInterval(state: inout State, now: Date) -> DateInterval {
        let interval = Self.dayInterval(containing: now)
        guard state.todayInterval != interval else { return interval }
        state.todayInterval = interval
        state.completedTodayTodos = []
        state.isCompletedTodayDataLoaded = false
        return interval
    }

    func fetchTodosEffect(
        interval: DateInterval,
        showsIndicator: Bool = true
    ) -> Effect<Action> {
        .run { [fetchTodosUseCase] send in
            if showsIndicator {
                await send(.loading(.begin(target: .default, mode: .delayed)))
            }
            do {
                async let todosWithDueDatePage = fetchTodosUseCase.execute(
                    TodoQuery(
                        completionFilter: .incomplete,
                        dueDateFilter: .withDueDate,
                        sortTarget: .dueDate,
                        sortOrder: .oldest,
                        pageSize: Self.pageSize,
                        fetchAllPages: true
                    ),
                    cursor: nil
                )
                async let todosWithoutDueDatePage = fetchTodosUseCase.execute(
                    TodoQuery(
                        completionFilter: .incomplete,
                        dueDateFilter: .withoutDueDate,
                        sortTarget: .updatedAt,
                        sortOrder: .latest,
                        pageSize: Self.pageSize,
                        fetchAllPages: true
                    ),
                    cursor: nil
                )
                async let completedTodayTodosPage = fetchTodosUseCase.execute(
                    Self.completedTodayQuery(interval: interval),
                    cursor: nil
                )
                let todosWithDueDate = try await todosWithDueDatePage.items.compactMap(TodayTodoItem.init(from:))
                let todosWithoutDueDate = try await todosWithoutDueDatePage.items.compactMap(TodayTodoItem.init(from:))
                let completedTodayTodos = try await completedTodayTodosPage.items.compactMap(TodayTodoItem.init(from:))
                await send(.store(.setTodos(
                    incomplete: todosWithDueDate + todosWithoutDueDate,
                    completedToday: completedTodayTodos,
                    interval: interval
                )))
                if showsIndicator {
                    await send(.loading(.end(target: .default, mode: .delayed)))
                }
            } catch {
                if showsIndicator {
                    await send(.loading(.end(target: .default, mode: .delayed)))
                }
                await send(.store(.setAlert))
            }
        }
    }

    func fetchCompletedTodayTodosEffect(interval: DateInterval) -> Effect<Action> {
        .run { [fetchTodosUseCase] send in
            do {
                let page = try await fetchTodosUseCase.execute(
                    Self.completedTodayQuery(interval: interval),
                    cursor: nil
                )
                let todos = page.items.compactMap(TodayTodoItem.init(from:))
                await send(.store(.setCompletedTodayTodos(todos, interval: interval)))
            } catch {
                await send(.store(.setAlert))
            }
        }
    }

    func fetchCategoriesEffect() -> Effect<Action> {
        .run { [fetchCategoryPreferencesUseCase] send in
            do {
                let preferences = try await fetchCategoryPreferencesUseCase.execute()
                await send(.store(.setCategories(preferences.map(TodoCategoryItem.init(from:)))))
            } catch {
                await send(.store(.setAlert))
            }
        }
    }

    static func completedTodayQuery(interval: DateInterval) -> TodoQuery {
        TodoQuery(
            completionFilter: .completed,
            dueDateFilter: .withDueDate,
            sortDateFrom: interval.start,
            sortDateTo: interval.end,
            sortTarget: .dueDate,
            sortOrder: .oldest,
            pageSize: Self.pageSize,
            fetchAllPages: true
        )
    }

    func completeTodoEffect(_ item: TodayTodoItem) -> Effect<Action> {
        .run { [fetchTodoByIdUseCase, upsertTodoUseCase, trackAnalyticsEventUseCase, now] send in
            await send(.loading(.begin(target: .default, mode: .delayed)))
            do {
                var todo = try await fetchTodoByIdUseCase.execute(item.id)
                todo.isCompleted = true
                todo.completedAt = now
                todo.updatedAt = now
                try await upsertTodoUseCase.execute(todo)
                trackAnalyticsEventUseCase.execute(.todoComplete)
                guard let item = TodayTodoItem(from: todo) else {
                    await send(.loading(.end(target: .default, mode: .delayed)))
                    await send(.store(.setAlert))
                    return
                }
                await send(.store(.updateTodo(item)))
                await send(.loading(.end(target: .default, mode: .delayed)))
            } catch {
                await send(.loading(.end(target: .default, mode: .delayed)))
                await send(.store(.setAlert))
            }
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
