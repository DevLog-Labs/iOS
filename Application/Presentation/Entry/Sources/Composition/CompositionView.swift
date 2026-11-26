//
//  CompositionView.swift
//  Entry
//
//  Created by opfic on 5/8/25.
//

import SwiftUI
import ProfileTab
import PresentationShared

struct CompositionView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
    @Environment(\.deviceType) private var deviceType
    @Binding var selectedTab: AppTab
    @State private var store: StoreOf<CompositionFeature>
    private let windowEvent: TodoEditorWindowEvent
    // 목록 칸과 상세 칸이 함께 들어가는 화면 영역 폭
    private let splitMinimumWidth = CGFloat(800)

    init(
        windowEvent: TodoEditorWindowEvent,
        selectedTab: Binding<AppTab>
    ) {
        @Dependency(\.fetchSideBarWidthUseCase) var fetchSideBarWidthUseCase
        var state = CompositionFeature.State()
        state.sideBarWidth = fetchSideBarWidthUseCase.execute().map { CGFloat($0) }
        self._store = State(initialValue: Store(initialState: state) {
            CompositionFeature()
        })
        self._selectedTab = selectedTab
        self.windowEvent = windowEvent
    }

    var body: some View {
        let showsSideBar = isiOSAppOnMac || deviceType != .duo && horizontalSizeClass == .regular
        let tabContentInset = horizontalSizeClass == .compact ? store.windowControlsInset : 0
        let readableContentWidth = showsSideBar ? store.readableContentWidth : .infinity
        // iPhone, Duo, 좁은 iPad 창은 시스템 탭 바 대신 직접 그린 탭 사용
        let usesCustomTabBar = deviceType != .ipad || horizontalSizeClass == .compact
        let isSystemTabBarHidden = showsSideBar || usesCustomTabBar
        let verticalBarWidth = deviceType == .duo
            ? max(store.verticalBarInsets.leading, store.verticalBarInsets.trailing) : 0
        // 시스템 탭 바처럼 키보드가 올라오면 키보드 뒤로 사라짐
        let showsTabBar = !showsSideBar && usesCustomTabBar && verticalBarWidth == 0 && !store.isKeyboardVisible
        // 사이드바가 있는 창 오른쪽 세부 정보 사이드바, 설정 화면에서는 표시하지 않음
        let showsDetailSideBar = showsSideBar
            && (store.sideBarLocations[selectedTab] ?? selectedTab.sideBarLocation) != .settings
        let sideBarIdealWidth = isiOSAppOnMac ? 220 * AdaptiveSize.boardScale : 250
        let tabBarInset = showsTabBar ? store.tabBarHeight : 0

        HStack(spacing: 0) {
            if showsSideBar && !store.isSideBarCollapsed {
                // 최소는 화살표와 아이콘만 보이는 폭, Mac 최대는 Orca 사이드바와 같은 폭
                TreeSideBar(selectedTab: $selectedTab, store: store)
                    .resizablePane(
                        width: store.sideBarWidth,
                        minimumWidth: isiOSAppOnMac ? 72 * AdaptiveSize.boardScale : 84,
                        idealWidth: sideBarIdealWidth,
                        maximumWidth: isiOSAppOnMac ? 500 * AdaptiveSize.boardScale : 320
                    ) { width in
                        store.send(.view(.sideBarResized(width)))
                    }
                    // 칸 자르기 밖이라 잘리지 않도록 바탕은 칸 바깥에서 아래쪽 안전 영역까지 채움
                    .background(Color.secondaryBackground, ignoresSafeAreaEdges: .bottom)
            }

            ZStack {
                // iPad는 시스템 탭 바를 쓰지 않아 Mac과 같이 구성
                // 넓은 창과 좁은 창을 오가도 탭 화면을 다시 만들지 않음
                if isiOSAppOnMac || deviceType == .ipad {
                    // 탭 전환 애니메이션 없이 한 번 연 탭을 유지하고 선택한 탭만 표시
                    // 사이드바 하위 항목은 홈 화면이 알려 주므로 홈은 처음부터 생성
                    ForEach(AppTab.allCases, id: \.self) { tab in
                        if store.openedTabs.contains(tab) || selectedTab == tab || tab == .home {
                            TabScreen(
                                store: store,
                                tab: tab,
                                isSelected: selectedTab == tab,
                                isTabBarHidden: isSystemTabBarHidden,
                                tabBarInset: tabBarInset,
                                usesPaneLayout: showsSideBar,
                                windowControlsInset: tabContentInset,
                                readableContentWidth: readableContentWidth,
                                windowEvent: windowEvent
                            )
                            .opacity(selectedTab == tab ? 1 : 0)
                            .allowsHitTesting(selectedTab == tab)
                        }
                    }
                } else {
                    TabView(selection: $selectedTab) {
                        Tab(
                            AppTab.home.title,
                            systemImage: AppTab.home.symbolName,
                            value: AppTab.home
                        ) {
                            TabScreen(
                                store: store,
                                tab: .home,
                                isSelected: selectedTab == .home,
                                isTabBarHidden: isSystemTabBarHidden,
                                tabBarInset: tabBarInset,
                                usesPaneLayout: showsSideBar,
                                windowControlsInset: tabContentInset,
                                readableContentWidth: readableContentWidth,
                                windowEvent: windowEvent
                            )
                        }
                        Tab(
                            AppTab.today.title,
                            systemImage: AppTab.today.symbolName,
                            value: AppTab.today
                        ) {
                            TabScreen(
                                store: store,
                                tab: .today,
                                isSelected: selectedTab == .today,
                                isTabBarHidden: isSystemTabBarHidden,
                                tabBarInset: tabBarInset,
                                usesPaneLayout: showsSideBar,
                                windowControlsInset: tabContentInset,
                                readableContentWidth: readableContentWidth,
                                windowEvent: windowEvent
                            )
                        }
                        Tab(
                            AppTab.notification.title,
                            systemImage: AppTab.notification.symbolName,
                            value: AppTab.notification
                        ) {
                            TabScreen(
                                store: store,
                                tab: .notification,
                                isSelected: selectedTab == .notification,
                                isTabBarHidden: isSystemTabBarHidden,
                                tabBarInset: tabBarInset,
                                usesPaneLayout: showsSideBar,
                                windowControlsInset: tabContentInset,
                                readableContentWidth: readableContentWidth,
                                windowEvent: windowEvent
                            )
                        }
                        .badge(store.unreadPushCount)
                        Tab(
                            AppTab.profile.title,
                            systemImage: AppTab.profile.symbolName,
                            value: AppTab.profile
                        ) {
                            TabScreen(
                                store: store,
                                tab: .profile,
                                isSelected: selectedTab == .profile,
                                isTabBarHidden: isSystemTabBarHidden,
                                tabBarInset: tabBarInset,
                                usesPaneLayout: showsSideBar,
                                windowControlsInset: tabContentInset,
                                readableContentWidth: readableContentWidth,
                                windowEvent: windowEvent
                            )
                        }
                    }
                }
            }
            .background {
                ReadableContentWidthReader { width in
                    store.send(.binding(.set(\.readableContentWidth, width)))
                }
            }
            // 접은 사이드바는 화면 칸 제목 줄의 버튼으로 다시 폄
            .environment(
                \.expandSideBar,
                store.isSideBarCollapsed ? { store.send(.binding(.set(\.isSideBarCollapsed, false))) } : nil
            )
            .environment(
                \.presentSettings,
                showsSideBar ? { store.send(.binding(.set(\.isSettingsPresented, true))) } : nil
            )
            // 닫힌 세부 정보 사이드바는 화면 칸 제목 줄의 버튼으로 엶
            .environment(
                \.showDetailSideBar,
                showsDetailSideBar && !store.isDetailSideBarPresented
                    ? { store.send(.binding(.set(\.isDetailSideBarPresented, true))) } : nil
            )
            .environment(\.isDetailSideBarPresented, showsDetailSideBar && store.isDetailSideBarPresented)
            .environment(
                \.setDetailSideBarPresented,
                showsDetailSideBar ? { store.send(.binding(.set(\.isDetailSideBarPresented, $0))) } : nil
            )

            // 칸 화면이 사이드바를 직접 그리면 창 사이드바는 표시하지 않음
            if showsDetailSideBar
                && store.isDetailSideBarPresented
                && store.detailSideBarTargets[selectedTab] != .hosted {
                DetailSideBar(
                    target: store.detailSideBarTargets[selectedTab],
                    windowEvent: windowEvent
                ) {
                    store.send(.binding(.set(\.isDetailSideBarPresented, false)))
                }
            }
        }
        // 사이드바가 있는 창의 설정은 앱 화면을 덮어 창 전체에 표시하고 닫으면 보던 화면으로 돌아감
        // 창이 좁아져도 진행 중인 로그아웃, 회원 탈퇴나 그 알림창이 끝날 때까지 표시
        .overlay {
            if store.isSettingsPresented && (showsSideBar || store.isSettingsBusy) {
                DesktopSettingsView { isBusy in
                    store.send(.binding(.set(\.isSettingsBusy, isBusy)))
                } onClose: {
                    store.send(.binding(.set(\.isSettingsPresented, false)))
                }
                .environment(\.readableContentWidth, readableContentWidth)
                .background(Color.background)
            }
        }
        // 세로로 펼친 Duo는 세로 막대가 없어 iPhone과 같은 화면 구성
        // 접힌 Duo는 세로 막대가 늘 있어 첫 화면이나 접는 중에도 바꾸지 않음
        .environment(
            \.deviceType,
            deviceType == .duo && horizontalSizeClass == .regular && verticalBarWidth == 0
                ? .bar : deviceType
        )
        // iPad 상태 표시줄 영역, Mac 창 제목 줄과 사이드바, 화면 영역을 나누는 구분선
        // iPad는 상태 표시줄 영역 맨 아래에 두어 상태 표시줄이 없는 창에서는 창 밖에 위치
        // Mac은 화면 영역 맨 위가 제목 줄 바로 아래라서 그 자리에 배치
        .overlay(alignment: .top) {
            if showsSideBar {
                Rectangle()
                    .fill(Color.separator)
                    .frame(height: 1)
                    .offset(y: isiOSAppOnMac ? 0 : -1)
                    .allowsHitTesting(false)
            }
        }
        .overlay {
            if 0 < verticalBarWidth {
                DuoTabBar(
                    selectedTab: $selectedTab,
                    edge: store.verticalBarInsets.leading < store.verticalBarInsets.trailing ? .trailing : .leading,
                    width: verticalBarWidth,
                    unreadPushCount: store.unreadPushCount
                )
            }
        }
        // Mac 창에서 상태 표시줄 자리로 비워 두는 상단 여백 제거
        .statusBarHidden(isiOSAppOnMac)
        // iPad는 사이드바를 펴면 목록 칸과 상세 칸이 함께 들어가지 않는 창에서 사이드바를 접고 시작
        // 세로 화면처럼 좁은 창에서 상세 칸이 잘리지 않게 함
        .onGeometryChange(for: Bool.self) { proxy in
            splitMinimumWidth + sideBarIdealWidth <= proxy.size.width
        } action: { fitsSideBar in
            guard !isiOSAppOnMac else { return }
            store.send(.binding(.set(\.isSideBarCollapsed, !fitsSideBar)))
        }
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.windowControlsInset
        } action: { inset in
            store.send(.binding(.set(\.windowControlsInset, inset)))
        }
        .toastHost()
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if showsTabBar {
                TabBar(
                    selectedTab: $selectedTab,
                    axis: .horizontal,
                    unreadPushCount: store.unreadPushCount
                )
                .padding(.horizontal, 8)
                .padding(.top, 8)
                .padding(.bottom, 4)
                .background(Color.background, ignoresSafeAreaEdges: .bottom)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Color.separator)
                        .frame(height: 1)
                }
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.size.height
                } action: { height in
                    store.send(.binding(.set(\.tabBarHeight, height)))
                }
            }
        }
        .onGeometryChange(for: EdgeInsets.self) { proxy in
            EdgeInsets(
                top: 0,
                leading: proxy.safeAreaInsets.leading,
                bottom: 0,
                trailing: proxy.safeAreaInsets.trailing
            )
        } action: { insets in
            store.send(.binding(.set(\.verticalBarInsets, insets)))
        }
        .onAppear { store.send(.view(.onAppear)) }
        .onChange(of: selectedTab, initial: true) { _, tab in
            store.send(.view(.selectedTabChanged(tab)))
        }
        // iPad 창이 좁아져 사이드바가 없어지면 진행 중인 요청과 알림창이 끝난 뒤 창 전체 설정 화면을 닫고 보던 화면으로 돌아감
        .onChange(of: showsSideBar || store.isSettingsBusy) { _, keepsSettings in
            if !keepsSettings {
                store.send(.binding(.set(\.isSettingsPresented, false)))
            }
        }
        .prominentAlert(store, state: \.alert, action: \.alert)
        // 이 화면 알림창도 화면 안쪽 알림창과 같은 버튼 모양으로 표시
        .environment(\.usesDesktopLayout, showsSideBar)
    }
}
