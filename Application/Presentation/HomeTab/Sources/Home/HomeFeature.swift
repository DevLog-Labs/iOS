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
    // 홈 내비게이션에 쌓는 카테고리 목록과 검색
    @Reducer
    enum Path {
        case category(TodoListFeature)
        case search(SearchFeature)
    }

    @ObservableState
    struct State: Equatable {
        @Presents var alert: AlertState<Action.Alert>?
        @Presents var categoryManage: CategoryManageFeature.State?
        @Presents var goalCreate: GoalCreateFeature.State?
        // 넓은 창의 홈 자리와 좁은 창의 내비게이션이 같은 상태를 그려 창 폭이 바뀌어도 작성 중인 기록 유지
        @Presents var goalDetail: GoalDetailFeature.State?
        @Presents var fullScreenCover: FullScreenCoverState?
        var path = StackState<Path.State>()
        // 작성 중인 새 개발 목표나 수정 중인 개발 목표를 버릴지 묻는 동안 미뤄 둔 동작
        var actionAfterGoalDiscard: Action?
        var showContentPicker = false
        // 사이드바가 있는 창, 사이드바 요청 처리와 사이드바 위치에 사용
        var usesDesktopLayout = false
        var developmentGoalItems = [DevelopmentGoalItem]()
        var hasDevelopmentGoalsLoaded = false
        var hasDevelopmentGoalsLoadFailure = false
        var preferences = [TodoCategoryItem]()
        var isTodoCategoryExpanded = false
        var isNetworkConnected = true
        var selectedTodoCategory: TodoCategory?
        // 홈 제목 줄 아래 보이는 높이, 새로 만들기 팝오버가 화면 밖으로 넘치지 않게 사용
        var visibleHeight = CGFloat.infinity
        // 새로 만들기 시트 목록 높이, 시트를 내용 높이에 맞추는 데 사용
        var contentPickerHeight = CGFloat.zero
        var loading = LoadingFeature.State()

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

        // 사이드바에서 고른 채로 표시할 위치
        var sideBarLocation: SideBarLocation {
            if let goalDetail {
                return .developmentGoal(goalDetail.goalId)
            }
            if usesDesktopLayout && categoryManage != nil {
                return .todoCategoryManagement
            }
            if case .search? = path.last {
                return .search
            }
            if case .category(let list)? = path.first {
                return .todoCategory(list.category.storageValue)
            }
            return .home
        }

        // 사이드바 Todo, 개발 목표 묶음의 하위 항목
        var sideBarContent: SideBarContent {
            SideBarContent(
                todoCategories: preferences.filter(\.isVisible),
                developmentGoals: developmentGoalItems.map { SideBarGoal(id: $0.id, title: $0.goal.title) }
            )
        }

        // 홈 루트에 띄운 화면은 한 번에 하나만 표시
        mutating func closePresentations() {
            categoryManage = nil
            goalCreate = nil
            goalDetail = nil
            showContentPicker = false
        }
    }

    enum Action: BindableAction, Equatable {
        case alert(PresentationAction<Alert>)
        case categoryManage(PresentationAction<CategoryManageFeature.Action>)
        case goalCreate(PresentationAction<GoalCreateFeature.Action>)
        case goalDetail(PresentationAction<GoalDetailFeature.Action>)
        case fullScreenCover(PresentationAction<FullScreenCover>)
        case path(StackActionOf<Path>)
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
            case tapSearch
            case sideBarRequested(SideBarRequest)
        }

        enum StoreAction: Equatable {
            case networkStatusChanged(Bool)
            case setPresentation(Presentation, Bool)
            case setAlert(isPresented: Bool)
            case developmentGoalsLoaded([DevelopmentGoalItem])
            case developmentGoalsLoadFailed
            case setTodoCategory([TodoCategoryItem])
        }
    }

    @ObservableState
    struct FullScreenCoverState: Equatable {
        var destination: Destination
        var todoEditor: TodoEditorFeature.State?

        enum Destination: Equatable {
            case todoEditor
        }

        static func todoEditor(_ category: TodoCategory) -> Self {
            Self(
                destination: .todoEditor,
                todoEditor: TodoEditorFeature.State(category: category)
            )
        }
    }

    @CasePathable
    enum FullScreenCover: Equatable {
        case todoEditor(TodoEditorFeature.Action)
    }

    enum Presentation: Equatable {
        case todoEditor
        case contentPicker
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
    @Dependency(\.homeFetchRecentSearchQueriesUseCase) var fetchRecentSearchQueriesUseCase
    @Dependency(\.homeNetworkConnectivityUseCase) var networkConnectivityUseCase
    @Dependency(\.trackAnalyticsEventUseCase) var trackAnalyticsEventUseCase
    @Dependency(\.continuousClock) var clock

    var body: some ReducerOf<Self> {
        Scope(state: \.loading, action: \.loading) {
            LoadingFeature()
        }
        BindingReducer()
        Reduce { state, action in
            // 새 개발 목표나 개발 목표 수정 칸이 열린 동안 홈 루트에 띄운 화면을 바꾸는 동작
            if let goal = state.goalCreate ?? state.goalDetail?.goalEdit {
                switch action {
                case .view(.tapCreateDevelopmentGoal),
                     .view(.tapDevelopmentGoal),
                     .view(.tapManageTodoCategory),
                     .view(.tapTodoCategory),
                     .store(.setPresentation(.contentPicker, true)):
                    // 저장하는 동안 화면을 바꾸면 저장이 취소되어 막음
                    if goal.isSaving {
                        return .none
                    }
                    // 작성 중인 내용이 있으면 버릴지 물은 뒤 고른 동작 실행
                    if goal.hasDraft {
                        state.actionAfterGoalDiscard = action
                        state.alert = Self.discardGoalDraftAlertState(isEditing: goal.goal != nil)
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
                // 개발 목표 칸에서 바꾼 상태와 기록은 수정을 버리고 칸을 닫아도 홈과 사이드바 목록에 반영
                let refreshesDevelopmentGoals = state.goalDetail != nil
                state.closePresentations()
                return refreshesDevelopmentGoals ? .merge(.send(action), .send(.view(.fetchData))) : .send(action)
            case .alert(.dismiss):
                state.actionAfterGoalDiscard = nil
            case .fullScreenCover(.presented(.todoEditor(.delegate(.created)))):
                return .send(.view(.todoEditorCreated))
            case .fullScreenCover(.dismiss):
                state.fullScreenCover = nil
                state.selectedTodoCategory = nil
            case .fullScreenCover:
                break
            case .categoryManage(.presented(.delegate(.changed(let preferences)))):
                // 카테고리 관리는 시트와 칸 모두 고친 값을 바로 저장
                state.preferences = preferences
                return delayedTodoCategoryPreferencesUpdateEffect(preferences)
            case .categoryManage:
                break
            case .goalCreate(.presented(.delegate(.saved))):
                state.goalCreate = nil
                return .send(.view(.fetchData))
            case .goalCreate(.presented(.delegate(.close))):
                return .send(.goalCreate(.dismiss))
            // 개발 목표 화면을 닫으면 바꾼 목표와 기록을 홈과 사이드바 목록에 반영하고, 이미 닫힌 뒤 늦게 온 닫힘은 다시 불러오지 않음
            case .goalCreate(.dismiss):
                guard state.goalCreate != nil else { break }
                return .send(.view(.fetchData))
            case .goalCreate:
                break
            // 개발 목표 칸에서 고친 제목을 사이드바와 홈 목록에 반영
            case .goalDetail(.presented(.delegate(.goalUpdated))):
                return .send(.view(.fetchData))
            case .goalDetail(.dismiss):
                guard state.goalDetail != nil else { break }
                return .send(.view(.fetchData))
            case .goalDetail:
                break
            case .path:
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
        .ifLet(\.$categoryManage, action: \.categoryManage) {
            CategoryManageFeature()
        }
        .ifLet(\.$goalCreate, action: \.goalCreate) {
            GoalCreateFeature()
        }
        .ifLet(\.$goalDetail, action: \.goalDetail) {
            GoalDetailFeature()
        }
        .ifLet(\.$fullScreenCover, action: \.fullScreenCover) {
            FullScreenCoverFeature()
        }
        .forEach(\.path, action: \.path)
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
                state.showContentPicker = false
                return delayedDevelopmentGoalCreateEffect()
            }
            state.closePresentations()
            state.goalCreate = GoalCreateFeature.State()
        case .tapDevelopmentGoal(let goalID):
            state.closePresentations()
            state.goalDetail = GoalDetailFeature.State(goalId: goalID)
        case .tapManageTodoCategory:
            // 이미 연 카테고리 관리는 고르던 카테고리를 그대로 유지
            guard state.categoryManage == nil else { break }
            state.closePresentations()
            state.categoryManage = CategoryManageFeature.State(preferences: state.preferences)
        case .tapTodoCategoryExpansionButton:
            state.isTodoCategoryExpanded.toggle()
        case .tapTodoCategory(let category):
            state.selectedTodoCategory = category
            state.closePresentations()
            return delayedTodoEditorEffect()
        case .tapSearch:
            // 열 때마다 빈 입력칸으로 시작하고 최근 검색은 열 때 읽음
            state.path.append(.search(SearchFeature.State(recentQueries: fetchRecentSearchQueriesUseCase.execute())))
        case .sideBarRequested(let request):
            return sideBarRequested(request, state: &state)
        }

        return .none
    }

    func reduce(
        _ action: Action.StoreAction,
        state: inout State
    ) -> Effect<Action> {
        switch action {
        case .networkStatusChanged(let isConnected):
            state.isNetworkConnected = isConnected
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

    // 사이드바에서 보낸 이동과 작성 요청
    func sideBarRequested(_ request: SideBarRequest, state: inout State) -> Effect<Action> {
        // 이미 표시 중인 개발 목표를 다시 누르면 다시 열지 않고 쌓아 연 화면만 닫아 개발 목표 첫 화면 표시
        if case .open(.developmentGoal(let goalID)) = request.action, state.goalDetail?.goalId == goalID {
            return .send(.goalDetail(.presented(.view(.returnToGoal))))
        }
        let goal = state.goalCreate ?? state.goalDetail?.goalEdit
        // 작성 중인 새 개발 목표나 수정 중인 개발 목표가 있으면 칸을 닫기 전에 버릴지 물음
        // 버리면 칸을 닫은 뒤 같은 요청을 다시 처리
        if request.action != .createTodo, let goal, goal.hasDraft {
            // 저장하는 동안 칸을 바꾸면 저장이 취소되어 막음
            guard !goal.isSaving else { return .none }
            state.actionAfterGoalDiscard = .view(.sideBarRequested(request))
            state.alert = Self.discardGoalDraftAlertState(isEditing: goal.goal != nil)
            return .none
        }
        // 사이드바가 있으면 카테고리 관리, 새 개발 목표, 개발 목표를 시트 대신 칸으로 표시
        let showsPane = state.usesDesktopLayout
            && (state.categoryManage != nil || state.goalCreate != nil || state.goalDetail != nil)
        // 개발 목표 칸을 다른 화면으로 바꾸면 칸에서 바꾼 목표와 기록을 시트를 닫을 때처럼 홈과 사이드바 목록에 반영
        let refreshesDevelopmentGoals = showsPane && (state.goalCreate != nil || state.goalDetail != nil)
        // 새 Todo 작성으로 작성 중인 개발 목표를 버릴지 묻는 경우
        var asksGoalDiscard = false
        var effects = [Effect<Action>]()
        // 사이드바로 다른 곳을 열면 칸으로 표시하던 화면은 닫고, 저장하는 동안은 닫지 않음
        if showsPane, case .open = request.action, goal?.isSaving != true {
            state.closePresentations()
        }
        switch request.action {
        case .open(.home):
            state.path.removeAll()
        case .open(.todoCategory(let id)):
            guard let item = state.preferences.first(where: { $0.id == id }) else { break }
            // 같은 카테고리 목록만 쌓여 있으면 보던 목록을 그대로 둠
            if state.path.count == 1, case .category(let list)? = state.path.first, list.category == item.todoCategory {
                break
            }
            state.path = StackState([.category(TodoListFeature.State(category: item.todoCategory))])
        case .open(.developmentGoal(let goalID)):
            // 사이드바가 있으면 개발 목표를 홈 루트에 그려 위에 쌓인 목록을 비움
            if state.usesDesktopLayout {
                state.path.removeAll()
            }
            effects.append(.send(.view(.tapDevelopmentGoal(goalID))))
        case .createTodo:
            if case .category? = state.path.first, let id = state.path.ids.first {
                // 카테고리 목록이 보이면 그 목록이 자기 작성 버튼과 같은 방식으로 작성
                effects.append(.send(.path(.element(id: id, action: .category(.store(.setFullScreenCover(.editor)))))))
            } else if state.isNetworkConnected {
                // 홈 작성 버튼처럼 연결이 끊기면 열지 않고 쌓아 연 검색도 그대로 둠
                // 쌓아 연 검색은 내리고 홈 작성 버튼과 같은 방식으로 작성
                state.path.removeAll()
                asksGoalDiscard = goal.map { !$0.isSaving && $0.hasDraft } ?? false
                effects.append(.send(.store(.setPresentation(.contentPicker, true))))
            }
        case .manageTodoCategory:
            // 카테고리를 불러오기 전 빈 목록으로 저장하지 않도록 무시
            guard !state.preferences.isEmpty else { break }
            // 사이드바가 있으면 카테고리 관리 칸을 홈 루트에 그려 위에 쌓인 목록을 비움
            if state.usesDesktopLayout {
                state.path.removeAll()
            }
            effects.append(.send(.view(.tapManageTodoCategory)))
        case .open:
            break
        }
        // 버릴지 묻는 중이면 칸이 그대로라 다시 불러오지 않음
        if refreshesDevelopmentGoals && state.actionAfterGoalDiscard == nil && !asksGoalDiscard {
            effects.append(.send(.view(.fetchData)))
        }
        return .concatenate(effects)
    }
}

extension HomeFeature.Path.State: Equatable {}
extension HomeFeature.Path.Action: Equatable {}
