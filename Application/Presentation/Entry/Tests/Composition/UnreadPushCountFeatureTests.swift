//
//  UnreadPushCountFeatureTests.swift
//  EntryTests
//
//  Created by opfic on 11/25/26.
//

import Combine
import PresentationShared
import Testing
@testable import Entry

@MainActor
struct UnreadPushCountFeatureTests {
    @Test("UnreadPushCountFeature는 기존 상태관리처럼 unread count를 갱신하고 badge 갱신을 요청한다")
    func UnreadPushCountFeature는_기존_상태관리처럼_unread_count를_갱신하고_badge_갱신을_요청한다() async {
        let reference = StateManagementReference()
        let badgeCountSpy = CompositionApplicationBadgeCountSpy()
        let store = makeUnreadPushCountStore(badgeCountSpy: badgeCountSpy)

        let effects = reference.reduce(.setUnreadPushCount(7))
        await store.send(.setCount(7)) {
            $0.count = reference.state.unreadPushCount
        }
        await waitUntil {
            badgeCountSpy.counts == [7]
        }

        #expect(reference.state.unreadPushCount == 7)
        #expect(effects == [.updateBadgeCount(7)])
        #expect(badgeCountSpy.counts == [7])
    }

    @Test("UnreadPushCountFeature는 기존 상태관리처럼 alert 표시 여부와 문구를 함께 갱신한다")
    func UnreadPushCountFeature는_기존_상태관리처럼_alert_state를_갱신한다() async {
        let reference = StateManagementReference()
        let store = makeUnreadPushCountStore()

        let presentEffects = reference.reduce(.setAlert)
        await store.send(.setAlert) {
            $0.alert = reference.state.alert
        }

        await store.send(.alert(.dismiss)) {
            $0.alert = nil
        }

        #expect(presentEffects.isEmpty)
        #expect(reference.state.alert == expectedCompositionErrorAlert())
    }

    @Test("UnreadPushCountFeature는 기존 상태관리처럼 unread count 관찰 시작 실패 시 alert를 표시한다")
    func UnreadPushCountFeature는_기존_상태관리처럼_unread_count_관찰_시작_실패_시_alert를_표시한다() async {
        let reference = StateManagementReference()
        let unreadPushCountUseCase = ObserveUnreadPushCountUseCaseSpy(error: CompositionTestError.failure)
        let store = makeUnreadPushCountStore(unreadPushCountUseCase: unreadPushCountUseCase)

        _ = reference.reduce(.onAppear)
        _ = reference.reduce(.setAlert)
        await store.send(.startObserving)
        await store.receive(.setAlert) {
            $0.alert = reference.state.alert
        }
    }

    @Test("UnreadPushCountFeature는 unread count 관찰 값을 기존 상태관리의 setUnreadPushCount 상태 변화로 반영한다")
    func UnreadPushCountFeature는_unread_count_관찰_값을_기존_상태관리의_setUnreadPushCount_상태_변화로_반영한다() async {
        let reference = StateManagementReference()
        let subject = PassthroughSubject<Int, Error>()
        let unreadPushCountUseCase = ObserveUnreadPushCountUseCaseSpy(publisher: subject.eraseToAnyPublisher())
        let badgeCountSpy = CompositionApplicationBadgeCountSpy()
        let store = makeUnreadPushCountStore(
            unreadPushCountUseCase: unreadPushCountUseCase,
            badgeCountSpy: badgeCountSpy
        )

        _ = reference.reduce(.onAppear)
        await store.send(.startObserving)

        let effects = reference.reduce(.setUnreadPushCount(3))
        subject.send(3)
        await store.receive(.setCount(3)) {
            $0.count = reference.state.unreadPushCount
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
