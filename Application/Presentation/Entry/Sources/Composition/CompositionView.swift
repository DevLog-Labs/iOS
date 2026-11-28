//
//  CompositionView.swift
//  Entry
//
//  Created by opfic on 5/8/25.
//

import SwiftUI
import ProfileTab
import PresentationShared

// SplitShell의 자리마다 넣을 화면과 탭 바를 정하는 화면
struct CompositionView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
    @Environment(\.deviceType) private var deviceType
    @Bindable private var store: StoreOf<CompositionFeature>
    private let windowEvent: TodoEditorWindowEvent
    // 목록 칸과 상세 칸이 함께 들어가는 화면 영역 폭
    private let splitMinimumWidth = CGFloat(800)

    init(store: StoreOf<CompositionFeature>, windowEvent: TodoEditorWindowEvent) {
        self.store = store
        self.windowEvent = windowEvent
    }

    var body: some View {
        let selectedTab = store.selectedTab
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
        let sideBarIdealWidth = isiOSAppOnMac ? 220 * AdaptiveSize.boardScale : 250
        let tabBarInset = showsTabBar ? store.tabBarHeight : 0
        // 사이드바가 있는 창에서 연 설정은 좁아지면 고른 탭을 바꾸지 않고 프로필 화면에 이어서 표시
        let visibleTab = !showsSideBar && store.isSettingsPresented ? AppTab.profile : selectedTab

        SplitShell {
            if showsSideBar && !store.sideBar.isCollapsed {
                // 최소는 화살표와 아이콘만 보이는 폭, Mac 최대는 Orca 사이드바와 같은 폭
                TreeSideBar(
                    store: store.scope(state: \.sideBar, action: \.sideBar),
                    selectedTab: selectedTab,
                    unreadPushCount: store.unreadPushCount.count
                )
                    .resizablePane(
                        width: store.sideBar.width,
                        minimumWidth: isiOSAppOnMac ? 72 * AdaptiveSize.boardScale : 84,
                        idealWidth: sideBarIdealWidth,
                        maximumWidth: isiOSAppOnMac ? 500 * AdaptiveSize.boardScale : 320
                    ) { width in
                        store.send(.sideBar(.resized(width)))
                    }
                    // 칸 자르기 밖이라 잘리지 않도록 바탕은 칸 바깥에서 아래쪽 안전 영역까지 채움
                    .background(Color.secondaryBackground, ignoresSafeAreaEdges: .bottom)
            }
        } center: {
            ZStack {
                // iPad는 시스템 탭 바를 쓰지 않아 Mac과 같이 구성
                // 넓은 창과 좁은 창을 오가도 탭 화면을 다시 만들지 않음
                if isiOSAppOnMac || deviceType == .ipad {
                    // 탭 전환 애니메이션 없이 한 번 연 탭을 유지하고 선택한 탭만 표시
                    // 사이드바 하위 항목은 홈 화면이 알려 주므로 홈은 처음부터 생성
                    ForEach(AppTab.allCases, id: \.self) { tab in
                        if store.openedTabs.contains(tab) || selectedTab == tab || visibleTab == tab || tab == .home {
                            TabScreen(
                                store: store,
                                tab: tab,
                                isSelected: selectedTab == tab && visibleTab == tab,
                                isVisible: visibleTab == tab,
                                isTabBarHidden: isSystemTabBarHidden,
                                tabBarInset: tabBarInset,
                                windowEvent: windowEvent
                            )
                            .opacity(visibleTab == tab ? 1 : 0)
                            .allowsHitTesting(visibleTab == tab)
                        }
                    }
                } else {
                    TabView(selection: $store.selectedTab.sending(\.selectTab)) {
                        ForEach(AppTab.allCases, id: \.self) { tab in
                            Tab(tab.title, systemImage: tab.symbolName, value: tab) {
                                TabScreen(
                                    store: store,
                                    tab: tab,
                                    isSelected: selectedTab == tab && visibleTab == tab,
                                    isVisible: visibleTab == tab,
                                    isTabBarHidden: isSystemTabBarHidden,
                                    tabBarInset: tabBarInset,
                                    windowEvent: windowEvent
                                )
                            }
                            .badge(tab == .notification ? store.unreadPushCount.count : 0)
                        }
                    }
                }
            }
            .environment(\.usesPaneLayout, showsSideBar)
            .environment(\.windowControlsInset, tabContentInset)
            .environment(\.readableContentWidth, readableContentWidth)
            .background {
                ReadableContentWidthReader { width in
                    store.send(.binding(.set(\.readableContentWidth, width)))
                }
            }
            // 접은 사이드바는 화면 칸 제목 줄의 버튼으로 다시 폄
            .environment(
                \.expandSideBar,
                store.sideBar.isCollapsed ? { store.send(.sideBar(.binding(.set(\.isCollapsed, false)))) } : nil
            )
            // 닫힌 세부 정보 사이드바는 화면 칸 제목 줄의 버튼으로 엶
            .environment(
                \.showDetailSideBar,
                showsSideBar && !store.detailSideBar.isPresented
                    ? { store.send(.detailSideBar(.binding(.set(\.isPresented, true)))) } : nil
            )
            .environment(
                \.setDetailSideBarPresented,
                showsSideBar ? { store.send(.detailSideBar(.binding(.set(\.isPresented, $0)))) } : nil
            )
        } right: { content in
            // 탭 화면이 올린 내용, 올린 내용이 없으면 안내 표시
            if showsSideBar && store.detailSideBar.isPresented {
                DetailSideBar {
                    store.send(.detailSideBar(.binding(.set(\.isPresented, false))))
                } content: {
                    if let content {
                        content
                    } else {
                        DetailSideBarPlaceholder()
                    }
                }
            }
        } overlay: {
            // 사이드바가 있는 창의 설정은 앱 화면을 덮어 창 전체에 표시하고 닫으면 보던 화면으로 돌아감
            if showsSideBar
                && store.settings.screen != nil
                && (store.isSettingsPresented || selectedTab == .profile) {
                DesktopSettingsView(store: store.scope(state: \.settings, action: \.settings))
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
                    selectedTab: $store.selectedTab.sending(\.selectTab),
                    edge: store.verticalBarInsets.leading < store.verticalBarInsets.trailing ? .trailing : .leading,
                    width: verticalBarWidth,
                    unreadPushCount: store.unreadPushCount.count
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
            store.send(.sideBar(.binding(.set(\.isCollapsed, !fitsSideBar))))
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
                    selectedTab: Binding(
                        get: { visibleTab },
                        set: { store.send(.selectTab($0)) }
                    ),
                    axis: .horizontal,
                    unreadPushCount: store.unreadPushCount.count
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
        .onChange(of: showsSideBar, initial: true) { _, showsSideBar in
            store.send(.view(.sideBarVisibilityChanged(showsSideBar)))
        }
        .prominentAlert(
            store.scope(state: \.unreadPushCount, action: \.unreadPushCount),
            state: \.alert,
            action: \.alert
        )
        // 창 폭이 바뀌어 계정 화면을 옮겨 그려도 떠 있는 알림창이 닫히지 않게 이 화면에서 표시
        .background {
            Color.clear
                .prominentAlert(
                    store.scope(state: \.settings.account, action: \.settings.account),
                    state: \.alert,
                    action: \.alert
                )
                .environment(
                    \.isTabContentActive,
                    store.isAccountOpen && (store.isSettingsPresented || selectedTab == .profile)
                )
        }
        // 이 화면 알림창도 화면 안쪽 알림창과 같은 버튼 모양으로 표시
        .environment(\.usesDesktopLayout, showsSideBar)
    }
}
