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
    @Environment(\.windowControlsInset) private var windowControlsInset
    @Environment(\.readableContentWidth) private var readableContentWidth
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
    @Environment(\.deviceType) private var deviceType
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
            PaneSplitView {
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
                // Mac 제목 줄 구분선과 첫 카드 사이 여백
                .contentMargins(.top, isiOSAppOnMac ? 12 : 0, for: .scrollContent)
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
                switch store.selectedTodoRoute {
                case .activity(let todoId):
                    TodoDetailPane(
                        todoId: todoId,
                        showEditButton: false,
                        placeholder: Text("profile_select_detail", bundle: PresentationResources.bundle)
                    )
                case .recentTodo(let todoId):
                    TodoDetailPane(
                        todoId: todoId,
                        showEditButton: true,
                        placeholder: Text("profile_select_detail", bundle: PresentationResources.bundle),
                        windowEvent: windowEvent
                    )
                default:
                    TodoDetailPane(
                        todoId: nil,
                        showEditButton: false,
                        placeholder: Text("profile_select_detail", bundle: PresentationResources.bundle)
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
                destination: { destinationView($0).environment(\.showsPaneTitleBar, isiOSAppOnMac) }
            )
        }
        .navigationHistory(router)
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
            isPresented: $store.showQuarterPicker.activePresentation(when: isSelected)
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

        if isiOSAppOnMac {
            PaneTitleBar(Text("nav_profile", bundle: PresentationResources.bundle)) {
                settingsButton
            }
        } else {
            VStack(alignment: .leading) {
                HStack {
                    Text("nav_profile", bundle: PresentationResources.bundle)
                        .font(.largeTitle.bold())
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

    // Mac은 옆 칸에 상세를 열고 나머지 기기는 화면 이동
    private func showTodo(_ route: ProfileRoute) {
        if isiOSAppOnMac {
            store.send(.binding(.set(\.selectedTodoRoute, route)))
        } else {
            router.push(route)
        }
    }

    @ViewBuilder
    private func destinationView(_ route: ProfileRoute) -> some View {
        switch route {
        case .settings:
            SettingsView(store: settingsStore) { router.push($0) }
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
        case .theme:
            ThemeView(theme: $settingsStore.theme)
        case .pushNotification:
            PushNotificationSettingsView(store: Store(
                initialState: PushNotificationSettingsFeature.State()
            ) {
                PushNotificationSettingsFeature()
            })
        case .account:
            AccountView(store: Store(initialState: AccountFeature.State()) {
                AccountFeature()
            })
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

enum ProfileRoute: Hashable {
    case settings
    case activity(String)
    case recentTodo(String)
    case theme
    case pushNotification
    case account
}
