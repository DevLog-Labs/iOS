//
//  CompositionFeature.swift
//  Entry
//
//  Created by opfic on 6/16/26.
//

import Combine
import PresentationShared
import Domain
import Foundation
import SwiftUI

@Reducer
struct CompositionFeature {
    @ObservableState
    struct State: Equatable {
        var windowControlsInset = CGFloat.zero
        // Duo 세로 칸 자리의 양옆 안전 영역
        var verticalBarInsets = EdgeInsets()
        // 화면 키보드가 떠 있는 동안 직접 그린 하단 탭 바를 숨김
        var isKeyboardVisible = false
        // 탭 안 화면이 직접 그린 하단 탭 바 뒤로 들어가지 않도록 비울 높이
        var tabBarHeight = CGFloat.zero
        var readableContentWidth = CGFloat.infinity
        var selectedTab = AppTab.home
        var openedTabs: Set<AppTab> = []
        // 앱 화면과 분리해 창 전체에 표시하는 Mac 설정 화면
        var isSettingsPresented = false
        // 창 전체 설정 화면에서 로그아웃, 회원 탈퇴나 그 알림창이 끝나지 않은 상태
        var isSettingsBusy = false
        var sideBar = SideBarFeature.State()
        var detailSideBar = DetailSideBarFeature.State()
        var unreadPushCount = UnreadPushCountFeature.State()
    }

    enum KeyboardEvent: Equatable {
        case willShow(height: CGFloat)
        case willHide
    }

    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case start
        case selectTab(AppTab)
        case sideBar(SideBarFeature.Action)
        case detailSideBar(DetailSideBarFeature.Action)
        case unreadPushCount(UnreadPushCountFeature.Action)
        case store(StoreAction)

        enum StoreAction: Equatable {
            case keyboardChanged(KeyboardEvent)
        }
    }

    private enum CancelID: Hashable {
        case keyboard
    }

    @Dependency(\.trackAnalyticsEventUseCase) var trackAnalyticsEventUseCase
    @Dependency(\.keyboardEvents) var keyboardEvents

    var body: some ReducerOf<Self> {
        Scope(state: \.sideBar, action: \.sideBar) {
            SideBarFeature()
        }
        Scope(state: \.detailSideBar, action: \.detailSideBar) {
            DetailSideBarFeature()
        }
        Scope(state: \.unreadPushCount, action: \.unreadPushCount) {
            UnreadPushCountFeature()
        }
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                break
            case .start:
                state.openedTabs.insert(state.selectedTab)
                return .merge(
                    .send(.unreadPushCount(.startObserving)),
                    observeKeyboardEffect(),
                    trackScreenViewEffect(state.selectedTab)
                )
            case .selectTab(let tab):
                return selectTabEffect(tab, state: &state)
            case .sideBar(.tapItem(let tab, _)):
                return selectTabEffect(tab, state: &state)
            case .sideBar(.tapSettings):
                state.isSettingsPresented = true
            case .sideBar, .detailSideBar, .unreadPushCount:
                break
            case .store(.keyboardChanged(.willShow(let height))):
                // 화면을 돌리면 키보드 없이도 높이 0인 키보드 표시 알림이 와서 무시
                guard 0 < height else { break }
                state.isKeyboardVisible = true
            case .store(.keyboardChanged(.willHide)):
                state.isKeyboardVisible = false
            }

            return .none
        }
    }
}

extension DependencyValues {
    var keyboardEvents: @Sendable () -> AnyPublisher<CompositionFeature.KeyboardEvent, Never> {
        get { self[KeyboardEventsKey.self] }
        set { self[KeyboardEventsKey.self] = newValue }
    }
}

private enum KeyboardEventsKey: DependencyKey {
    static let liveValue: @Sendable () -> AnyPublisher<CompositionFeature.KeyboardEvent, Never> = {
        let center = NotificationCenter.default
        return center.publisher(for: UIResponder.keyboardWillShowNotification)
            .map { notification in
                let frame = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue
                return CompositionFeature.KeyboardEvent.willShow(height: frame?.height ?? 0)
            }
            .merge(with: center.publisher(for: UIResponder.keyboardWillHideNotification).map { _ in .willHide })
            .eraseToAnyPublisher()
    }

    static var testValue: @Sendable () -> AnyPublisher<CompositionFeature.KeyboardEvent, Never> {
        liveValue
    }
}

private extension CompositionFeature {
    func observeKeyboardEffect() -> Effect<Action> {
        .run { [keyboardEvents] send in
            for await event in keyboardEvents().values {
                await send(.store(.keyboardChanged(event)))
            }
        }
        .cancellable(id: CancelID.keyboard, cancelInFlight: true)
    }

    func selectTabEffect(_ tab: AppTab, state: inout State) -> Effect<Action> {
        guard state.selectedTab != tab else { return .none }
        state.selectedTab = tab
        state.openedTabs.insert(tab)
        return trackScreenViewEffect(tab)
    }

    func trackScreenViewEffect(_ tab: AppTab) -> Effect<Action> {
        guard let screenName = tab.analyticsScreenName else { return .none }
        return .run { [trackAnalyticsEventUseCase] _ in
            trackAnalyticsEventUseCase.execute(.screenView(screenName))
        }
    }
}

private extension AppTab {
    var analyticsScreenName: String? {
        switch self {
        case .home:
            return "home"
        case .today:
            return "today"
        case .notification:
            return nil
        case .profile:
            return "profile"
        }
    }
}
