//
//  CompositionFeatureTests.swift
//  EntryTests
//
//  Created by opfic on 6/16/26.
//

import PresentationShared
import Foundation
import Testing
@testable import Entry

@MainActor
struct CompositionFeatureTests {
    @Test("CompositionFeature는 기존 상태관리처럼 최초 onAppear에서만 unread count 관찰을 시작한다")
    func CompositionFeature는_기존_상태관리처럼_최초_onAppear에서만_unread_count_관찰을_시작한다() async {
        let reference = StateManagementReference()
        let unreadPushCountUseCase = ObserveUnreadPushCountUseCaseSpy()
        let store = makeStore(unreadPushCountUseCase: unreadPushCountUseCase)

        let firstEffects = reference.reduce(.onAppear)
        let secondEffects = reference.reduce(.onAppear)
        await store.send(.view(.onAppear)) {
            $0.hasAppeared = true
        }
        await store.send(.view(.onAppear))
        await waitUntil {
            unreadPushCountUseCase.observeCallCount == 1
        }

        #expect(firstEffects == [.observeUnreadPushCount])
        #expect(secondEffects.isEmpty)
        #expect(unreadPushCountUseCase.observeCallCount == 1)
    }

    @Test("CompositionFeature는 기존 상태관리처럼 notification 탭을 제외한 화면 전환을 추적한다")
    func CompositionFeature는_기존_상태관리처럼_notification_탭을_제외한_화면_전환을_추적한다() async {
        let reference = StateManagementReference()
        let trackAnalyticsEventUseCase = CompositionTrackAnalyticsEventUseCaseSpy()
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

    @Test("CompositionFeature는 화면 회전 때 오는 높이 0인 키보드 표시 알림을 무시한다")
    func CompositionFeature는_화면_회전_때_오는_높이_0인_키보드_표시_알림을_무시한다() async {
        let store = makeStore()

        await store.send(.store(.keyboardChanged(.willShow(height: 0))))

        #expect(!store.state.isKeyboardVisible)

        await store.send(.store(.keyboardChanged(.willShow(height: 300)))) {
            $0.isKeyboardVisible = true
        }
        await store.send(.store(.keyboardChanged(.willHide))) {
            $0.isKeyboardVisible = false
        }
    }
}
