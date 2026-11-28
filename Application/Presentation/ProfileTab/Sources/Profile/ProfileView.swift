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
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
    @State private var store: StoreOf<ProfileFeature>
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
        NavigationStack {
            // 사이드바가 있는 창은 프로필을 창 전체 폭으로 두고 오른쪽 칸으로 옮긴 Todo가 있을 때만 두 칸으로 나눔
            PaneSplitView {
                ScrollView {
                    // 카드 없이 각 섹션이 페이지 여백을 가짐
                    LazyVStack(alignment: .leading, spacing: 0) {
                        UserInfoCard(store: store, isSelected: isSelected)
                        ActivityCard(store: store) { todoId in
                            store.send(.selectTodo(todoId))
                        }
                        ProfileGoalSummary(store: store)
                        RecentActivityCard(store: store) { todoId in
                            store.send(.selectTodo(todoId))
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
                // 좁은 창은 프로필 위에 쌓고, 사이드바가 있는 창은 상세 판이나 오른쪽 칸에 표시
                // 창 폭이 바뀌면 같은 상세 상태를 바뀐 자리에서 이어 그림
                .compositionDetail(
                    item: $store.scope(state: \.detail, action: \.detail),
                    inPane: store.showsDetailInPane,
                    isActive: isSelected
                ) { detailStore, onClose in
                    // 프로필에서 연 Todo는 고칠 수 없어 편집 결과를 받을 창 이벤트 없이 표시
                    TodoDetailView(
                        store: detailStore,
                        windowEvent: nil,
                        isPaneDetail: onClose != nil,
                        onClose: onClose
                    )
                    // 칸 안에서 다른 Todo로 바꾸면 그 Todo를 조회
                    .id(detailStore.todoId)
                } panel: { detailStore in
                    TodoDetailPanel(
                        store: detailStore,
                        location: Text("nav_profile", bundle: PresentationResources.bundle),
                        windowEvent: nil,
                        onMoveToPane: {
                            store.send(.binding(.set(\.showsDetailInPane, true)))
                        }
                    )
                }
            }
            .compositionRight(isActive: store.showsDetailInPane && store.detail != nil) {
                if let detail = store.detail {
                    TodoDetailSideBarView(
                        todoId: detail.todoId,
                        isEditable: false,
                        windowEvent: nil
                    )
                    .id(detail.todoId)
                }
            }
            // 좁은 창은 설정 목록과 고른 항목 화면을 프로필 위에 쌓고, 사이드바가 있는 창은 창 전체 설정 화면에 그려 쌓지 않음
            .navigationDestination(
                isPresented: $settingsStore.isListPushed.hiddenInPane(usesDesktopLayout),
                interactivePop: true
            ) {
                SettingsView(store: settingsStore) { route in
                    settingsStore.send(.select(route))
                }
                .environment(\.showsPaneTitleBar, usesPaneLayout)
                .navigationDestination(
                    item: $settingsStore.pushedRoute.hiddenInPane(usesDesktopLayout),
                    interactivePop: settingsStore.pushedRoute == .theme
                ) { route in
                    settingsPage(route)
                        .environment(\.showsPaneTitleBar, usesPaneLayout)
                }
            }
        }
        .desktopNavigationTransition()
        // 창 폭이 바뀌어 같은 설정을 다시 쌓거나 내릴 때 밀리는 효과 없이 바꿈
        .transaction(value: usesDesktopLayout) { $0.disablesAnimations = true }
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
        // 좁은 창은 분기 선택을 시트로, 칸으로 나눈 화면은 분기 표시 옆 팝오버로 표시하고 Mac은 분기 표시 아래로 표시
        .compositionPicker(
            isPresented: $store.showQuarterPicker,
            isActive: isSelected,
            arrowEdge: isiOSAppOnMac ? .top : nil
        ) {
            QuarterPickerSheet(store: store)
        }
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
