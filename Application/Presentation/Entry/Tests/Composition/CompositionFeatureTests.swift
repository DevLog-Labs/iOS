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
    @Test("CompositionFeature는 시작하면 unread count 관찰을 시작한다")
    func CompositionFeature는_시작하면_unread_count_관찰을_시작한다() async {
        let unreadPushCountUseCase = ObserveUnreadPushCountUseCaseSpy()
        let store = makeStore(unreadPushCountUseCase: unreadPushCountUseCase)

        await store.send(.start)
        await waitUntil {
            unreadPushCountUseCase.observeCallCount == 1
        }

        #expect(unreadPushCountUseCase.observeCallCount == 1)
    }

    @Test("CompositionFeature는 기존 상태관리처럼 notification 탭을 제외한 화면 전환을 추적한다")
    func CompositionFeature는_기존_상태관리처럼_notification_탭을_제외한_화면_전환을_추적한다() async {
        let reference = StateManagementReference()
        let trackAnalyticsEventUseCase = CompositionTrackAnalyticsEventUseCaseSpy()
        let store = makeStore(trackAnalyticsEventUseCase: trackAnalyticsEventUseCase)

        let expectedEffects = [
            reference.reduce(.onAppear),
            reference.reduce(.selectedTabChanged(.home)),
            reference.reduce(.selectedTabChanged(.today)),
            reference.reduce(.selectedTabChanged(.notification)),
            reference.reduce(.selectedTabChanged(.profile))
        ]
        await store.send(.start) {
            $0.openedTabs = [.home]
        }
        await waitUntil {
            trackAnalyticsEventUseCase.screenNames == ["home"]
        }
        // 이미 고른 탭을 다시 고르면 다시 추적하지 않음
        await store.send(.selectTab(.home))
        await store.send(.selectTab(.today)) {
            $0.selectedTab = .today
            $0.openedTabs = [.home, .today]
        }
        await waitUntil {
            trackAnalyticsEventUseCase.screenNames == ["home", "today"]
        }
        await store.send(.selectTab(.notification)) {
            $0.selectedTab = .notification
            $0.openedTabs = [.home, .today, .notification]
        }
        await store.send(.selectTab(.profile)) {
            $0.selectedTab = .profile
            $0.openedTabs = [.home, .today, .notification, .profile]
        }
        await waitUntil {
            trackAnalyticsEventUseCase.screenNames == ["home", "today", "profile"]
        }

        #expect(expectedEffects == [
            [.observeUnreadPushCount],
            [.trackScreenView("home")],
            [.trackScreenView("today")],
            [],
            [.trackScreenView("profile")]
        ])
        #expect(trackAnalyticsEventUseCase.screenNames == ["home", "today", "profile"])
    }

    @Test("CompositionFeature는 사이드바 항목을 고르면 작성 화면을 그린 탭이라도 그 탭을 선택한다")
    func CompositionFeature는_사이드바_항목을_고르면_작성_화면을_그린_탭이라도_그_탭을_선택한다() async {
        let store = makeStore()

        await store.send(.sideBar(.paneEditingChanged(.profile, true)))
        await store.send(.sideBar(.tapItem(.profile, .open(.profile))))

        #expect(store.state.selectedTab == .profile)
        #expect(store.state.sideBar.requests[.profile] == nil)
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
