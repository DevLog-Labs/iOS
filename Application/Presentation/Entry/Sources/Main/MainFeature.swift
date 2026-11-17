//
//  MainFeature.swift
//  Entry
//
//  Created by opfic on 6/16/26.
//

import Combine
import PresentationShared
import Core
import Domain
import Foundation
import SwiftUI
import UserNotifications

@Reducer
struct MainFeature {
    @ObservableState
    struct State: Equatable {
        @Presents var alert: AlertState<Never>?
        var unreadPushCount = 0
        var isObservingUnreadPushCount = false
        var windowControlsInset = CGFloat.zero
        // Duo 세로 칸 자리의 양옆 안전 영역
        var verticalBarInsets = EdgeInsets()
        // 화면 키보드가 떠 있는 동안 직접 그린 하단 탭 바를 숨김
        var isKeyboardVisible = false
        // 탭 안 화면이 직접 그린 하단 탭 바 뒤로 들어가지 않도록 비울 높이
        var tabBarHeight = CGFloat.zero
        var readableContentWidth = CGFloat.infinity
        var openedTabs: Set<MainTab> = []
        var isSideBarCollapsed = false
        // 사용자가 끌어서 정한 사이드바 폭, 정하지 않았으면 기본 폭
        var sideBarWidth: CGFloat?
        var expandedSideBarGroups: Set<SideBarGroup> = []
        var sideBarLocations: [MainTab: SideBarLocation] = [:]
        var sideBarRequests: [MainTab: SideBarRequest] = [:]
        // 칸에 작성 화면을 그린 탭, 덮는 화면처럼 닫기·저장 버튼으로 닫기 전에는 사이드바로 이동하지 않음
        var paneEditingTabs: Set<MainTab> = []
        var sideBarContent = SideBarContent()
        var isDetailSideBarPresented = false
        // 앱 화면과 분리해 창 전체에 표시하는 Mac 설정 화면
        var isSettingsPresented = false
        // 탭마다 세부 정보 사이드바 대상을 고르는 화면, 대상이 없어도 나타난 순서대로 위치
        var detailSideBarSelections: [MainTab: [DetailSideBarSelection]] = [:]

        // 탭마다 지금 고른 세부 정보 사이드바 대상, 대상을 고른 화면 중 가장 나중에 나타난 화면의 대상
        var detailSideBarTargets: [MainTab: DetailSideBarTarget] {
            detailSideBarSelections.compactMapValues { $0.last { $0.target != nil }?.target }
        }
    }

    struct DetailSideBarSelection: Equatable {
        let owner: UUID
        var target: DetailSideBarTarget?
    }

    enum KeyboardEvent: Equatable {
        case willShow(height: CGFloat)
        case willHide
    }

    enum SideBarGroup: Hashable {
        case todo
        case developmentGoal
    }

    enum Action: BindableAction, Equatable {
        case alert(PresentationAction<Never>)
        case binding(BindingAction<State>)
        case view(ViewAction)
        case store(StoreAction)

        enum ViewAction: Equatable {
            case onAppear
            case selectedTabChanged(MainTab)
            case sideBarLocationChanged(MainTab, SideBarLocation)
            case sideBarContentChanged(SideBarContent)
            case tapSideBarGroup(SideBarGroup)
            case tapSideBarItem(MainTab, SideBarRequest.Action)
            case paneEditingChanged(MainTab, Bool)
            case sideBarResized(CGFloat)
            case detailSideBarTargetChanged(MainTab, DetailSideBarTarget?, owner: UUID)
            case detailSideBarOwnerRemoved(MainTab, owner: UUID)
        }

        enum StoreAction: Equatable {
            case setUnreadPushCount(Int)
            case keyboardChanged(KeyboardEvent)
            case setAlert
        }
    }

    private enum CancelID: Hashable {
        case unreadPushCount
        case keyboard
    }

    @Dependency(\.observeUnreadPushCountUseCase) var observeUnreadPushCountUseCase
    @Dependency(\.uuid) var uuid
    @Dependency(\.trackAnalyticsEventUseCase) var trackAnalyticsEventUseCase
    @Dependency(\.setApplicationBadgeCount) var setApplicationBadgeCount
    @Dependency(\.updateSideBarWidthUseCase) var updateSideBarWidthUseCase
    @Dependency(\.keyboardEvents) var keyboardEvents

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .alert:
                break
            case .binding:
                break
            case .view(.onAppear):
                guard !state.isObservingUnreadPushCount else { break }
                state.isObservingUnreadPushCount = true
                return .merge(observeUnreadPushCountEffect(), observeKeyboardEffect())
            case .view(.selectedTabChanged(let tab)):
                state.openedTabs.insert(tab)
                guard let screenName = tab.analyticsScreenName else { break }
                return trackScreenViewEffect(screenName)
            case .view(.sideBarLocationChanged(let tab, let location)):
                state.sideBarLocations[tab] = location
                // 홈 카테고리 격자처럼 다른 경로로 하위 항목에 들어오면 그 묶음을 펼침
                switch location {
                case .todoCategory:
                    state.expandedSideBarGroups.insert(.todo)
                case .developmentGoal:
                    state.expandedSideBarGroups.insert(.developmentGoal)
                case .home, .todoCategoryManagement, .today, .notification, .profile, .settings:
                    break
                }
            case .view(.sideBarContentChanged(let content)):
                state.sideBarContent = content
            case .view(.tapSideBarGroup(let group)):
                if state.expandedSideBarGroups.contains(group) {
                    state.expandedSideBarGroups.remove(group)
                } else {
                    state.expandedSideBarGroups.insert(group)
                }
            case .view(.tapSideBarItem(let tab, let action)):
                guard !state.paneEditingTabs.contains(tab) else { break }
                state.sideBarRequests[tab] = SideBarRequest(id: uuid(), action: action)
            case .view(.paneEditingChanged(let tab, let isEditing)):
                if isEditing {
                    state.paneEditingTabs.insert(tab)
                } else {
                    state.paneEditingTabs.remove(tab)
                }
            case .view(.sideBarResized(let width)):
                state.sideBarWidth = width
                return .run { [updateSideBarWidthUseCase] _ in
                    updateSideBarWidthUseCase.execute(Double(width))
                }
            case .view(.detailSideBarTargetChanged(let tab, let target, let owner)):
                // 대상을 바꿔도 화면이 나타난 순서의 자리 유지
                var selections = state.detailSideBarSelections[tab, default: []]
                if let index = selections.firstIndex(where: { $0.owner == owner }) {
                    selections[index].target = target
                } else {
                    selections.append(DetailSideBarSelection(owner: owner, target: target))
                }
                state.detailSideBarSelections[tab] = selections
            case .view(.detailSideBarOwnerRemoved(let tab, let owner)):
                // 사라지는 화면은 자기 자리만 지우고, 그 아래 화면이 고른 대상을 다시 표시
                state.detailSideBarSelections[tab]?.removeAll { $0.owner == owner }
            case .store(.setUnreadPushCount(let count)):
                state.unreadPushCount = count
                return updateBadgeCountEffect(count)
            case .store(.keyboardChanged(.willShow)):
                state.isKeyboardVisible = true
            case .store(.keyboardChanged(.willHide)):
                state.isKeyboardVisible = false
            case .store(.setAlert):
                state.alert = Self.alertState()
            }

            return .none
        }
        .ifLet(\.$alert, action: \.alert)
    }
}

extension DependencyValues {
    var observeUnreadPushCountUseCase: ObserveUnreadPushCountUseCase {
        get { self[ObserveUnreadPushCountUseCaseKey.self] }
        set { self[ObserveUnreadPushCountUseCaseKey.self] = newValue }
    }

    var setApplicationBadgeCount: @Sendable (Int) async throws -> Void {
        get { self[SetApplicationBadgeCountKey.self] }
        set { self[SetApplicationBadgeCountKey.self] = newValue }
    }

    var keyboardEvents: @Sendable () -> AnyPublisher<MainFeature.KeyboardEvent, Never> {
        get { self[KeyboardEventsKey.self] }
        set { self[KeyboardEventsKey.self] = newValue }
    }

    var fetchSideBarWidthUseCase: FetchSideBarWidthUseCase {
        get { self[FetchSideBarWidthUseCaseKey.self] }
        set { self[FetchSideBarWidthUseCaseKey.self] = newValue }
    }

    var updateSideBarWidthUseCase: UpdateSideBarWidthUseCase {
        get { self[UpdateSideBarWidthUseCaseKey.self] }
        set { self[UpdateSideBarWidthUseCaseKey.self] = newValue }
    }
}

private enum FetchSideBarWidthUseCaseKey: DependencyKey {
    static var liveValue: FetchSideBarWidthUseCase {
        preconditionFailure("FetchSideBarWidthUseCase must be provided.")
    }

    static var testValue: FetchSideBarWidthUseCase {
        liveValue
    }
}

private enum UpdateSideBarWidthUseCaseKey: DependencyKey {
    static var liveValue: UpdateSideBarWidthUseCase {
        preconditionFailure("UpdateSideBarWidthUseCase must be provided.")
    }

    static var testValue: UpdateSideBarWidthUseCase {
        liveValue
    }
}

private enum ObserveUnreadPushCountUseCaseKey: DependencyKey {
    static var liveValue: ObserveUnreadPushCountUseCase {
        preconditionFailure("ObserveUnreadPushCountUseCase must be provided.")
    }

    static var testValue: ObserveUnreadPushCountUseCase {
        liveValue
    }
}

private enum SetApplicationBadgeCountKey: DependencyKey {
    static let liveValue: @Sendable (Int) async throws -> Void = { count in
        try await UNUserNotificationCenter.current().setBadgeCount(count)
    }

    static var testValue: @Sendable (Int) async throws -> Void {
        liveValue
    }
}

private enum KeyboardEventsKey: DependencyKey {
    static let liveValue: @Sendable () -> AnyPublisher<MainFeature.KeyboardEvent, Never> = {
        let center = NotificationCenter.default
        return center.publisher(for: UIResponder.keyboardWillShowNotification)
            .map { notification in
                let frame = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue
                return MainFeature.KeyboardEvent.willShow(height: frame?.height ?? 0)
            }
            .merge(with: center.publisher(for: UIResponder.keyboardWillHideNotification).map { _ in .willHide })
            .eraseToAnyPublisher()
    }

    static var testValue: @Sendable () -> AnyPublisher<MainFeature.KeyboardEvent, Never> {
        liveValue
    }
}

private extension MainFeature {
    func observeKeyboardEffect() -> Effect<Action> {
        .run { [keyboardEvents] send in
            for await event in keyboardEvents().values {
                await send(.store(.keyboardChanged(event)))
            }
        }
        .cancellable(id: CancelID.keyboard, cancelInFlight: true)
    }

    func observeUnreadPushCountEffect() -> Effect<Action> {
        .run { [observeUnreadPushCountUseCase] send in
            do {
                let publisher = try observeUnreadPushCountUseCase.observe()
                for try await count in publisher.values {
                    await send(.store(.setUnreadPushCount(count)))
                }
            } catch {
                await send(.store(.setAlert))
            }
        }
        .cancellable(id: CancelID.unreadPushCount, cancelInFlight: true)
    }

    func trackScreenViewEffect(_ screenName: String) -> Effect<Action> {
        .run { [trackAnalyticsEventUseCase] _ in
            trackAnalyticsEventUseCase.execute(.screenView(screenName))
        }
    }

    func updateBadgeCountEffect(_ count: Int) -> Effect<Action> {
        .run { [setApplicationBadgeCount] _ in
            do {
                try await setApplicationBadgeCount(count)
            } catch {
                Logger(category: "MainFeature").error("Failed to update application badge count", error: error)
            }
        }
    }

    static func alertState() -> AlertState<Never> {
        AlertState {
            TextState(String(localized: "common_error_title", bundle: PresentationResources.bundle))
        } actions: {
            ButtonState(role: .cancel) {
                TextState(String(localized: "common_close", bundle: PresentationResources.bundle))
            }
        } message: {
            TextState(String(localized: "main_alert_badge_error_message", bundle: PresentationResources.bundle))
        }
    }
}

private extension MainTab {
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
