//
//  TabScreen.swift
//  Entry
//
//  Created by opfic on 11/25/26.
//

import SwiftUI
import HomeTab
import NotificationTab
import ProfileTab
import PresentationShared
import TodayTab

struct TabScreen: View {
    let store: StoreOf<CompositionFeature>
    let tab: AppTab
    let isSelected: Bool
    let isVisible: Bool
    let isTabBarHidden: Bool
    let tabBarInset: CGFloat
    let windowEvent: TodoEditorWindowEvent

    var body: some View {
        content
            .environment(\.isTabContentActive, isVisible)
            .environment(\.sideBarRequest, store.sideBar.requests[tab])
            // 고른 탭 화면이 올린 세부 정보 사이드바 내용만 창에 전달
            .transformPreference(DetailSideBarContentPreferenceKey.self) { content in
                if !isSelected {
                    content = nil
                }
            }
            .onPreferenceChange(SideBarLocationPreferenceKey.self) { location in
                guard let location else { return }
                store.send(.sideBar(.locationChanged(tab, location)))
            }
            .onPreferenceChange(PaneDetailEditingPreferenceKey.self) { isEditing in
                store.send(.sideBar(.paneEditingChanged(tab, isEditing)))
            }
            .onPreferenceChange(SideBarContentPreferenceKey.self) { content in
                guard let content else { return }
                store.send(.sideBar(.contentChanged(content)))
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
            PushNotificationListView(isSelected: isSelected, windowEvent: windowEvent)
        case .profile:
            ProfileView(
                isSelected: isSelected,
                settingsStore: store.scope(state: \.settings, action: \.settings),
                windowEvent: windowEvent
            )
        }
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
