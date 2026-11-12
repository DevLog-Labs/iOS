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

        HStack(spacing: 0) {
            if showsSideBar {
                SideBar(
                    selectedTab: $selectedTab,
                    unreadPushCount: store.unreadPushCount
                )
                .resizableSideBar(
                    minimumWidth: 220,
                    idealWidth: 260,
                    maximumWidth: 320
                )
            }

            TabView(selection: $selectedTab) {
                Tab(
                    MainTab.home.title,
                    systemImage: MainTab.home.symbolName,
                    value: MainTab.home
                ) {
                    MainTabContent(
                        tab: .home,
                        isSelected: selectedTab == .home,
                        showsSideBar: showsSideBar,
                        windowControlsInset: tabContentInset,
                        readableContentWidth: readableContentWidth,
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
                        showsSideBar: showsSideBar,
                        windowControlsInset: tabContentInset,
                        readableContentWidth: readableContentWidth,
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
                        showsSideBar: showsSideBar,
                        windowControlsInset: tabContentInset,
                        readableContentWidth: readableContentWidth,
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
                        showsSideBar: showsSideBar,
                        windowControlsInset: tabContentInset,
                        readableContentWidth: readableContentWidth,
                        windowEvent: windowEvent
                    )
                }
            }
            .background {
                ReadableContentWidthReader { width in
                    store.send(.binding(.set(\.readableContentWidth, width)))
                }
            }
        }
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
    let showsSideBar: Bool
    let windowControlsInset: CGFloat
    let readableContentWidth: CGFloat
    let windowEvent: TodoEditorWindowEvent

    var body: some View {
        content
            .environment(\.isTabContentActive, isSelected)
            .environment(\.windowControlsInset, windowControlsInset)
            .environment(\.readableContentWidth, readableContentWidth)
            .toolbarVisibility(showsSideBar ? .hidden : .visible, for: .tabBar)
            .background { TabBarVisibility(isHidden: showsSideBar) }
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

private struct SideBar: View {
    @Binding var selectedTab: MainTab
    let unreadPushCount: Int

    var body: some View {
        GeometryReader { geometry in
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
            .padding(.top, geometry.windowControlsInset)
        }
        .background {
            Color.surface
                .ignoresSafeArea(.container, edges: .vertical)
        }
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
            .foregroundStyle(isSelected ? Color.onPrimaryContainer : .primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.primaryContainer : .clear)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

private struct ResizableSideBarModifier: ViewModifier {
    @Environment(\.layoutDirection) private var layoutDirection
    @State private var width: CGFloat
    @State private var dragStartWidth: CGFloat?
    private let minimumWidth: CGFloat
    private let maximumWidth: CGFloat

    init(
        minimumWidth: CGFloat,
        idealWidth: CGFloat,
        maximumWidth: CGFloat
    ) {
        self.minimumWidth = minimumWidth
        self.maximumWidth = maximumWidth
        self._width = State(initialValue: min(max(idealWidth, minimumWidth), maximumWidth))
    }

    func body(content: Content) -> some View {
        content
            .frame(width: width)
            .overlay(alignment: .trailing) {
                Color.clear
                    .frame(width: 16)
                    .contentShape(.rect)
                    .gesture(resizeGesture)
                    .overlay(alignment: .trailing) {
                        Rectangle()
                            .fill(Color.border)
                            .frame(width: 1)
                    }
                    .ignoresSafeArea(.container, edges: .vertical)
            }
    }

    private var resizeGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .onChanged { value in
                if dragStartWidth == nil {
                    dragStartWidth = width
                }
                let startWidth = dragStartWidth ?? width
                let translation = layoutDirection == .leftToRight
                    ? value.translation.width
                    : -value.translation.width
                width = min(max(startWidth + translation, minimumWidth), maximumWidth)
            }
            .onEnded { _ in
                dragStartWidth = nil
            }
    }
}

private extension View {
    func resizableSideBar(
        minimumWidth: CGFloat,
        idealWidth: CGFloat,
        maximumWidth: CGFloat
    ) -> some View {
        modifier(ResizableSideBarModifier(
            minimumWidth: minimumWidth,
            idealWidth: idealWidth,
            maximumWidth: maximumWidth
        ))
    }
}
