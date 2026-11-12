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
import UserNotifications

@Reducer
struct MainFeature {
    @ObservableState
    struct State: Equatable {
        @Presents var alert: AlertState<Never>?
        var unreadPushCount = 0
        var isObservingUnreadPushCount = false
        var isWide = false
        var windowControlsInset = CGFloat.zero
        var readableContentWidth = CGFloat.infinity
        var navigationHistories: [MainTab: NavigationHistoryState] = [:]
        var navigationSteps: [MainTab: NavigationStep] = [:]
        var openedTabs: Set<MainTab> = []
    }

    enum Action: BindableAction, Equatable {
        case alert(PresentationAction<Never>)
        case binding(BindingAction<State>)
        case view(ViewAction)
        case store(StoreAction)

        enum ViewAction: Equatable {
            case onAppear
            case selectedTabChanged(MainTab)
            case navigationHistoryChanged(MainTab, NavigationHistoryState)
            case tapNavigation(MainTab, NavigationStep.Direction)
        }

        enum StoreAction: Equatable {
            case setUnreadPushCount(Int)
            case setAlert
        }
    }

    private enum CancelID: Hashable {
        case unreadPushCount
    }

    @Dependency(\.observeUnreadPushCountUseCase) var observeUnreadPushCountUseCase
    @Dependency(\.uuid) var uuid
    @Dependency(\.trackAnalyticsEventUseCase) var trackAnalyticsEventUseCase
    @Dependency(\.setApplicationBadgeCount) var setApplicationBadgeCount

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
                return observeUnreadPushCountEffect()
            case .view(.selectedTabChanged(let tab)):
                state.openedTabs.insert(tab)
                guard let screenName = tab.analyticsScreenName else { break }
                return trackScreenViewEffect(screenName)
            case .view(.navigationHistoryChanged(let tab, let history)):
                state.navigationHistories[tab] = history
            case .view(.tapNavigation(let tab, let direction)):
                state.navigationSteps[tab] = NavigationStep(id: uuid(), direction: direction)
            case .store(.setUnreadPushCount(let count)):
                state.unreadPushCount = count
                return updateBadgeCountEffect(count)
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

private extension MainFeature {
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
