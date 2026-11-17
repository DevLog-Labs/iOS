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
        @Presents var alert: AlertState<Action.Alert>?
        @Presents var sheet: SheetState?
        @Presents var fullScreenCover: FullScreenCoverState?
        // 작성 중인 새 개발 목표를 버릴지 묻는 동안 미뤄 둔 동작
        var actionAfterGoalDiscard: Action?
        // 새 개발 목표 칸을 닫은 뒤 다시 처리할 사이드바 요청
        var sideBarRequestAfterGoalDiscard: SideBarRequest?
        var developmentGoalItems = [DevelopmentGoalItem]()
        var hasDevelopmentGoalsLoaded = false
        var hasDevelopmentGoalsLoadFailure = false
        var preferences = [TodoCategoryItem]()
        var isTodoCategoryExpanded = false
        var isNetworkConnected = true
        var selectedTodoCategory: TodoCategory?
        var searchInset = CGFloat.zero
        // 홈 제목 줄 아래 보이는 높이, 새로 만들기 팝오버가 화면 밖으로 넘치지 않게 사용
        var visibleHeight = CGFloat.infinity
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
        case alert(PresentationAction<Alert>)
        case sheet(PresentationAction<Sheet>)
        case fullScreenCover(PresentationAction<FullScreenCover>)
        case binding(BindingAction<State>)
        case view(ViewAction)
        case store(StoreAction)
        case loading(LoadingFeature.Action)

        enum Alert: Equatable {
            case discardGoalDraft
        }

        enum ViewAction: Equatable {
            case startObserving
            case fetchData
            case todoEditorCreated
            case tapCreateDevelopmentGoal
            case tapDevelopmentGoal(String)
            case tapManageTodoCategory
            case tapTodoCategoryExpansionButton
            case tapTodoCategory(TodoCategory)
            case closeGoalCreateForSideBarRequest(SideBarRequest)
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
        case goalCreate(GoalCreateFeature.State)
        // 넓은 창의 칸과 시트가 같은 상태를 그려 창 폭이 바뀌어도 작성 중인 기록 유지
        case goalDetail(GoalDetailFeature.State)

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

        var goalCreateState: GoalCreateFeature.State? {
            get {
                guard case .goalCreate(let state) = self else { return nil }
                return state
            }
            set {
                guard let newValue else { return }
                self = .goalCreate(newValue)
            }
        }

        var goalDetailState: GoalDetailFeature.State? {
            get {
                guard case .goalDetail(let state) = self else { return nil }
                return state
            }
            set {
                guard let newValue else { return }
                self = .goalDetail(newValue)
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
        case goalCreate(GoalCreateFeature.Action)
        case goalDetail(GoalDetailFeature.Action)
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
            // 새 개발 목표 칸이 열린 동안 시트 자리를 바꾸는 동작
            if let goal = state.sheet?.goalCreateState {
                switch action {
                case .view(.tapCreateDevelopmentGoal),
                     .view(.tapDevelopmentGoal),
                     .view(.tapManageTodoCategory),
                     .view(.tapTodoCategory),
                     .view(.closeGoalCreateForSideBarRequest),
                     .store(.setSheet),
                     .store(.setPresentation(.contentPicker, true)):
                    // 저장하는 동안 시트 자리를 바꾸면 저장이 취소되어 막음
                    if goal.isSaving {
                        return .none
                    }
                    // 작성 중인 내용이 있으면 버릴지 물은 뒤 고른 동작 실행
                    if goal.hasDraft {
                        state.actionAfterGoalDiscard = action
                        state.alert = Self.discardGoalDraftAlertState
                        return .none
                    }
                default:
                    break
                }
            }

            switch action {
            case .alert(.presented(.discardGoalDraft)):
                guard let action = state.actionAfterGoalDiscard else { break }
                state.actionAfterGoalDiscard = nil
                state.sheet = nil
                return .send(action)
            case .alert(.dismiss):
                state.actionAfterGoalDiscard = nil
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
            case .sheet(.presented(.categoryManage(.delegate(.changed(let preferences))))):
                // 사이드바가 있는 창의 카테고리 관리 칸은 고친 값을 바로 저장
                state.preferences = preferences
                return delayedTodoCategoryPreferencesUpdateEffect(preferences)
            case .sheet(.presented(.categoryManage(.setSavesImmediately(true)))):
                // 시트에서 고친 값은 바로 저장하는 칸으로 바뀔 때 저장
                guard let preferences = state.sheet?.categoryManageState?.preferences,
                      preferences != state.preferences else { break }
                state.preferences = preferences
                return delayedTodoCategoryPreferencesUpdateEffect(preferences)
            case .sheet(.presented(.goalCreate(.delegate(.saved)))):
                state.sheet = nil
                return .send(.view(.fetchData))
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
            state.sheet = .goalCreate(GoalCreateFeature.State())
        case .tapDevelopmentGoal(let goalID):
            state.sheet = .goalDetail(GoalDetailFeature.State(goalId: goalID))
        case .tapManageTodoCategory:
            // 이미 연 카테고리 관리 칸은 바로 저장하는 상태를 그대로 유지
            guard state.sheet?.categoryManageState == nil else { break }
            state.sheet = .reorderTodo(CategoryManageFeature.State(preferences: state.preferences))
        case .tapTodoCategoryExpansionButton:
            state.isTodoCategoryExpanded.toggle()
        case .tapTodoCategory(let category):
            state.selectedTodoCategory = category
            state.sheet = nil
            return delayedTodoEditorEffect()
        case .closeGoalCreateForSideBarRequest(let request):
            state.sheet = nil
            state.sideBarRequestAfterGoalDiscard = request
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
        .ifCaseLet(\.goalCreate, action: \.goalCreate) {
            GoalCreateFeature()
        }
        .ifCaseLet(\.goalDetail, action: \.goalDetail) {
            GoalDetailFeature()
        }
    }
}
