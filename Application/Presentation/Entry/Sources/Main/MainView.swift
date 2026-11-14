//
//  MainView.swift
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

struct MainView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
    @Environment(\.deviceType) private var deviceType
    @Binding var selectedTab: MainTab
    @State private var store: StoreOf<MainFeature>
    private let windowEvent: TodoEditorWindowEvent
    private let sideBarMinimumWidth = CGFloat(800)

    init(
        windowEvent: TodoEditorWindowEvent,
        selectedTab: Binding<MainTab>
    ) {
        self._store = State(initialValue: Store(initialState: MainFeature.State()) {
            MainFeature()
        })
        self._selectedTab = selectedTab
        self.windowEvent = windowEvent
    }

    var body: some View {
        let showsSideBar = isiOSAppOnMac || deviceType != .duo && horizontalSizeClass == .regular && store.isWide
        let tabContentInset = horizontalSizeClass == .compact ? store.windowControlsInset : 0
        let readableContentWidth = isiOSAppOnMac ? store.readableContentWidth : .infinity
        // iPhone, Duo, 좁은 iPad 창은 시스템 탭 바 대신 직접 그린 탭 사용
        let usesCustomTabBar = deviceType != .ipad || horizontalSizeClass == .compact
        let isSystemTabBarHidden = showsSideBar || usesCustomTabBar
        let verticalBarWidth = deviceType == .duo
            ? max(store.verticalBarInsets.leading, store.verticalBarInsets.trailing) : 0
        // 시스템 탭 바처럼 키보드가 올라오면 키보드 뒤로 사라짐
        let showsTabBar = !showsSideBar && usesCustomTabBar && verticalBarWidth == 0 && !store.isKeyboardVisible

        HStack(spacing: 0) {
            if showsSideBar {
                SideBar(
                    selectedTab: $selectedTab,
                    unreadPushCount: store.unreadPushCount,
                    history: isiOSAppOnMac ? store.navigationHistories[selectedTab, default: NavigationHistoryState()] : nil,
                    onBack: { store.send(.view(.tapNavigation(selectedTab, .back))) },
                    onForward: { store.send(.view(.tapNavigation(selectedTab, .forward))) }
                )
                .resizablePane(
                    minimumWidth: 220,
                    idealWidth: 260,
                    maximumWidth: 320
                )
            }

            ZStack {
                if isiOSAppOnMac {
                    // 탭 전환 애니메이션 없이 한 번 연 탭을 유지하고 선택한 탭만 표시
                    ForEach(MainTab.allCases, id: \.self) { tab in
                        if store.openedTabs.contains(tab) || selectedTab == tab {
                            MainTabContent(
                                tab: tab,
                                isSelected: selectedTab == tab,
                                isTabBarHidden: isSystemTabBarHidden,
                                windowControlsInset: tabContentInset,
                                readableContentWidth: readableContentWidth,
                                navigationStep: store.navigationSteps[tab],
                                onNavigationHistoryChange: { store.send(.view(.navigationHistoryChanged(tab, $0))) },
                                windowEvent: windowEvent
                            )
                            .opacity(selectedTab == tab ? 1 : 0)
                            .allowsHitTesting(selectedTab == tab)
                        }
                    }
                } else {
                    TabView(selection: $selectedTab) {
                        Tab(
                            MainTab.home.title,
                            systemImage: MainTab.home.symbolName,
                            value: MainTab.home
                        ) {
                            MainTabContent(
                                tab: .home,
                                isSelected: selectedTab == .home,
                                isTabBarHidden: isSystemTabBarHidden,
                                windowControlsInset: tabContentInset,
                                readableContentWidth: readableContentWidth,
                                navigationStep: store.navigationSteps[.home],
                                onNavigationHistoryChange: { store.send(.view(.navigationHistoryChanged(.home, $0))) },
                                windowEvent: windowEvent
                            )
                        }
                        Tab(
                            MainTab.today.title,
                            systemImage: MainTab.today.symbolName,
                            value: MainTab.today
                        ) {
                            MainTabContent(
                                tab: .today,
                                isSelected: selectedTab == .today,
                                isTabBarHidden: isSystemTabBarHidden,
                                windowControlsInset: tabContentInset,
                                readableContentWidth: readableContentWidth,
                                navigationStep: store.navigationSteps[.today],
                                onNavigationHistoryChange: { store.send(.view(.navigationHistoryChanged(.today, $0))) },
                                windowEvent: windowEvent
                            )
                        }
                        Tab(
                            MainTab.notification.title,
                            systemImage: MainTab.notification.symbolName,
                            value: MainTab.notification
                        ) {
                            MainTabContent(
                                tab: .notification,
                                isSelected: selectedTab == .notification,
                                isTabBarHidden: isSystemTabBarHidden,
                                windowControlsInset: tabContentInset,
                                readableContentWidth: readableContentWidth,
                                navigationStep: store.navigationSteps[.notification],
                                onNavigationHistoryChange: { store.send(.view(.navigationHistoryChanged(.notification, $0))) },
                                windowEvent: windowEvent
                            )
                        }
                        .badge(store.unreadPushCount)
                        Tab(
                            MainTab.profile.title,
                            systemImage: MainTab.profile.symbolName,
                            value: MainTab.profile
                        ) {
                            MainTabContent(
                                tab: .profile,
                                isSelected: selectedTab == .profile,
                                isTabBarHidden: isSystemTabBarHidden,
                                windowControlsInset: tabContentInset,
                                readableContentWidth: readableContentWidth,
                                navigationStep: store.navigationSteps[.profile],
                                onNavigationHistoryChange: { store.send(.view(.navigationHistoryChanged(.profile, $0))) },
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
        }
        .overlay {
            if 0 < verticalBarWidth {
                MainTabRail(
                    selectedTab: $selectedTab,
                    edge: store.verticalBarInsets.leading < store.verticalBarInsets.trailing ? .trailing : .leading,
                    width: verticalBarWidth,
                    unreadPushCount: store.unreadPushCount
                )
            }
        }
        // Mac 창에서 상태 표시줄 자리로 비워 두는 상단 여백 제거
        .statusBarHidden(isiOSAppOnMac)
        .onGeometryChange(for: Bool.self) { proxy in
            sideBarMinimumWidth <= proxy.size.width
        } action: { isWide in
            store.send(.binding(.set(\.isWide, isWide)))
        }
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.windowControlsInset
        } action: { inset in
            store.send(.binding(.set(\.windowControlsInset, inset)))
        }
        .toastHost()
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if showsTabBar {
                MainTabBar(
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
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            store.send(.binding(.set(\.isKeyboardVisible, true)))
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            store.send(.binding(.set(\.isKeyboardVisible, false)))
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
        .prominentAlert(store, state: \.alert, action: \.alert)
    }
}

// toolbarVisibility 적용 전 첫 프레임의 탭 바 노출 방지
private struct TabBarVisibility: UIViewControllerRepresentable {
    let isHidden: Bool

    func makeUIViewController(context: Context) -> Controller {
        Controller()
    }

    func updateUIViewController(_ controller: Controller, context: Context) {
        controller.isTabBarHidden = isHidden
        controller.tabBarController?.isTabBarHidden = isHidden
    }

    final class Controller: UIViewController {
        var isTabBarHidden = false

        override func didMove(toParent parent: UIViewController?) {
            super.didMove(toParent: parent)
            tabBarController?.isTabBarHidden = isTabBarHidden
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

private struct MainTabContent: View {
    let tab: MainTab
    let isSelected: Bool
    let isTabBarHidden: Bool
    let windowControlsInset: CGFloat
    let readableContentWidth: CGFloat
    let navigationStep: NavigationStep?
    let onNavigationHistoryChange: (NavigationHistoryState) -> Void
    let windowEvent: TodoEditorWindowEvent

    var body: some View {
        content
            .environment(\.isTabContentActive, isSelected)
            .environment(\.windowControlsInset, windowControlsInset)
            .environment(\.readableContentWidth, readableContentWidth)
            .environment(\.navigationStep, navigationStep)
            .onPreferenceChange(NavigationHistoryPreferenceKey.self) { history in
                onNavigationHistoryChange(history)
            }
            .toolbarVisibility(isTabBarHidden ? .hidden : .visible, for: .tabBar)
            .background { TabBarVisibility(isHidden: isTabBarHidden) }
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
private struct MainTabRail: View {
    @Binding var selectedTab: MainTab
    let edge: HorizontalEdge
    let width: CGFloat
    let unreadPushCount: Int

    var body: some View {
        MainTabBar(
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

private struct SideBar: View {
    @Binding var selectedTab: MainTab
    let unreadPushCount: Int
    let history: NavigationHistoryState?
    let onBack: () -> Void
    let onForward: () -> Void

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                if let history {
                    // 칸 제목 줄과 같은 높이의 ← → 줄
                    PaneTitleBar(background: .secondaryBackground) {
                        EmptyView()
                    } actions: {
                        SideBarHistoryButton(
                            systemName: "arrow.left",
                            isEnabled: history.canGoBack,
                            action: onBack
                        )
                        SideBarHistoryButton(
                            systemName: "arrow.right",
                            isEnabled: history.canGoForward,
                            action: onForward
                        )
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(MainTab.allCases, id: \.self) { tab in
                        if tab == .profile { Spacer() }
                        SideBarButton(
                            tab: tab,
                            isSelected: selectedTab == tab,
                            unreadPushCount: unreadPushCount
                        ) {
                            selectedTab = tab
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 16)
            }
            .padding(.top, geometry.windowControlsInset)
        }
        .background {
            Color.secondaryBackground
                .ignoresSafeArea(.container, edges: .vertical)
        }
    }
}

private struct SideBarHistoryButton: View {
    let systemName: String
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .foregroundStyle(isEnabled ? Color.label : .tertiaryLabel)
        }
        .topBarButtonStyle()
        .disabled(!isEnabled)
    }
}

private struct SideBarButton: View {
    let tab: MainTab
    let isSelected: Bool
    let unreadPushCount: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: tab.symbolName)
                    .font(.title3)
                    .frame(width: 24)
                Text(tab.title)
                    .font(.body.weight(.semibold))
                    .lineLimit(1)
                Spacer(minLength: 8)
                if tab == .notification, 0 < unreadPushCount {
                    Text(verbatim: unreadPushCount.formatted())
                        .font(.caption.bold())
                        .monospacedDigit()
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accent, in: .capsule)
                }
            }
            .foregroundStyle(isSelected ? Color.tintLabel : .label)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background {
                RoundedRectangle(cornerRadius: CornerRadius.control)
                    .fill(isSelected ? Color.tintFill : .clear)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}
