//
//  HomeFeatureTestSupport.swift
//  HomeTabTests
//
//  Created by opfic on 6/14/26.
//

import Testing
import Combine
import Core
import Domain
import PresentationShared
@testable import HomeTab
import Foundation

@MainActor
struct StoreTestAdapter {
    private let store: TestStoreOf<HomeFeature>
    private let clock: TestClock<Duration>

    var preferences: [TodoCategoryItem] { store.state.preferences }
    var isTodoCategoryExpanded: Bool { store.state.isTodoCategoryExpanded }
    var developmentGoalItems: [DevelopmentGoalItem] { store.state.developmentGoalItems }
    var hasDevelopmentGoalsLoaded: Bool { store.state.hasDevelopmentGoalsLoaded }
    var hasDevelopmentGoalsLoadFailure: Bool { store.state.hasDevelopmentGoalsLoadFailure }
    var isNetworkConnected: Bool { store.state.isNetworkConnected }
    var showContentPicker: Bool { store.state.showContentPicker }
    var showCategoryManage: Bool {
        store.state.sheet?.categoryManageState != nil
    }
    var showTodoEditor: Bool { store.state.showTodoEditor }
    var sheet: HomeFeature.SheetState? { store.state.sheet }

    init(
        fetchPreferencesUseCase: FetchTodoCategoryPreferencesUseCase = FetchTodoCategoryPreferencesUseCaseSpy(),
        updatePreferencesUseCase: UpdateTodoCategoryPreferencesUseCase = UpdateTodoCategoryPreferencesUseCaseSpy(),
        networkConnectivityUseCase: ObserveNetworkConnectivityUseCase = ObserveNetworkConnectivityUseCaseSpy(),
        fetchDevelopmentGoalsUseCase: FetchDevelopmentGoalsUseCase = FetchDevelopmentGoalsUseCaseSpy(),
        recentRecordUseCase: FetchRecentDevelopmentRecordUseCase = FetchRecentDevelopmentRecordUseCaseSpy(),
        fetchTodosUseCase: FetchTodosUseCase = HomeFetchTodosUseCaseSpy(),
        trackAnalyticsEventUseCase: TrackAnalyticsEventUseCase = TrackAnalyticsEventUseCaseSpy(),
        configureDependencies: ((inout DependencyValues) -> Void)? = nil
    ) {
        let clock = TestClock()
        self.clock = clock
        store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        } withDependencies: {
            $0.fetchTodoCategoryPreferencesUseCase = fetchPreferencesUseCase
            $0.homeUpdateTodoCategoryPreferencesUseCase = updatePreferencesUseCase
            $0.homeNetworkConnectivityUseCase = networkConnectivityUseCase
            $0.homeFetchDevelopmentGoalsUseCase = fetchDevelopmentGoalsUseCase
            $0.homeFetchRecentDevelopmentRecordUseCase = recentRecordUseCase
            $0.homeFetchTodosUseCase = fetchTodosUseCase
            $0.trackAnalyticsEventUseCase = trackAnalyticsEventUseCase
            $0.continuousClock = clock
            configureDependencies?(&$0)
        }
        store.exhaustivity = .off(showSkippedAssertions: false)
    }

    func startObserving() async {
        await store.send(.view(.startObserving))
        await drainReceivedActions()
    }

    func fetchData() async {
        await store.send(.view(.fetchData))
        await drainReceivedActions()
    }

    func setPresentation(_ presentation: HomeFeature.Presentation, _ isPresented: Bool) async {
        await store.send(.store(.setPresentation(presentation, isPresented)))
    }

    func tapTodoCategory(_ category: TodoCategory) async {
        await store.send(.view(.tapTodoCategory(category)))
        await clock.advance(by: .seconds(1))
        await settle()
    }

    func todoEditorCreated() async {
        await store.send(.view(.todoEditorCreated))
        await drainReceivedActions()
    }

    func tapManageTodoCategory() async {
        await store.send(.view(.tapManageTodoCategory))
        await drainReceivedActions()
    }

    func tapCreateDevelopmentGoal() async {
        await store.send(.view(.tapCreateDevelopmentGoal))
    }

    func tapDevelopmentGoal(_ goalID: String) async {
        await store.send(.view(.tapDevelopmentGoal(goalID)))
    }

    func setSheet(_ sheet: HomeFeature.SheetState?) async {
        await store.send(.store(.setSheet(sheet)))
    }

    func setCategoryManageSavesImmediately() async {
        await store.send(.sheet(.presented(.categoryManage(.setSavesImmediately))))
    }

    func changeCategoryPreferences(_ items: [TodoCategoryItem]) async {
        await store.send(.sheet(.presented(.categoryManage(.delegate(.changed(items))))))
    }

    func setGoalCreateSaving() async {
        await store.send(.sheet(.presented(.goalCreate(.binding(.set(\.isSaving, true))))))
    }

    func goalCreateSaved(_ goal: DevelopmentGoal) async {
        await store.send(.sheet(.presented(.goalCreate(.delegate(.saved(goal))))))
        await drainReceivedActions()
    }

    func advanceClock(by duration: Duration) async {
        await clock.advance(by: duration)
        await settle()
    }

    func dismissSheet() async {
        await store.send(.sheet(.dismiss))
        await drainReceivedActions()
    }

    func tapTodoCategoryExpansionButton() async {
        await store.send(.view(.tapTodoCategoryExpansionButton))
    }

    func orderTodoCategory(_ items: [TodoCategoryItem]) async {
        await store.send(.sheet(.presented(.categoryManage(.delegate(.done(items))))))
        await drainReceivedActions()
    }

    func drainReceivedActions() async {
        for _ in 0..<12 {
            await store.skipReceivedActions(strict: false)
        }
    }

    func settle() async {
        await Task.yield()
        await drainReceivedActions()
    }
}

final class TrackAnalyticsEventUseCaseSpy: TrackAnalyticsEventUseCase {
    private(set) var events = [AnalyticsEvent]()
    var hasTrackedTodoCreate: Bool {
        events.contains {
            guard case .todoCreate = $0 else { return false }
            return true
        }
    }

    func execute(_ event: AnalyticsEvent) {
        events.append(event)
    }
}
