//
//  CompositionFeatureTestSupport.swift
//  EntryTests
//
//  Created by opfic on 11/25/26.
//

import Combine
import PresentationShared
import Domain
import Foundation
@testable import Entry

@MainActor
func makeStore(
    unreadPushCountUseCase: ObserveUnreadPushCountUseCase = ObserveUnreadPushCountUseCaseSpy(),
    trackAnalyticsEventUseCase: TrackAnalyticsEventUseCase = CompositionTrackAnalyticsEventUseCaseSpy(),
    badgeCountSpy: CompositionApplicationBadgeCountSpy = CompositionApplicationBadgeCountSpy()
) -> TestStoreOf<CompositionFeature> {
    let store = TestStore(initialState: CompositionFeature.State()) {
        CompositionFeature()
    } withDependencies: {
        $0.observeUnreadPushCountUseCase = unreadPushCountUseCase
        $0.trackAnalyticsEventUseCase = trackAnalyticsEventUseCase
        $0.setApplicationBadgeCount = { count in
            try await badgeCountSpy.setBadgeCount(count)
        }
    }
    store.exhaustivity = .off(showSkippedAssertions: false)
    return store
}

@MainActor
func makeUnreadPushCountStore(
    unreadPushCountUseCase: ObserveUnreadPushCountUseCase = ObserveUnreadPushCountUseCaseSpy(),
    badgeCountSpy: CompositionApplicationBadgeCountSpy = CompositionApplicationBadgeCountSpy()
) -> TestStoreOf<UnreadPushCountFeature> {
    let store = TestStore(initialState: UnreadPushCountFeature.State()) {
        UnreadPushCountFeature()
    } withDependencies: {
        $0.observeUnreadPushCountUseCase = unreadPushCountUseCase
        $0.setApplicationBadgeCount = { count in
            try await badgeCountSpy.setBadgeCount(count)
        }
    }
    store.exhaustivity = .off(showSkippedAssertions: false)
    return store
}

@MainActor
final class StateManagementReference {
    struct State: Equatable {
        var alert: AlertState<Never>?
        var unreadPushCount = 0
    }

    enum Action {
        case onAppear
        case selectedTabChanged(AppTab)
        case setUnreadPushCount(Int)
        case setAlert
    }

    enum Effect: Equatable {
        case observeUnreadPushCount
        case trackScreenView(String)
        case updateBadgeCount(Int)
    }

    private(set) var state = State()
    private var isObservingUnreadPushCount = false

    func reduce(_ action: Action) -> [Effect] {
        switch action {
        case .onAppear:
            if !isObservingUnreadPushCount {
                isObservingUnreadPushCount = true
                return [.observeUnreadPushCount]
            }
        case .selectedTabChanged(let tab):
            if let screenName = tab.analyticsScreenName {
                return [.trackScreenView(screenName)]
            }
        case .setUnreadPushCount(let count):
            state.unreadPushCount = count
            return [.updateBadgeCount(count)]
        case .setAlert:
            setAlert()
        }

        return []
    }

    private func setAlert() {
        state.alert = expectedCompositionErrorAlert()
    }
}

func expectedCompositionErrorAlert() -> AlertState<Never> {
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

final class ObserveUnreadPushCountUseCaseSpy: ObserveUnreadPushCountUseCase {
    var publisher: AnyPublisher<Int, Error>
    var error: Error?
    private(set) var observeCallCount = 0

    init(
        publisher: AnyPublisher<Int, Error> = Empty().eraseToAnyPublisher(),
        error: Error? = nil
    ) {
        self.publisher = publisher
        self.error = error
    }

    func observe() throws -> AnyPublisher<Int, Error> {
        observeCallCount += 1

        if let error {
            throw error
        }

        return publisher
    }
}

actor CompositionFetchAuthProvidersUseCaseSpy: FetchAuthProvidersUseCase {
    private var count = 0

    func execute() async throws -> (currentProvider: AuthProvider?, allProviders: [AuthProvider]) {
        count += 1
        return (nil, [])
    }

    func executeCallCount() -> Int {
        count
    }
}

final class CompositionTrackAnalyticsEventUseCaseSpy: TrackAnalyticsEventUseCase {
    private var events = [AnalyticsEvent]()

    var screenNames: [String] {
        events.compactMap { event in
            guard case .screenView(let screenName) = event else { return nil }
            return screenName
        }
    }

    func execute(_ event: AnalyticsEvent) {
        events.append(event)
    }
}

final class CompositionApplicationBadgeCountSpy: @unchecked Sendable {
    private(set) var counts = [Int]()
    var error: Error?

    func setBadgeCount(_ count: Int) async throws {
        counts.append(count)

        if let error {
            throw error
        }
    }
}

enum CompositionTestError: Error {
    case failure
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
