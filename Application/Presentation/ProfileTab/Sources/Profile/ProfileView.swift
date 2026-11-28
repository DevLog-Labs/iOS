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
    @State private var store: StoreOf<ProfileFeature>
    @State private var router = NavigationRouter<ProfileRoute>()
    @Bindable private var settingsStore: StoreOf<SettingsFeature>
    private let isSelected: Bool
    private let windowEvent: TodoEditorWindowEvent

    public init(
        isSelected: Bool,
        settingsStore: StoreOf<SettingsFeature>,
        windowEvent: TodoEditorWindowEvent
    ) {
        let store = Store(initialState: ProfileFeature.State()) {
            ProfileFeature()
        }
        self._store = State(initialValue: store)
        self.settingsStore = settingsStore
        self.isSelected = isSelected
        self.windowEvent = windowEvent
    }

    public var body: some View {
        NavigationStack(path: path) {
            // 사이드바가 있는 창은 프로필을 창 전체 폭으로 두고 오른쪽 칸으로 옮긴 Todo가 있을 때만 두 칸으로 나눔
            PaneSplitView(splitsOnDesktop: store.showsDetailInPane && store.detail != nil) {
                ScrollView {
                    // 카드 없이 각 섹션이 페이지 여백을 가짐
                    LazyVStack(alignment: .leading, spacing: 0) {
                        UserInfoCard(store: store, isSelected: isSelected)
                        ActivityCard(store: store) { todoId in
                            store.send(.selectTodo(todoId, isEditable: false))
                        }
                        ProfileGoalSummary(store: store)
                        RecentActivityCard(store: store) { todoId in
                            store.send(.selectTodo(todoId, isEditable: true))
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
                if store.showsDetailInPane,
                   let detailStore = store.scope(state: \.detail, action: \.detail.presented) {
                    // 활동 기록 Todo는 고칠 수 없어 편집 결과를 받을 창 이벤트 없이 표시
                    TodoDetailView(
                        store: detailStore,
                        windowEvent: detailStore.showEditButton ? windowEvent : nil,
                        isPaneDetail: true,
                        onClose: usesDesktopLayout ? { store.send(.detail(.dismiss)) } : nil
                    )
                    .environment(\.showsPaneTitleBar, true)
                    // 칸 안에서 다른 Todo로 바꾸면 그 Todo를 조회
                    .id(detailStore.todoId)
                } else {
                    PanePlaceholder()
                }
            }
            .compositionRight(isActive: store.showsDetailInPane && store.detail != nil) {
                if let detail = store.detail {
                    TodoDetailSideBarView(
                        todoId: detail.todoId,
                        isEditable: detail.showEditButton,
                        windowEvent: windowEvent
                    )
                    .id(detail.todoId)
                }
            }
            // 좁은 창은 프로필 위에 쌓고, 사이드바가 있는 창은 상세 판이나 오른쪽 칸에 표시
            // 창 폭이 바뀌면 같은 상세 상태를 바뀐 자리에서 이어 그림
            .compositionDetail(
                item: $store.scope(state: \.detail, action: \.detail),
                inPane: store.showsDetailInPane,
                isActive: isSelected
            ) { detailStore in
                TodoDetailView(store: detailStore, windowEvent: detailStore.showEditButton ? windowEvent : nil)
            } panel: { detailStore in
                TodoDetailPanel(
                    store: detailStore,
                    location: Text("nav_profile", bundle: PresentationResources.bundle),
                    windowEvent: detailStore.showEditButton ? windowEvent : nil,
                    onMoveToPane: {
                        store.send(.binding(.set(\.showsDetailInPane, true)))
                    }
                )
            }
            .navigationDestination(
                for: ProfileRoute.self,
                interactivePop: {
                    switch $0 {
                    case .settings, .theme: true
                    default: false
                    }
                },
                destination: { destinationView($0).environment(\.showsPaneTitleBar, usesPaneLayout) }
            )
        }
        .desktopNavigationTransition()
        // 창 폭이 바뀌어 같은 설정을 다시 쌓거나 내릴 때 밀리는 효과 없이 바꿈
        .transaction(value: usesDesktopLayout) { $0.disablesAnimations = true }
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
                settingsStore.send(.openList)
            } label: {
                Image(systemName: "gearshape")
            }
            .id(windowControlsInset)
        }
    }

    @ViewBuilder
    private var titleBar: some View {
        if usesPaneLayout {
            PaneTitleBar(Text("nav_profile", bundle: PresentationResources.bundle)) {
                // 사이드바가 있는 창은 앱 화면과 분리한 설정 화면 표시
                Button {
                    settingsStore.send(.open)
                } label: {
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
                        Button {
                            settingsStore.send(.openList)
                        } label: {
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

    // 사이드바가 있는 창의 설정은 창 전체 설정 화면에 그리므로 쌓지 않음
    private var path: Binding<[ProfileRoute]> {
        Binding(
            get: {
                guard !usesDesktopLayout else { return router.path }
                switch settingsStore.screen {
                case .list:
                    return router.path + [.settings]
                case .detail:
                    return router.path + [.settings, settingsStore.selectedRoute]
                case nil:
                    return router.path
                }
            },
            set: { path in
                let settingsIndex = path.firstIndex(of: .settings) ?? path.endIndex
                router.path = Array(path[..<settingsIndex])
                // 쌓은 설정이 내려가며 늦게 보낸 빈 경로가 보던 항목을 지우지 않음
                guard !usesDesktopLayout else { return }
                switch path.endIndex - settingsIndex {
                case 0:
                    settingsStore.send(.binding(.set(\.screen, nil)))
                case 1:
                    settingsStore.send(.binding(.set(\.screen, .list)))
                default:
                    settingsStore.send(.binding(.set(\.screen, .detail)))
                }
            }
        )
    }

    @ViewBuilder
    private func destinationView(_ route: ProfileRoute) -> some View {
        switch route {
        case .settings:
            SettingsView(store: settingsStore) { route in
                settingsStore.send(.select(route))
            }
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
            AccountView(
                store: settingsStore.scope(state: \.account, action: \.account),
                settingsStore: settingsStore
            )
        case .settings, .information:
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

public enum ProfileRoute: Hashable, Identifiable {
    case settings
    case theme
    case pushNotification
    case account
    // Mac 설정 화면 목차에서만 고르는 앱 정보
    case information

    public var id: Self { self }
}
