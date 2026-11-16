//
//  MainFeatureTests.swift
//  EntryTests
//
//  Created by opfic on 6/16/26.
//

import Combine
import PresentationShared
import Domain
import Foundation
import Testing
@testable import Entry

@MainActor
struct MainFeatureTests {
    @Test("MainFeature는 기존 Main 상태관리처럼 최초 onAppear에서만 unread count 관찰을 시작한다")
    func MainFeature는_기존_Main_상태관리처럼_최초_onAppear에서만_unread_count_관찰을_시작한다() async {
        let reference = MainStateManagementReference()
        let unreadPushCountUseCase = MainObserveUnreadPushCountUseCaseSpy()
        let store = makeStore(unreadPushCountUseCase: unreadPushCountUseCase)

        let firstEffects = reference.reduce(.onAppear)
        let secondEffects = reference.reduce(.onAppear)
        await store.send(.view(.onAppear)) {
            $0.isObservingUnreadPushCount = true
        }
        await store.send(.view(.onAppear))

        #expect(firstEffects == [.observeUnreadPushCount])
        #expect(secondEffects.isEmpty)
        #expect(unreadPushCountUseCase.observeCallCount == 1)
    }

    @Test("MainFeature는 기존 Main 상태관리처럼 notification 탭을 제외한 화면 전환을 추적한다")
    func MainFeature는_기존_Main_상태관리처럼_notification_탭을_제외한_화면_전환을_추적한다() async {
        let reference = MainStateManagementReference()
        let trackAnalyticsEventUseCase = MainTrackAnalyticsEventUseCaseSpy()
        let store = makeStore(trackAnalyticsEventUseCase: trackAnalyticsEventUseCase)

        let expectedEffects = [
            reference.reduce(.selectedTabChanged(.home)),
            reference.reduce(.selectedTabChanged(.today)),
            reference.reduce(.selectedTabChanged(.notification)),
            reference.reduce(.selectedTabChanged(.profile))
        ]
        await store.send(.view(.selectedTabChanged(.home))) {
            $0.openedTabs = [.home]
        }
        await store.send(.view(.selectedTabChanged(.today))) {
            $0.openedTabs = [.home, .today]
        }
        await store.send(.view(.selectedTabChanged(.notification))) {
            $0.openedTabs = [.home, .today, .notification]
        }
        await store.send(.view(.selectedTabChanged(.profile))) {
            $0.openedTabs = [.home, .today, .notification, .profile]
        }
        await waitUntil {
            trackAnalyticsEventUseCase.screenNames == ["home", "today", "profile"]
        }

        #expect(expectedEffects == [
            [.trackScreenView("home")],
            [.trackScreenView("today")],
            [],
            [.trackScreenView("profile")]
        ])
        #expect(trackAnalyticsEventUseCase.screenNames == ["home", "today", "profile"])
    }

    @Test("MainFeature는 기존 Main 상태관리처럼 unread count를 갱신하고 badge 갱신을 요청한다")
    func MainFeature는_기존_Main_상태관리처럼_unread_count를_갱신하고_badge_갱신을_요청한다() async {
        let reference = MainStateManagementReference()
        let badgeCountSpy = MainApplicationBadgeCountSpy()
        let store = makeStore(badgeCountSpy: badgeCountSpy)

        let effects = reference.reduce(.setUnreadPushCount(7))
        await store.send(.store(.setUnreadPushCount(7))) {
            $0.unreadPushCount = reference.state.unreadPushCount
        }
        await waitUntil {
            badgeCountSpy.counts == [7]
        }

        #expect(reference.state.unreadPushCount == 7)
        #expect(effects == [.updateBadgeCount(7)])
        #expect(badgeCountSpy.counts == [7])
    }

    @Test("MainFeature는 기존 Main 상태관리처럼 alert 표시 여부와 문구를 함께 갱신한다")
    func MainFeature는_기존_Main_상태관리처럼_alert_state를_갱신한다() async {
        let reference = MainStateManagementReference()
        let store = makeStore()

        let presentEffects = reference.reduce(.setAlert)
        await store.send(.store(.setAlert)) {
            $0.alert = reference.state.alert
        }

        await store.send(.alert(.dismiss)) {
            $0.alert = nil
        }

        #expect(presentEffects.isEmpty)
        #expect(reference.state.alert == expectedMainErrorAlert())
    }

    @Test("MainFeature는 기존 Main 상태관리처럼 unread count 관찰 시작 실패 시 alert를 표시한다")
    func MainFeature는_기존_Main_상태관리처럼_unread_count_관찰_시작_실패_시_alert를_표시한다() async {
        let reference = MainStateManagementReference()
        let unreadPushCountUseCase = MainObserveUnreadPushCountUseCaseSpy(error: MainTestError.failure)
        let store = makeStore(unreadPushCountUseCase: unreadPushCountUseCase)

        _ = reference.reduce(.onAppear)
        _ = reference.reduce(.setAlert)
        await store.send(.view(.onAppear)) {
            $0.isObservingUnreadPushCount = true
        }
        await store.receive(.store(.setAlert)) {
            $0.alert = reference.state.alert
        }
    }

    @Test("MainFeature는 다른 경로로 하위 항목에 들어오면 그 묶음을 펼치고 묶음을 접어도 위치를 유지한다")
    func MainFeature는_다른_경로로_하위_항목에_들어오면_그_묶음을_펼치고_묶음을_접어도_위치를_유지한다() async {
        let store = makeStore()

        await store.send(.view(.sideBarLocationChanged(.home, .todoCategory("issue")))) {
            $0.sideBarLocations[.home] = .todoCategory("issue")
            $0.expandedSideBarGroups = [.todo]
        }
        await store.send(.view(.tapSideBarGroup(.todo))) {
            $0.expandedSideBarGroups = []
        }
        #expect(store.state.sideBarLocations[.home] == .todoCategory("issue"))
        await store.send(.view(.sideBarLocationChanged(.home, .developmentGoal("goal")))) {
            $0.sideBarLocations[.home] = .developmentGoal("goal")
            $0.expandedSideBarGroups = [.developmentGoal]
        }
    }

    @Test("MainFeature는 사라지는 화면이 다른 화면이 고른 세부 정보 사이드바 대상을 지우지 않게 한다")
    func MainFeature는_사라지는_화면이_다른_화면이_고른_세부_정보_사이드바_대상을_지우지_않게_한다() async {
        let store = makeStore()
        let goal = UUID()
        let category = UUID()

        await store.send(.view(.detailSideBarTargetChanged(.home, .hosted, owner: goal)))
        await store.send(.view(.detailSideBarTargetChanged(.home, .hosted, owner: category)))
        await store.send(.view(.detailSideBarOwnerRemoved(.home, owner: goal)))

        #expect(store.state.detailSideBarTargets[.home] == .hosted)

        await store.send(.view(.detailSideBarOwnerRemoved(.home, owner: category)))

        #expect(store.state.detailSideBarTargets[.home] == nil)
    }

    @Test("MainFeature는 위 화면이 사라지면 아래 화면이 고른 세부 정보 사이드바 대상을 다시 표시한다")
    func MainFeature는_위_화면이_사라지면_아래_화면이_고른_세부_정보_사이드바_대상을_다시_표시한다() async {
        let store = makeStore()
        let list = UUID()
        let editor = UUID()

        await store.send(.view(.detailSideBarTargetChanged(.home, .todo(id: "todo", isEditable: true), owner: list)))
        await store.send(.view(.detailSideBarTargetChanged(.home, .hosted, owner: editor)))
        await store.send(.view(.detailSideBarTargetChanged(.home, .todo(id: "other", isEditable: true), owner: list)))

        #expect(store.state.detailSideBarTargets[.home] == .hosted)

        await store.send(.view(.detailSideBarOwnerRemoved(.home, owner: editor)))

        #expect(store.state.detailSideBarTargets[.home] == .todo(id: "other", isEditable: true))
    }

    @Test("MainFeature는 먼저 나타난 화면이 나중에 대상을 골라도 나중에 나타난 화면의 대상을 유지한다")
    func MainFeature는_먼저_나타난_화면이_나중에_대상을_골라도_나중에_나타난_화면의_대상을_유지한다() async {
        let store = makeStore()
        let list = UUID()
        let editor = UUID()

        await store.send(.view(.detailSideBarTargetChanged(.home, nil, owner: list)))
        await store.send(.view(.detailSideBarTargetChanged(.home, .hosted, owner: editor)))
        await store.send(.view(.detailSideBarTargetChanged(.home, .todo(id: "todo", isEditable: true), owner: list)))

        #expect(store.state.detailSideBarTargets[.home] == .hosted)

        await store.send(.view(.detailSideBarOwnerRemoved(.home, owner: editor)))

        #expect(store.state.detailSideBarTargets[.home] == .todo(id: "todo", isEditable: true))
    }

    @Test("MainFeature는 unread count 관찰 값을 기존 Main 상태관리의 setUnreadPushCount 상태 변화로 반영한다")
    func MainFeature는_unread_count_관찰_값을_기존_Main_상태관리의_setUnreadPushCount_상태_변화로_반영한다() async {
        let reference = MainStateManagementReference()
        let subject = PassthroughSubject<Int, Error>()
        let unreadPushCountUseCase = MainObserveUnreadPushCountUseCaseSpy(publisher: subject.eraseToAnyPublisher())
        let badgeCountSpy = MainApplicationBadgeCountSpy()
        let store = makeStore(
            unreadPushCountUseCase: unreadPushCountUseCase,
            badgeCountSpy: badgeCountSpy
        )

        _ = reference.reduce(.onAppear)
        await store.send(.view(.onAppear)) {
            $0.isObservingUnreadPushCount = true
        }

        let effects = reference.reduce(.setUnreadPushCount(3))
        subject.send(3)
        await store.receive(.store(.setUnreadPushCount(3))) {
            $0.unreadPushCount = reference.state.unreadPushCount
        }
        await waitUntil {
            badgeCountSpy.counts == [3]
        }

        #expect(reference.state.unreadPushCount == 3)
        #expect(effects == [.updateBadgeCount(3)])
        #expect(badgeCountSpy.counts == [3])
        subject.send(completion: .finished)
    }
}

@MainActor
private func makeStore(
    unreadPushCountUseCase: ObserveUnreadPushCountUseCase = MainObserveUnreadPushCountUseCaseSpy(),
    trackAnalyticsEventUseCase: TrackAnalyticsEventUseCase = MainTrackAnalyticsEventUseCaseSpy(),
    badgeCountSpy: MainApplicationBadgeCountSpy = MainApplicationBadgeCountSpy()
) -> TestStoreOf<MainFeature> {
    let store = TestStore(initialState: MainFeature.State()) {
        MainFeature()
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
private final class MainStateManagementReference {
    struct State: Equatable {
        var alert: AlertState<Never>?
        var unreadPushCount = 0
    }

    enum Action {
        case onAppear
        case selectedTabChanged(MainTab)
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
        state.alert = expectedMainErrorAlert()
    }
}

private func expectedMainErrorAlert() -> AlertState<Never> {
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

private final class MainObserveUnreadPushCountUseCaseSpy: ObserveUnreadPushCountUseCase {
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

private final class MainTrackAnalyticsEventUseCaseSpy: TrackAnalyticsEventUseCase {
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

private final class MainApplicationBadgeCountSpy: @unchecked Sendable {
    private(set) var counts = [Int]()
    var error: Error?

    func setBadgeCount(_ count: Int) async throws {
        counts.append(count)

        if let error {
            throw error
        }
    }
}

private enum MainTestError: Error {
    case failure
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
