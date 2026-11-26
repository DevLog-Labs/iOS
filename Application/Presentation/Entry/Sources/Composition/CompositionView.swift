//
//  CompositionView.swift
//  Entry
//
//  Created by opfic on 5/8/25.
//

import SwiftUI
import HomeTab
import NotificationTab
import ProfileTab
import PresentationShared
import TodayTab

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

// toolbarVisibility 적용 전 첫 프레임의 탭 바 노출 방지
// 바깥 SwiftUI 여백은 탭 안 UIKit 화면까지 전달되지 않아 직접 그린 탭 바 높이를 탭 컨트롤러 안전 영역에 더함
private struct TabBarVisibility: UIViewControllerRepresentable {
    let isHidden: Bool
    let bottomInset: CGFloat

    func makeUIViewController(context: Context) -> Controller {
        Controller()
    }

    func updateUIViewController(_ controller: Controller, context: Context) {
        controller.isTabBarHidden = isHidden
        controller.bottomInset = bottomInset
        controller.apply()
    }

    final class Controller: UIViewController {
        var isTabBarHidden = false
        var bottomInset = CGFloat.zero

        override func didMove(toParent parent: UIViewController?) {
            super.didMove(toParent: parent)
            apply()
        }

        func apply() {
            guard let tabBarController else { return }
            tabBarController.isTabBarHidden = isTabBarHidden
            if tabBarController.additionalSafeAreaInsets.bottom != bottomInset {
                tabBarController.additionalSafeAreaInsets.bottom = bottomInset
            }
        }
    }
}

// 화면 영역의 readableContentGuide 폭 전달
struct ReadableContentWidthReader: UIViewRepresentable {
    let action: (CGFloat) -> Void

    func makeUIView(context: Context) -> ReaderView {
        let view = ReaderView()
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: ReaderView, context: Context) {
        uiView.action = action
    }

    final class ReaderView: UIView {
        var action: ((CGFloat) -> Void)?
        private var width: CGFloat?

        override func layoutSubviews() {
            super.layoutSubviews()
            let width = readableContentGuide.layoutFrame.width
            guard width != self.width else { return }
            self.width = width
            // 레이아웃 중 상태 변경 방지
            DispatchQueue.main.async { [action] in
                action?(width)
            }
        }
    }
}

private struct TabScreen: View {
    let store: StoreOf<CompositionFeature>
    let tab: AppTab
    let isSelected: Bool
    let isTabBarHidden: Bool
    let tabBarInset: CGFloat
    let usesPaneLayout: Bool
    let windowControlsInset: CGFloat
    let readableContentWidth: CGFloat
    let windowEvent: TodoEditorWindowEvent

    var body: some View {
        content
            .environment(\.isTabContentActive, isSelected)
            .environment(\.usesPaneLayout, usesPaneLayout)
            .environment(\.windowControlsInset, windowControlsInset)
            .environment(\.readableContentWidth, readableContentWidth)
            .environment(\.sideBarRequest, store.sideBarRequests[tab])
            // 좁은 창에서도 고른 대상을 기록해 넓은 창으로 바뀌면 바로 세부 정보 사이드바에 표시
            .environment(\.selectDetailSideBarTarget) { store.send(.view(.detailSideBarTargetChanged(tab, $0, owner: $1))) }
            .environment(\.removeDetailSideBarTarget) { store.send(.view(.detailSideBarOwnerRemoved(tab, owner: $0))) }
            .onPreferenceChange(SideBarLocationPreferenceKey.self) { location in
                guard let location else { return }
                store.send(.view(.sideBarLocationChanged(tab, location)))
            }
            .onPreferenceChange(PaneDetailEditingPreferenceKey.self) { isEditing in
                store.send(.view(.paneEditingChanged(tab, isEditing)))
            }
            .onPreferenceChange(SideBarContentPreferenceKey.self) { content in
                guard let content else { return }
                store.send(.view(.sideBarContentChanged(content)))
            }
            .toolbarVisibility(isTabBarHidden ? .hidden : .visible, for: .tabBar)
            .background { TabBarVisibility(isHidden: isTabBarHidden, bottomInset: tabBarInset) }
    }

    @ViewBuilder
    private var content: some View {
        switch tab {
        case .home:
            HomeView(
                isSelected: isSelected,
                windowEvent: windowEvent
            )
        case .today:
            TodayView(
                isSelected: isSelected,
                windowEvent: windowEvent
            )
        case .notification:
            PushNotificationListView(isSelected: isSelected)
        case .profile:
            ProfileView(
                isSelected: isSelected,
                windowEvent: windowEvent
            )
        }
    }
}

// Duo 세로 칸 경계선과 아래쪽 탭
// 위쪽 상태 표시와 툴바 버튼 자리는 시스템 세로 막대가 맡음
private struct DuoTabBar: View {
    @Binding var selectedTab: AppTab
    let edge: HorizontalEdge
    let width: CGFloat
    let unreadPushCount: Int

    var body: some View {
        TabBar(
            selectedTab: $selectedTab,
            axis: .vertical,
            unreadPushCount: unreadPushCount
        )
        // 시스템 세로 막대 버튼처럼 화면 끝 쪽을 더 띄움
        .padding(edge == .trailing ? .trailing : .leading, 12)
        .frame(width: width)
        .frame(maxHeight: .infinity, alignment: .bottom)
        .overlay(alignment: edge == .trailing ? .leading : .trailing) {
            Rectangle()
                .fill(Color.separator)
                .frame(width: 1)
                .ignoresSafeArea(edges: .vertical)
                .allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity, alignment: edge == .trailing ? .trailing : .leading)
        .ignoresSafeArea(edges: .horizontal)
    }
}

// Mac과 넓은 iPad 창에서 Finder처럼 위치를 고르는 트리 사이드바
private struct TreeSideBar: View {
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
    @Environment(\.paneWidth) private var paneWidth
    @Binding var selectedTab: AppTab
    let store: StoreOf<CompositionFeature>

    var body: some View {
        let location = store.sideBarLocations[selectedTab] ?? selectedTab.sideBarLocation
        let expandedGroups = store.expandedSideBarGroups
        let isCompact = (paneWidth ?? .infinity) < SideBarRow.compactWidth
        let collapseButton = Button {
            store.send(.binding(.set(\.isSideBarCollapsed, true)))
        } label: {
            Image(systemName: "sidebar.left")
        }
        .topBarButtonStyle()

        GeometryReader { geometry in
            VStack(spacing: 0) {
                // 칸 제목 줄과 같은 높이의 사이드바 접기 줄
                PaneTitleBar(background: .secondaryBackground) {
                    EmptyView()
                } actions: {
                    if !isCompact {
                        collapseButton
                    }
                }
                // 아이콘만 보일 때는 아래 줄 아이콘과 같은 세로선에 배치
                .overlay(alignment: .leading) {
                    if isCompact {
                        collapseButton
                            .frame(width: isiOSAppOnMac ? 18 * AdaptiveSize.boardScale : 20)
                            .padding(.leading, isiOSAppOnMac ? (8 + 4 + 14 + 6) * AdaptiveSize.boardScale : 8 + 6 + 16 + 8)
                    }
                }
                ScrollView {
                    VStack(spacing: isiOSAppOnMac ? AdaptiveSize.boardScale : 2) {
                        ForEach([AppTab.home, .today, .notification], id: \.self) { tab in
                            SideBarRow(
                                title: Text(tab.title),
                                symbolName: tab.symbolName,
                                isSelected: location == tab.sideBarLocation,
                                badgeCount: tab == .notification ? store.unreadPushCount : 0
                            ) {
                                open(tab.sideBarLocation)
                            }
                        }
                        SideBarRow(
                            title: Text("development_goal_title", bundle: PresentationResources.bundle),
                            symbolName: "flag.checkered",
                            isExpanded: expandedGroups.contains(.developmentGoal)
                        ) {
                            store.send(.view(.tapSideBarGroup(.developmentGoal)), animation: .easeInOut(duration: 0.2))
                        }
                        if expandedGroups.contains(.developmentGoal) {
                            ForEach(store.sideBarContent.developmentGoals) { goal in
                                SideBarRow(
                                    title: Text(goal.title),
                                    symbolName: "flag",
                                    isChild: true,
                                    isSelected: location == .developmentGoal(goal.id)
                                ) {
                                    open(.developmentGoal(goal.id))
                                }
                            }
                        }
                        SideBarRow(
                            title: Text(verbatim: "Todo"),
                            symbolName: "tray.fill",
                            isSelected: location == .todoCategoryManagement,
                            isExpanded: expandedGroups.contains(.todo)
                        ) {
                            store.send(.view(.tapSideBarGroup(.todo)), animation: .easeInOut(duration: 0.2))
                        }
                        .contextMenu {
                            Button {
                                request(.createTodo)
                            } label: {
                                Label {
                                    Text("sidebar_new_todo", bundle: PresentationResources.bundle)
                                } icon: {
                                    Image(systemName: "square.and.pencil")
                                }
                            }
                            Button {
                                request(.manageTodoCategory)
                            } label: {
                                Label {
                                    Text("todo_category_manage", bundle: PresentationResources.bundle)
                                } icon: {
                                    Image(systemName: "square.grid.2x2")
                                }
                            }
                        }
                        if expandedGroups.contains(.todo) {
                            ForEach(store.sideBarContent.todoCategories) { item in
                                SideBarRow(
                                    title: Text(item.localizedName),
                                    symbolName: item.symbolName,
                                    symbolColor: item.color,
                                    isChild: true,
                                    isSelected: location == .todoCategory(item.id)
                                ) {
                                    open(.todoCategory(item.id))
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 8 * AdaptiveSize.boardScale)
                    .padding(.vertical, 10 * AdaptiveSize.boardScale)
                }
                VStack(spacing: isiOSAppOnMac ? AdaptiveSize.boardScale : 2) {
                    SideBarRow(
                        title: Text(AppTab.profile.title),
                        symbolName: AppTab.profile.symbolName,
                        isSelected: location == .profile
                    ) {
                        open(.profile)
                    }
                    SideBarRow(
                        title: Text("nav_settings", bundle: PresentationResources.bundle),
                        symbolName: "gearshape.fill",
                        isSelected: location == .settings
                    ) {
                        // 앱 화면과 분리한 설정 화면 표시
                        store.send(.binding(.set(\.isSettingsPresented, true)))
                    }
                }
                .padding(.horizontal, 8 * AdaptiveSize.boardScale)
                .padding(.vertical, 10 * AdaptiveSize.boardScale)
            }
            .padding(.top, geometry.windowControlsInset)
        }
        // 칸이 기본 폭보다 좁아도 잘라 내지 않고 지금 폭에 맞춰 배치
        .frame(width: paneWidth)
    }

    private func open(_ location: SideBarLocation) {
        selectedTab = location.tab
        store.send(.view(.tapSideBarItem(location.tab, .open(location))))
    }

    // Todo 우클릭 메뉴의 작성과 카테고리 관리는 홈 화면에서 표시
    private func request(_ action: SideBarRequest.Action) {
        selectedTab = .home
        store.send(.view(.tapSideBarItem(.home, action)))
    }
}

// Mac과 iPad가 같은 모양으로 쓰는 트리 사이드바 항목
// Mac은 Mac 화면 크기, iPad는 손가락으로 누르는 크기
private struct SideBarRow: View {
    // 이름이 들어갈 자리가 없어 아이콘만 표시하는 폭
    static let compactWidth = ProcessInfo.processInfo.isiOSAppOnMac ? 104 * AdaptiveSize.boardScale : 120

    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
    @Environment(\.paneWidth) private var paneWidth
    let title: Text
    let symbolName: String
    var symbolColor: Color?
    var isChild = false
    var isSelected = false
    // 묶음 이름 줄만 펼침 여부가 있음
    var isExpanded: Bool?
    var badgeCount = 0
    let action: () -> Void

    var body: some View {
        let isCompact = (paneWidth ?? .infinity) < Self.compactWidth

        Button(action: action) {
            HStack(spacing: isiOSAppOnMac ? 6 * AdaptiveSize.boardScale : 8) {
                Image(systemName: "chevron.right")
                    .font(.adaptive(.caption2).weight(.bold))
                    .foregroundStyle(Color.secondaryLabel)
                    .rotationEffect(.degrees(isExpanded == true ? 90 : 0))
                    .opacity(isExpanded == nil ? 0 : 1)
                    .frame(width: isiOSAppOnMac ? 14 * AdaptiveSize.boardScale : 16)
                Image(systemName: symbolName)
                    .font(.adaptive(.body))
                    .foregroundStyle(symbolColor ?? .secondaryLabel)
                    .frame(width: isiOSAppOnMac ? 18 * AdaptiveSize.boardScale : 20)
                    // 아이콘만 보일 때 읽지 않은 알림은 아이콘 오른쪽 위 점으로 표시
                    .overlay(alignment: .topTrailing) {
                        if isCompact && 0 < badgeCount {
                            Circle()
                                .fill(Color.accent)
                                .frame(width: 7 * AdaptiveSize.boardScale, height: 7 * AdaptiveSize.boardScale)
                                .offset(x: 3 * AdaptiveSize.boardScale, y: -2 * AdaptiveSize.boardScale)
                        }
                    }
                title
                    .font(.adaptive(isiOSAppOnMac ? .body : .subheadline).weight(isChild ? .medium : .semibold))
                    .lineLimit(1)
                    // 아이콘만 보일 때도 이름 줄 높이는 유지
                    .frame(maxWidth: isCompact ? 0 : nil)
                    .opacity(isCompact ? 0 : 1)
                // 읽지 않은 개수는 이름 바로 오른쪽에 표시
                if !isCompact && 0 < badgeCount {
                    Text(verbatim: badgeCount.formatted())
                        .font(.adaptive(.caption2))
                        .monospacedDigit()
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 4 * AdaptiveSize.boardScale)
                        .frame(minWidth: 18 * AdaptiveSize.boardScale, minHeight: 18 * AdaptiveSize.boardScale)
                        .background(Color.accent, in: .capsule)
                        .fixedSize()
                }
            }
            .foregroundStyle(Color.label)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, isiOSAppOnMac ? (isChild && !isCompact ? 22 : 4) * AdaptiveSize.boardScale : (isChild && !isCompact ? 34 : 6))
            .padding(.trailing, isiOSAppOnMac ? 8 * AdaptiveSize.boardScale : 10)
            .frame(minHeight: isiOSAppOnMac ? 28 * AdaptiveSize.boardScale : 44)
            .hoverHighlight(in: RoundedRectangle(cornerRadius: CornerRadius.control), isEnabled: !isSelected)
            // 선택 표시는 마우스 표시와 같은 회색
            .background {
                RoundedRectangle(cornerRadius: CornerRadius.control)
                    .fill(isSelected ? Color.fill : .clear)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}
