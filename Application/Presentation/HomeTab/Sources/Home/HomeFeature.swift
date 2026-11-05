//
//  HomeFeature.swift
//  HomeTab
//
//  Created by opfic on 6/14/26.
//

import Domain
import Foundation
import PresentationShared

@Reducer
struct HomeFeature {
    @ObservableState
    struct State: Equatable {
        @Presents var alert: AlertState<Never>?
        @Presents var sheet: SheetState?
        @Presents var fullScreenCover: FullScreenCoverState?
        var developmentGoalItems = [DevelopmentGoalItem]()
        var hasDevelopmentGoalsLoaded = false
        var hasDevelopmentGoalsLoadFailure = false
        var preferences = [TodoCategoryItem]()
        var isTodoCategoryExpanded = false
        var isNetworkConnected = true
        var selectedTodoCategory: TodoCategory?
        var searchInset = CGFloat.zero
        var loading = LoadingFeature.State()

        var showContentPicker: Bool {
            if case .contentPicker? = sheet { return true }
            return false
        }

        var showTodoEditor: Bool { fullScreenCover?.todoEditor != nil }

        var todoEditorCategory: TodoCategory? {
            fullScreenCover?.todoEditor?.category.todoCategory
        }

        var isPreferencesLoading: Bool {
            loading.visibleTargets.contains(LoadingTarget.preferences.target)
        }

        var isDevelopmentGoalsLoading: Bool {
            loading.visibleTargets.contains(LoadingTarget.developmentGoals.target)
        }

    }

    enum Action: BindableAction, Equatable {
        case alert(PresentationAction<Never>)
        case sheet(PresentationAction<Sheet>)
        case fullScreenCover(PresentationAction<FullScreenCover>)
        case binding(BindingAction<State>)
        case view(ViewAction)
        case store(StoreAction)
        case loading(LoadingFeature.Action)

        enum ViewAction: Equatable {
            case startObserving
            case fetchData
            case todoEditorCreated
            case tapCreateDevelopmentGoal
            case tapDevelopmentGoal(String)
            case tapManageTodoCategory
            case tapTodoCategoryExpansionButton
            case tapTodoCategory(TodoCategory)
        }

        enum StoreAction: Equatable {
            case networkStatusChanged(Bool)
            case setSheet(SheetState?)
            case setPresentation(Presentation, Bool)
            case setAlert(isPresented: Bool)
            case developmentGoalsLoaded([DevelopmentGoalItem])
            case developmentGoalsLoadFailed
            case setTodoCategory([TodoCategoryItem])
        }
    }

    @ObservableState
    @CasePathable
    enum SheetState: Equatable {
        case reorderTodo(CategoryManageFeature.State)
        case contentPicker
        case goalCreate
        case goalDetail(String)

        var categoryManageState: CategoryManageFeature.State? {
            get {
                guard case .reorderTodo(let state) = self else { return nil }
                return state
            }
            set {
                guard let newValue else { return }
                self = .reorderTodo(newValue)
            }
        }

        var isDevelopmentGoalPresentation: Bool {
            switch self {
            case .goalCreate, .goalDetail:
                true
            case .reorderTodo, .contentPicker:
                false
            }
        }
    }

    @CasePathable
    enum Sheet: Equatable {
        case tapCloseButton
        case categoryManage(CategoryManageFeature.Action)
    }

    @ObservableState
    struct FullScreenCoverState: Equatable {
        var destination: Destination
        var todoEditor: TodoEditorFeature.State?

        enum Destination: Equatable {
            case todoEditor
            case search
        }

        static func todoEditor(_ category: TodoCategory) -> Self {
            Self(
                destination: .todoEditor,
                todoEditor: TodoEditorFeature.State(category: category)
            )
        }

        static let search = Self(destination: .search)
    }

    @CasePathable
    enum FullScreenCover: Equatable {
        case todoEditor(TodoEditorFeature.Action)
    }

    enum Presentation: Equatable {
        case todoEditor
        case contentPicker
        case searchView
    }

    enum LoadingTarget: Hashable {
        case preferences
        case developmentGoals

        var target: LoadingFeature.Target {
            switch self {
            case .preferences:
                return LoadingFeature.Target("home.preferences")
            case .developmentGoals:
                return LoadingFeature.Target("home.developmentGoals")
            }
        }
    }

    @Dependency(\.fetchTodoCategoryPreferencesUseCase) var fetchPreferencesUseCase
    @Dependency(\.homeFetchDevelopmentGoalsUseCase) var fetchDevelopmentGoalsUseCase
    @Dependency(\.homeFetchRecentDevelopmentRecordUseCase) var recentRecordUseCase
    @Dependency(\.homeFetchTodosUseCase) var fetchTodosUseCase
    @Dependency(\.homeUpdateTodoCategoryPreferencesUseCase) var updatePreferencesUseCase
    @Dependency(\.homeNetworkConnectivityUseCase) var networkConnectivityUseCase
    @Dependency(\.trackAnalyticsEventUseCase) var trackAnalyticsEventUseCase
    @Dependency(\.continuousClock) var clock

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
                return .send(.view(.todoEditorCreated))
            case .fullScreenCover(.dismiss):
                state.fullScreenCover = nil
                state.selectedTodoCategory = nil
            case .fullScreenCover:
                break
            case .sheet(.dismiss):
                let refreshesDevelopmentGoals = state.sheet?.isDevelopmentGoalPresentation == true
                state.sheet = nil
                if refreshesDevelopmentGoals {
                    return .send(.view(.fetchData))
                }
            case .sheet(.presented(.tapCloseButton)):
                state.sheet = nil
            case .sheet(.presented(.categoryManage(.delegate(.done(let preferences))))):
                return orderTodoCategory(preferences, state: &state)
            case .sheet:
                break
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
        .ifLet(\.$sheet, action: \.sheet) {
            SheetFeature()
        }
        .ifLet(\.$fullScreenCover, action: \.fullScreenCover) {
            FullScreenCoverFeature()
        }
    }
}

private struct FullScreenCoverFeature: Reducer {
    typealias State = HomeFeature.FullScreenCoverState
    typealias Action = HomeFeature.FullScreenCover

    var body: some ReducerOf<Self> {
        EmptyReducer()
            .ifLet(\.todoEditor, action: \.todoEditor) {
                TodoEditorFeature()
            }
    }
}

private extension HomeFeature {
    func reduce(
        _ action: Action.ViewAction,
        state: inout State
    ) -> Effect<Action> {
        switch action {
        case .startObserving:
            return observeNetworkConnectivityEffect()
        case .fetchData:
            return .merge(
                fetchTodoCategoryPreferencesEffect(),
                fetchDevelopmentGoalsEffect()
            )
        case .todoEditorCreated:
            state.fullScreenCover = nil
            state.selectedTodoCategory = nil
            return .merge(
                trackTodoCreateEffect(),
                .send(.view(.fetchData))
            )
        case .tapCreateDevelopmentGoal:
            if state.showContentPicker {
                state.sheet = nil
                return delayedDevelopmentGoalCreateEffect()
            }
            state.sheet = .goalCreate
        case .tapDevelopmentGoal(let goalID):
            state.sheet = .goalDetail(goalID)
        case .tapManageTodoCategory:
            state.sheet = .reorderTodo(CategoryManageFeature.State(preferences: state.preferences))
        case .tapTodoCategoryExpansionButton:
            state.isTodoCategoryExpanded.toggle()
        case .tapTodoCategory(let category):
            state.selectedTodoCategory = category
            state.sheet = nil
            return delayedTodoEditorEffect()
        }

        return .none
    }

    func orderTodoCategory(
        _ preferences: [TodoCategoryItem],
        state: inout State
    ) -> Effect<Action> {
        state.preferences = preferences
        state.sheet = nil
        return updateTodoCategoryPreferencesEffect(preferences)
    }

    func reduce(
        _ action: Action.StoreAction,
        state: inout State
    ) -> Effect<Action> {
        switch action {
        case .networkStatusChanged(let isConnected):
            state.isNetworkConnected = isConnected
        case .setSheet(let sheet):
            state.sheet = sheet
        case .setPresentation(let presentation, let isPresented):
            Self.setPresentation(&state, presentation: presentation, isPresented: isPresented)
        case .setAlert(let isPresented):
            Self.setAlert(&state, isPresented: isPresented)
        case .developmentGoalsLoaded(let items):
            state.developmentGoalItems = items
            state.hasDevelopmentGoalsLoaded = true
            state.hasDevelopmentGoalsLoadFailure = false
        case .developmentGoalsLoadFailed:
            state.hasDevelopmentGoalsLoadFailure = true
        case .setTodoCategory(let preferences):
            state.preferences = preferences
        }

        return .none
    }
}

private struct SheetFeature: Reducer {
    typealias State = HomeFeature.SheetState
    typealias Action = HomeFeature.Sheet

    var body: some ReducerOf<Self> {
        EmptyReducer()
        .ifCaseLet(\.reorderTodo, action: \.categoryManage) {
            CategoryManageFeature()
        }
    }
}
