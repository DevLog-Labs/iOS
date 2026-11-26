//
//  UnreadPushCountFeature.swift
//  Entry
//
//  Created by opfic on 11/25/26.
//

import Core
import Domain
import Foundation
import PresentationShared
import UserNotifications

@Reducer
struct UnreadPushCountFeature {
    private enum CancelID: Hashable {
        case count
    }

    @ObservableState
    struct State: Equatable {
        @Presents var alert: AlertState<Never>?
        var count = 0
    }

    enum Action: Equatable {
        case alert(PresentationAction<Never>)
        case startObserving
        case setCount(Int)
        case setAlert
    }

    @Dependency(\.observeUnreadPushCountUseCase) var observeUnreadPushCountUseCase
    @Dependency(\.setApplicationBadgeCount) var setApplicationBadgeCount

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .alert:
                break
            case .startObserving:
                return observeCountEffect()
            case .setCount(let count):
                state.count = count
                return updateBadgeCountEffect(count)
            case .setAlert:
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

private extension UnreadPushCountFeature {
    func observeCountEffect() -> Effect<Action> {
        .run { [observeUnreadPushCountUseCase] send in
            do {
                let publisher = try observeUnreadPushCountUseCase.observe()
                for try await count in publisher.values {
                    await send(.setCount(count))
                }
            } catch {
                await send(.setAlert)
            }
        }
        .cancellable(id: CancelID.count, cancelInFlight: true)
    }

    func updateBadgeCountEffect(_ count: Int) -> Effect<Action> {
        .run { [setApplicationBadgeCount] _ in
            do {
                try await setApplicationBadgeCount(count)
            } catch {
                Logger(category: "UnreadPushCountFeature").error("Failed to update application badge count", error: error)
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
            TextState(String(localized: "composition_alert_badge_error_message", bundle: PresentationResources.bundle))
        }
    }
}
