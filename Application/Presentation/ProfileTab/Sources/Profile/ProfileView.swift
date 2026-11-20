//
//  ProfileView.swift
//  ProfileTab
//
//  Created by opfic on 5/7/25.
//

import SwiftUI
import Core
import Domain
import PresentationShared

public struct ProfileView: View {
    @Environment(\.usesDesktopLayout) private var usesDesktopLayout
    @Environment(\.windowControlsInset) private var windowControlsInset
    @Environment(\.readableContentWidth) private var readableContentWidth
    @Environment(\.usesPaneLayout) private var usesPaneLayout
    @Environment(\.deviceType) private var deviceType
    @Environment(\.sideBarRequest) private var sideBarRequest
    @Environment(\.presentSettings) private var presentSettings
    @State private var settingsStore: StoreOf<SettingsFeature>
    // 계정 화면에서 뒤로 가도 진행 중인 로그아웃, 회원 탈퇴가 취소되지 않게 프로필 화면이 보관
    @State private var accountStore: StoreOf<AccountFeature>
    @State private var store: StoreOf<ProfileFeature>
    @State private var router = NavigationRouter<ProfileRoute>()
    private let isSelected: Bool
    private let windowEvent: TodoEditorWindowEvent

    public init(
        isSelected: Bool,
        windowEvent: TodoEditorWindowEvent
    ) {
        let store = Store(initialState: ProfileFeature.State()) {
            ProfileFeature()
        }
        let settingsStore = Store(initialState: SettingsFeature.State()) {
            SettingsFeature()
        }
        let accountStore = Store(initialState: AccountFeature.State()) {
            AccountFeature()
        }
        self._store = State(initialValue: store)
        self._settingsStore = State(initialValue: settingsStore)
        self._accountStore = State(initialValue: accountStore)
        self.isSelected = isSelected
        self.windowEvent = windowEvent
    }

    public var body: some View {
        NavigationStack(path: $router.path) {
            // 사이드바가 있는 창은 프로필을 창 전체 폭으로 두고 오른쪽 칸으로 옮긴 Todo가 있을 때만 두 칸으로 나눔
            PaneSplitView(splitsOnDesktop: store.selectedTodoRoute != nil) {
                ScrollView {
                    // 카드 없이 각 섹션이 페이지 여백을 가짐
                    LazyVStack(alignment: .leading, spacing: 0) {
                        UserInfoCard(store: store, isSelected: isSelected)
                        ActivityCard(store: store) { todoId in
                            showTodo(.activity(todoId))
                        }
                        ProfileGoalSummary(store: store)
                        RecentActivityCard(store: store) { todoId in
                            showTodo(.recentTodo(todoId))
                        }
                    }
                    .padding(.bottom, 24)
                    .frame(maxWidth: readableContentWidth)
                    .frame(maxWidth: .infinity)
                }
                .safeAreaInset(edge: .top, spacing: 0) { titleBar }
                .refreshable { await store.send(.refresh).finish() }
                .duoToolbarVisibility()
                .toolbar {
                    if deviceType == .duo {
                        // 세로 막대 버튼을 리퀴드 글래스 묶음 없이 아이콘만 표시
                        duoToolbarItem
                            .sharedBackgroundHidden()
                    }
                }
                .background(Color.background)
            } detail: {
                let closeDetailPane: (() -> Void)? = usesDesktopLayout
                    ? { store.send(.binding(.set(\.selectedTodoRoute, nil))) } : nil

                switch store.selectedTodoRoute {
                case .activity(let todoId):
                    TodoDetailPane(todoId: todoId, showEditButton: false, onClose: closeDetailPane)
                case .recentTodo(let todoId):
                    TodoDetailPane(
                        todoId: todoId,
                        showEditButton: true,
                        windowEvent: windowEvent,
                        onClose: closeDetailPane
                    )
                default:
                    TodoDetailPane(todoId: nil, showEditButton: false)
                }
            }
            .detailSideBarTarget(store.selectedTodoRoute?.detailSideBarTarget)
            // 좁은 창으로 바뀌면 상세 판을 숨기고 넓어지면 다시 표시
            .detailPanel(item: $store.panelTodoRoute.activePresentation(when: isSelected && usesDesktopLayout)) { route in
                if case .todo(let todoId, let isEditable, _)? = route.detailSideBarTarget {
                    TodoDetailPanel(
                        todoId: todoId,
                        location: Text("nav_profile", bundle: PresentationResources.bundle),
                        isEditable: isEditable,
                        windowEvent: isEditable ? windowEvent : nil,
                        onMoveToPane: {
                            store.send(.binding(.set(\.panelTodoRoute, nil)))
                            store.send(.binding(.set(\.selectedTodoRoute, route)))
                        }
                    )
                }
            }
            .navigationDestination(
                for: ProfileRoute.self,
                interactivePop: {
                    switch $0 {
                    case .settings, .theme, .activity, .recentTodo: true
                    default: false
                    }
                },
                destination: { destinationView($0).environment(\.showsPaneTitleBar, usesPaneLayout) }
            )
        }
        .desktopNavigationTransition()
        // 사이드바 구조로 바뀌면 쌓아 연 Todo 상세는 내리고 같은 Todo를 옆 칸에 표시
        .closesPushedDetail {
            switch router.path.last {
            case .activity?, .recentTodo?:
                let route = router.path.removeLast()
                store.send(.binding(.set(\.selectedTodoRoute, route)))
            default:
                break
            }
        }
        // 사이드바가 있는 창으로 바뀌면 쌓아 연 설정은 내리고 창 전체 설정 화면으로 표시
        .onChange(of: usesDesktopLayout) { _, usesDesktopLayout in
            if usesDesktopLayout, router.root == .settings, let presentSettings {
                router.path = []
                // 다른 탭을 보던 중이면 쌓아 연 설정만 내리고 창 전체 설정 화면은 띄우지 않음
                if isSelected {
                    presentSettings()
                }
            }
        }
        // 설정 아래 화면도 사이드바에서는 설정으로 표시
        .preference(
            key: SideBarLocationPreferenceKey.self,
            value: router.root == .settings ? .settings : .profile
        )
        // 사이드바 요청으로 처음 여는 탭도 그 요청을 반영
        .onChange(of: sideBarRequest, initial: true) { _, request in
            switch request?.action {
            case .open(.profile):
                router.path = []
            default:
                break
            }
        }
        .onChange(of: isSelected, initial: true) { _, isSelected in
            if isSelected {
                store.send(.fetchData)
            }
        }
        .onAppear {
            store.send(.startObserving)
            settingsStore.send(.startObserving)
        }
        .prominentAlert(store, state: \.alert, action: \.alert)
        .prominentSheet(
            isPresented: $store.showQuarterPicker
                .hiddenInPane(usesPaneLayout)
                .activePresentation(when: isSelected)
        ) { QuarterPickerSheet(store: store) }
        .overlay {
            if store.isLoading {
                LoadingView()
            }
        }
    }

    private var duoToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            // 접힌 뒤 펼칠 때 레일 아이콘이 사라지는 현상 방지
            Button {
                router.push(.settings)
            } label: {
                Image(systemName: "gearshape")
            }
            .id(windowControlsInset)
        }
    }

    @ViewBuilder
    private var titleBar: some View {
        let openSettings = {
            // 사이드바가 있는 창은 앱 화면과 분리한 설정 화면 표시
            if let presentSettings {
                presentSettings()
            } else {
                router.push(.settings)
            }
        }

        if usesPaneLayout {
            PaneTitleBar(Text("nav_profile", bundle: PresentationResources.bundle)) {
                Button(action: openSettings) {
                    Image(systemName: "gearshape")
                }
                .topBarButtonStyle()
            }
        } else {
            VStack(alignment: .leading) {
                HStack(spacing: 0) {
                    Text("nav_profile", bundle: PresentationResources.bundle)
                        .font(.adaptive(.largeTitle).bold())
                    Spacer()
                    if deviceType != .duo {
                        // 리퀴드 글래스 없이 배경 없는 40pt 아이콘 버튼
                        Button(action: openSettings) {
                            Image(systemName: "gearshape")
                        }
                        .buttonStyle(ProfileTopBarIconButtonStyle())
                    }
                }
            }
            .padding(.leading, 16)
            .padding(.trailing, 8)
            .frame(maxWidth: readableContentWidth)
            .padding(.top, windowControlsInset)
            .padding(.bottom, 8)
            .background(Color.background)
            .toolbarBackground(Color.background)
        }
    }

    // 칸 화면은 옆 칸에 상세를 열고 나머지는 화면 이동
    // 사이드바가 있는 창은 오른쪽 칸을 열지 않았으면 상세 판으로 열고 열었으면 오른쪽 칸 내용을 바꿈
    private func showTodo(_ route: ProfileRoute) {
        if usesDesktopLayout && store.selectedTodoRoute == nil {
            store.send(.binding(.set(\.panelTodoRoute, route)))
        } else if usesPaneLayout {
            store.send(.binding(.set(\.selectedTodoRoute, route)))
        } else {
            router.push(route)
        }
    }

    @ViewBuilder
    private func destinationView(_ route: ProfileRoute) -> some View {
        switch route {
        case .settings:
            SettingsView(store: settingsStore) { route in
                router.push(route)
            }
        case .activity(let todoId):
            TodoDetailView(store: Store(
                initialState: TodoDetailFeature.State(todoId: todoId, showEditButton: false)
            ) {
                TodoDetailFeature()
            })
        case .recentTodo(let todoId):
            TodoDetailView(store: Store(
                initialState: TodoDetailFeature.State(todoId: todoId, showEditButton: true)
            ) {
                TodoDetailFeature()
            }, windowEvent: windowEvent)
        case .theme, .pushNotification, .account, .information:
            settingsPage(route)
        }
    }

    // 설정에서 고르는 아래 화면
    @ViewBuilder
    private func settingsPage(_ route: ProfileRoute) -> some View {
        switch route {
        case .theme:
            ThemeView(theme: $settingsStore.theme)
        case .pushNotification:
            PushNotificationSettingsView(store: Store(
                initialState: PushNotificationSettingsFeature.State()
            ) {
                PushNotificationSettingsFeature()
            })
        case .account:
            AccountView(store: accountStore, settingsStore: settingsStore)
        case .settings, .activity, .recentTodo, .information:
            EmptyView()
        }
    }
}

// 좁은 화면 위쪽 줄의 배경 없는 40pt 아이콘 버튼
private struct ProfileTopBarIconButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.adaptive(.title3).weight(.medium))
            .foregroundStyle(Color.label)
            .opacity(isEnabled && !configuration.isPressed ? 1 : 0.4)
            .frame(width: 40, height: 40)
            .contentShape(.rect)
    }
}

private struct ProfileGoalSummary: View {
    let store: StoreOf<ProfileFeature>

    var body: some View {
        GoalSummaryCard(
            goals: store.developmentGoals,
            isLoading: store.isDevelopmentGoalsLoading,
            hasLoaded: store.hasDevelopmentGoalsLoaded,
            hasLoadFailure: store.hasDevelopmentGoalsLoadFailure,
            onRetry: { store.send(.retryDevelopmentGoals) }
        )
    }
}

enum ProfileRoute: Hashable, Identifiable {
    case settings
    case activity(String)
    case recentTodo(String)
    case theme
    case pushNotification
    case account
    // Mac 설정 화면 목차에서만 고르는 앱 정보
    case information

    var id: Self { self }
}

private extension ProfileRoute {
    // 활동 기록 Todo는 고칠 수 없어 읽기 전용으로 표시
    var detailSideBarTarget: DetailSideBarTarget? {
        switch self {
        case .activity(let todoId): .todo(id: todoId, isEditable: false)
        case .recentTodo(let todoId): .todo(id: todoId, isEditable: true)
        default: nil
        }
    }
}
