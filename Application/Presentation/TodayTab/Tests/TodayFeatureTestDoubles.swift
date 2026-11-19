//
//  TodayFeatureTestDoubles.swift
//  TodayTabTests
//
//  Created by opfic on 6/14/26.
//

import Foundation
import PresentationShared
import Domain
@testable import TodayTab

enum TodayTestError: Error {
    case failure
}

enum TodayTestTodoScope: Hashable, CaseIterable {
    case remaining
    case important
}

enum TodayTestSectionCategory: Hashable {
    case overdue
    case today
    case upcoming
    case later
    case unscheduled
}

struct TodayDisplayedSection: Equatable {
    let category: TodayTestSectionCategory
    let itemIds: [String]
}

@MainActor
protocol TodayStateDriving {
    var todos: [TodayTodoItem] { get }
    var completedTodayTodos: [TodayTodoItem] { get }
    var todayTodos: [TodayTodoItem] { get }
    var todayAchievement: TodayFeature.TodayAchievement? { get }
    var todayInterval: DateInterval { get }
    var isTodayDataLoaded: Bool { get }
    var selectedTodoScope: TodayTestTodoScope { get }
    var selectedCategoryID: String? { get }
    var isCategoryFilterPresented: Bool { get }
    var isTodoInspectorPresented: Bool { get }
    var todoInfoTitle: String? { get }
    var visibleCategoryIDs: [String] { get }
    var showAlert: Bool { get }
    var isLoading: Bool { get }
    var displayedSections: [TodayDisplayedSection] { get }
    var summaryCounts: [TodayTestTodoScope: Int] { get }

    func fetchData() async
    func checkCurrentDate(_ date: Date) async
    func setTodoScope(_ scope: TodayTestTodoScope) async
    func setCategory(_ categoryID: String?) async
    func setCategoryFilterPresented(_ isPresented: Bool) async
    func completeTodo(_ item: TodayTodoItem) async
    func showTodoInspector(_ item: TodayTodoItem) async
    func setTodoInspectorPresented(_ isPresented: Bool) async
    func receiveTodoInfoSaved(_ todo: Todo) async
}

@MainActor
struct TodayStoreTestAdapter: TodayStateDriving {
    private let store: TestStoreOf<TodayFeature>

    var todos: [TodayTodoItem] { store.state.todos }
    var completedTodayTodos: [TodayTodoItem] { store.state.completedTodayTodos }
    var todayTodos: [TodayTodoItem] { store.state.todayTodos }
    var todayAchievement: TodayFeature.TodayAchievement? { store.state.todayAchievement }
    var todayInterval: DateInterval { store.state.todayInterval }
    var isTodayDataLoaded: Bool { store.state.isTodayDataLoaded }
    var selectedTodoScope: TodayTestTodoScope { store.state.selectedTodoScope.testValue }
    var selectedCategoryID: String? { store.state.selectedCategoryID }
    var isCategoryFilterPresented: Bool { store.state.isCategoryFilterPresented }
    var isTodoInspectorPresented: Bool { store.state.isTodoInspectorPresented }
    var todoInfoTitle: String? { store.state.todoInfo?.editor?.title }
    var selectedTodoId: String? { store.state.selectedTodoId }
    var detailPaneRevision: Int { store.state.detailPaneRevision }
    var visibleCategoryIDs: [String] { store.state.visibleCategories.map(\.id) }
    var showAlert: Bool { store.state.alert != nil }
    var isLoading: Bool { store.state.isLoading }
    var displayedSections: [TodayDisplayedSection] { store.state.sections.map(\.testValue) }
    var summaryCounts: [TodayTestTodoScope: Int] {
        Dictionary(
            uniqueKeysWithValues: store.state.summaryCounts.map { key, value in
                (key.testValue, value)
            }
        )
    }

    init(
        fetchUseCase: FetchTodosUseCase = TodayFetchTodosUseCaseSpy(),
        fetchCategoryPreferencesUseCase: FetchTodoCategoryPreferencesUseCase
            = TodayFetchCategoryPreferencesUseCaseSpy(),
        fetchTodoByIdUseCase: FetchTodoByIdUseCase = TodayFetchTodoByIdUseCaseSpy(),
        upsertUseCase: UpsertTodoUseCase = TodayUpsertTodoUseCaseSpy(),
        trackAnalyticsEventUseCase: TrackAnalyticsEventUseCase = TodayTrackAnalyticsEventUseCaseSpy(),
        now: Date = Date(),
        configureDependencies: ((inout DependencyValues) -> Void)? = nil
    ) {
        store = TestStore(initialState: TodayFeature.State(now: now)) {
            TodayFeature()
        } withDependencies: {
            $0.todayFetchTodosUseCase = fetchUseCase
            $0.fetchTodoCategoryPreferencesUseCase = fetchCategoryPreferencesUseCase
            $0.fetchTodoByIdUseCase = fetchTodoByIdUseCase
            $0.upsertTodoUseCase = upsertUseCase
            $0.trackAnalyticsEventUseCase = trackAnalyticsEventUseCase
            $0.date.now = now
            $0.continuousClock = ContinuousClock()
            configureDependencies?(&$0)
        }
        store.exhaustivity = .off(showSkippedAssertions: false)
    }

    func fetchData() async {
        await store.send(.fetchData)
        await drainReceivedActions()
    }

    func checkCurrentDate(_ date: Date) async {
        await store.send(.checkCurrentDate(date))
        await drainReceivedActions()
    }

    func receiveCompletedTodayTodos(
        _ todos: [TodayTodoItem],
        interval: DateInterval
    ) async {
        await store.send(.store(.setCompletedTodayTodos(todos, interval: interval)))
    }

    func receiveTodos(
        incomplete: [TodayTodoItem],
        completedToday: [TodayTodoItem],
        interval: DateInterval
    ) async {
        await store.send(.store(.setTodos(
            incomplete: incomplete,
            completedToday: completedToday,
            interval: interval
        )))
    }

    func receiveUpdatedTodo(_ item: TodayTodoItem) async {
        await store.send(.store(.updateTodo(item)))
    }

    func receiveDetailTodo(_ item: TodayTodoItem) async {
        await store.send(.detailTodoUpdated(item))
    }

    func setTodoScope(_ scope: TodayTestTodoScope) async {
        await store.send(.setTodoScope(scope.featureValue))
    }

    func setCategory(_ categoryID: String?) async {
        await store.send(.setCategory(categoryID))
    }

    func setCategoryFilterPresented(_ isPresented: Bool) async {
        await store.send(.binding(.set(\.isCategoryFilterPresented, isPresented)))
    }

    func completeTodo(_ item: TodayTodoItem) async {
        await store.send(.completeTodo(item))
        await drainReceivedActions()
    }

    func showTodoInspector(_ item: TodayTodoItem) async {
        await store.send(.showTodoInspector(item))
        await drainReceivedActions()
    }

    func setTodoInspectorPresented(_ isPresented: Bool) async {
        await store.send(.binding(.set(\.isTodoInspectorPresented, isPresented)))
    }

    func selectTodo(_ id: String) async {
        await store.send(.binding(.set(\.selectedTodoId, id)))
    }

    func setTodoInfoPinned(_ isPinned: Bool) async {
        await store.send(.todoInfo(.editor(.binding(.set(\.isPinned, isPinned)))))
        await drainReceivedActions()
    }

    func moveTodoInspectorToSideBar() async {
        await store.send(.moveTodoInspectorToSideBar)
        await drainReceivedActions()
    }

    func receiveTodoInfoSaved(_ todo: Todo) async {
        await store.send(.todoInfo(.editor(.updateSucceeded(todo))))
        await drainReceivedActions()
    }

    func receiveTodoInfoSaveFailed() async {
        await store.send(.todoInfo(.editor(.saveFailed)))
    }

    private func drainReceivedActions() async {
        for _ in 0..<10 {
            await store.skipReceivedActions(strict: false)
        }
    }
}

private extension TodayTestTodoScope {
    var featureValue: TodayFeature.TodoScope {
        switch self {
        case .remaining: .remaining
        case .important: .important
        }
    }
}

private extension TodayFeature.TodoScope {
    var testValue: TodayTestTodoScope {
        switch self {
        case .remaining: .remaining
        case .important: .important
        }
    }
}

private extension TodayFeature.SectionCategory {
    var testValue: TodayTestSectionCategory {
        switch self {
        case .overdue: .overdue
        case .today: .today
        case .upcoming: .upcoming
        case .later: .later
        case .unscheduled: .unscheduled
        }
    }
}

private extension TodayFeature.SectionContent {
    var testValue: TodayDisplayedSection {
        TodayDisplayedSection(
            category: category.testValue,
            itemIds: items.map(\.id)
        )
    }
}
