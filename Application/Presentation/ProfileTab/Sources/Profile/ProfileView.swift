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
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
    @Environment(\.windowControlsInset) private var windowControlsInset
    @Environment(\.readableContentWidth) private var readableContentWidth
    @Environment(\.usesDesktopLayout) private var usesDesktopLayout
    @Environment(\.usesPaneLayout) private var usesPaneLayout
    @Environment(\.deviceType) private var deviceType
    @Environment(\.sideBarRequest) private var sideBarRequest
    @State private var settingsStore: StoreOf<SettingsFeature>
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
        self._store = State(initialValue: store)
        self._settingsStore = State(initialValue: settingsStore)
        self.isSelected = isSelected
        self.windowEvent = windowEvent
    }

    public var body: some View {
        NavigationStack(path: $router.path) {
            // Mac은 프로필을 창 전체 폭으로 두고 오른쪽 칸으로 옮긴 Todo가 있을 때만 두 칸으로 나눔
            PaneSplitView(duoWidth: .medium, splitsOnDesktop: !isiOSAppOnMac || store.selectedTodoRoute != nil) {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        UserInfoCard(store: store, isSelected: isSelected)
                        ActivityCard(store: store) { todoId in
                            showTodo(.activity(todoId))
                        }
                        ProfileGoalSummary(store: store)
                        RecentActivityCard(store: store) { todoId in
                            showTodo(.recentTodo(todoId))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                    .frame(maxWidth: readableContentWidth)
                    .frame(maxWidth: .infinity)
                }
                // 칸 제목 줄 구분선과 첫 카드 사이 여백
                .contentMargins(.top, usesPaneLayout ? 12 : 0, for: .scrollContent)
                .safeAreaInset(edge: .top, spacing: 0) { titleBar }
                .refreshable { await store.send(.refresh).finish() }
                .duoToolbarVisibility()
                .toolbar {
                    if deviceType == .duo {
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
                }
                .background(Color.background)
            } detail: {
                let closeDetailPane: (() -> Void)? = isiOSAppOnMac
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
            .detailPanel(item: $store.panelTodoRoute.activePresentation(when: isSelected)) { route in
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
            case .open(.settings):
                router.replace(with: .settings)
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

    @ViewBuilder
    private var titleBar: some View {
        let settingsButton = Button {
            router.push(.settings)
        } label: {
            Image(systemName: "gearshape")
        }
        .topBarButtonStyle()

        if usesPaneLayout {
            PaneTitleBar(Text("nav_profile", bundle: PresentationResources.bundle)) {
                settingsButton
            }
        } else {
            VStack(alignment: .leading) {
                HStack {
                    Text("nav_profile", bundle: PresentationResources.bundle)
                        .font(.adaptive(.largeTitle).bold())
                    Spacer()
                    if deviceType != .duo {
                        settingsButton
                    }
                }
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: readableContentWidth)
            .padding(.top, windowControlsInset)
            .padding(.bottom, 8)
            .background(Color.background)
            .toolbarBackground(Color.background)
        }
    }

    // 칸 화면은 옆 칸에 상세를 열고 나머지는 화면 이동
    // Mac은 오른쪽 칸을 열지 않았으면 상세 판으로 열고 열었으면 오른쪽 칸 내용을 바꿈
    private func showTodo(_ route: ProfileRoute) {
        if isiOSAppOnMac && store.selectedTodoRoute == nil {
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
            // 사이드바가 있는 창은 설정 아래 화면으로 이동하고 Duo 펼침은 옆 칸에 표시
            let showsRoutePane = usesPaneLayout && !usesDesktopLayout

            PaneSplitView(duoWidth: .medium, splitsOnDesktop: false) {
                SettingsView(store: settingsStore) { route in
                    if showsRoutePane {
                        settingsStore.send(.binding(.set(\.selectedRoute, route)))
                    } else {
                        router.push(route)
                    }
                }
            } detail: {
                settingsPage(settingsStore.selectedRoute, isPaneDetail: true)
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
        case .theme, .pushNotification, .account:
            settingsPage(route, isPaneDetail: false)
        }
    }

    // 설정에서 고르는 아래 화면
    @ViewBuilder
    private func settingsPage(_ route: ProfileRoute, isPaneDetail: Bool) -> some View {
        switch route {
        case .theme:
            ThemeView(theme: $settingsStore.theme, isPaneDetail: isPaneDetail)
        case .pushNotification:
            PushNotificationSettingsView(store: Store(
                initialState: PushNotificationSettingsFeature.State()
            ) {
                PushNotificationSettingsFeature()
            }, isPaneDetail: isPaneDetail)
        case .account:
            AccountView(store: Store(initialState: AccountFeature.State()) {
                AccountFeature()
            }, isPaneDetail: isPaneDetail)
        case .settings, .activity, .recentTodo:
            EmptyView()
        }
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
