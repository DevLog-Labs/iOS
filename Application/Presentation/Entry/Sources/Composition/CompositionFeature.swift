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
import ProfileTab
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
        // 창에 사이드바가 있는지 여부, 배치가 아닌 설정 규칙에만 사용
        var showsSideBar = false
        // 앱 화면과 분리해 창 전체에 표시하는 설정 화면, 좁아진 창에서는 프로필 화면에 이어서 표시
        var isSettingsPresented = false
        var sideBar = SideBarFeature.State()
        var detailSideBar = DetailSideBarFeature.State()
        var unreadPushCount = UnreadPushCountFeature.State()
        // 창 폭이 바뀌어도 보던 항목과 진행 중인 로그아웃, 회원 탈퇴를 이어 가게 화면보다 위에서 보관
        var settings = SettingsFeature.State()

        // 계정 화면이 열려 있는지 여부, 창 전체 설정은 목차에서 고른 항목이고 좁은 창은 쌓은 설정의 맨 위 화면
        var isAccountOpen: Bool {
            let isDetailOpen = showsSideBar ? settings.screen != nil : settings.screen == .detail
            return isDetailOpen && settings.selectedRoute == .account
        }
    }

    enum KeyboardEvent: Equatable {
        case willShow(height: CGFloat)
        case willHide
    }

    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case start
        case selectTab(AppTab)
        case view(ViewAction)
        case sideBar(SideBarFeature.Action)
        case detailSideBar(DetailSideBarFeature.Action)
        case unreadPushCount(UnreadPushCountFeature.Action)
        case settings(SettingsFeature.Action)
        case store(StoreAction)

        enum ViewAction: Equatable {
            case sideBarVisibilityChanged(Bool)
        }

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
        CombineReducers {
            Scope(state: \.sideBar, action: \.sideBar) {
                SideBarFeature()
            }
            Scope(state: \.detailSideBar, action: \.detailSideBar) {
                DetailSideBarFeature()
            }
            Scope(state: \.unreadPushCount, action: \.unreadPushCount) {
                UnreadPushCountFeature()
            }
            Scope(state: \.settings, action: \.settings) {
                SettingsFeature()
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
                    // 좁아진 창에 설정이 이어져 있어도 탭이나 위젯에서 고른 탭을 표시
                    if !state.showsSideBar {
                        state.isSettingsPresented = false
                    }
                    return selectTabEffect(tab, state: &state)
                case .sideBar(.tapItem(let tab, _)):
                    return selectTabEffect(tab, state: &state)
                case .sideBar(.tapSettings):
                    return .send(.settings(.open))
                case .sideBar, .detailSideBar, .unreadPushCount:
                    break
                case .settings(.open):
                    state.isSettingsPresented = true
                case .settings(.close):
                    state.isSettingsPresented = false
                case .settings(.binding(\.screen)):
                    guard state.settings.screen == nil, state.isSettingsPresented else { break }
                    // 좁아진 창에서 설정을 닫으면 설정 아래에 있던 프로필 화면 표시
                    state.isSettingsPresented = false
                    return selectTabEffect(.profile, state: &state)
                case .settings:
                    break
                case .view(.sideBarVisibilityChanged(true)):
                    state.showsSideBar = true
                    // 사이드바가 있는 창으로 바뀌면 보던 설정을 창 전체 설정 화면에 이어서 표시
                    guard state.settings.screen != nil else { break }
                    // 다른 탭을 보던 중이면 쌓아 연 설정만 내리고 창 전체 설정 화면은 띄우지 않음
                    guard state.isSettingsPresented || state.selectedTab == .profile else {
                        state.settings.screen = nil
                        break
                    }
                    state.isSettingsPresented = true
                    // 창 전체 설정 화면은 고른 항목을 표시하므로 다시 좁아지면 그 항목 화면을 이어서 쌓음
                    // 앱 정보는 좁은 창에 항목 화면이 없어 설정 목록 유지
                    if state.settings.selectedRoute != .information {
                        state.settings.screen = .detail
                    }
                case .view(.sideBarVisibilityChanged(false)):
                    state.showsSideBar = false
                    // 좁아진 창에서 설정을 이어서 표시하는 프로필 화면 유지
                    if state.isSettingsPresented {
                        state.openedTabs.insert(.profile)
                    }
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
        .onChange(of: \.isAccountOpen) { _, isOpen in
            Reduce { _, _ in
                // 창 폭이 바뀌어 화면을 옮겨 그릴 때는 다시 조회하지 않고 계정 화면에 들어올 때만 조회
                // 계정 화면을 나가면 그 화면이 있던 창 정보를 지움
                .send(.settings(.account(isOpen ? .open : .setPresentationContext(nil))))
            }
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
