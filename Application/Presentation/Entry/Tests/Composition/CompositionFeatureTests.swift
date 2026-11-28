//
//  CompositionFeatureTests.swift
//  EntryTests
//
//  Created by opfic on 6/16/26.
//

import Core
import PresentationShared
import Foundation
import Testing
@testable import Entry
@testable import ProfileTab

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

    @Test("CompositionFeature는 프로필 칸에 작성 화면을 그린 동안에도 설정을 창 전체에 표시하고 닫으면 내린다")
    func CompositionFeature는_프로필_칸에_작성_화면을_그린_동안에도_설정을_창_전체에_표시하고_닫으면_내린다() async {
        let store = TestStore(initialState: CompositionFeature.State()) {
            CompositionFeature()
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.sideBar(.paneEditingChanged(.profile, true)))
        await store.send(.sideBar(.tapSettings))
        await store.receive(.settings(.open))

        #expect(store.state.isSettingsPresented)
        #expect(store.state.settings.screen == .detail)
        #expect(store.state.settings.selectedRoute == .theme)
        // 설정을 여는 것만으로 프로필 탭을 만들지 않음
        #expect(store.state.openedTabs.isEmpty)

        await store.send(.settings(.close))

        #expect(!store.state.isSettingsPresented)
        #expect(store.state.settings.screen == nil)
    }

    @Test("CompositionFeature는 사이드바 항목을 고르면 작성 화면을 그린 탭이라도 그 탭을 선택한다")
    func CompositionFeature는_사이드바_항목을_고르면_작성_화면을_그린_탭이라도_그_탭을_선택한다() async {
        let store = makeStore()

        await store.send(.sideBar(.paneEditingChanged(.profile, true)))
        await store.send(.sideBar(.tapItem(.profile, .open(.profile))))

        #expect(store.state.selectedTab == .profile)
        #expect(store.state.sideBar.requests[.profile] == nil)
    }

    @Test("CompositionFeature는 창이 좁아지면 설정을 이어서 표시할 프로필 탭을 유지한다")
    func CompositionFeature는_창이_좁아지면_설정을_이어서_표시할_프로필_탭을_유지한다() async {
        let store = TestStore(initialState: CompositionFeature.State()) {
            CompositionFeature()
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.settings(.open))
        await store.send(.settings(.select(.pushNotification)))
        await store.send(.view(.sideBarVisibilityChanged(false)))

        #expect(store.state.isSettingsPresented)
        #expect(store.state.settings.screen == .detail)
        #expect(store.state.settings.selectedRoute == .pushNotification)
        #expect(store.state.openedTabs == [.profile])
    }

    @Test(
        "CompositionFeature는 창이 넓어지면 프로필 탭에서 보던 설정만 창 전체에 이어서 표시한다",
        arguments: [AppTab.profile, .home]
    )
    func CompositionFeature는_창이_넓어지면_프로필_탭에서_보던_설정만_창_전체에_이어서_표시한다(tab: AppTab) async {
        let store = makeStore()

        await store.send(.settings(.select(.pushNotification)))
        await store.send(.selectTab(tab))
        await store.send(.view(.sideBarVisibilityChanged(true)))

        #expect(store.state.isSettingsPresented == (tab == .profile))
        #expect(store.state.settings.screen == (tab == .profile ? .detail : nil))
        #expect(store.state.settings.selectedRoute == .pushNotification)
    }

    @Test("CompositionFeature는 좁아진 창에 이어진 설정을 닫으면 프로필 탭을 선택한다")
    func CompositionFeature는_좁아진_창에_이어진_설정을_닫으면_프로필_탭을_선택한다() async {
        let store = makeStore()

        await store.send(.view(.sideBarVisibilityChanged(true)))
        await store.send(.settings(.open))
        await store.send(.view(.sideBarVisibilityChanged(false)))
        await store.send(.settings(.binding(.set(\.pushedRoute, nil))))

        #expect(store.state.isSettingsPresented)
        #expect(store.state.selectedTab == .home)

        await store.send(.settings(.binding(.set(\.isListPushed, false))))

        #expect(!store.state.isSettingsPresented)
        #expect(store.state.selectedTab == .profile)
    }

    @Test("CompositionFeature는 좁아진 창에 설정이 이어져 있어도 이미 선택한 탭을 다시 고르면 그 탭을 표시한다")
    func CompositionFeature는_좁아진_창에_설정이_이어져_있어도_이미_선택한_탭을_다시_고르면_그_탭을_표시한다() async {
        let store = makeStore()

        await store.send(.view(.sideBarVisibilityChanged(true)))
        await store.send(.settings(.open))
        await store.send(.selectTab(.home))

        // 사이드바가 있는 창의 설정은 탭을 골라도 유지
        #expect(store.state.isSettingsPresented)

        await store.send(.view(.sideBarVisibilityChanged(false)))
        await store.send(.selectTab(.home))

        #expect(!store.state.isSettingsPresented)
        #expect(store.state.settings.screen == .detail)
        #expect(store.state.settings.selectedRoute == .theme)
    }

    @Test("CompositionFeature는 창 폭이 바뀔 때는 다시 조회하지 않고 계정 화면에 들어올 때만 조회한다")
    func CompositionFeature는_창_폭이_바뀔_때는_다시_조회하지_않고_계정_화면에_들어올_때만_조회한다() async {
        let fetchUseCase = CompositionFetchAuthProvidersUseCaseSpy()
        let store = TestStore(initialState: CompositionFeature.State()) {
            CompositionFeature()
        } withDependencies: {
            $0.fetchAuthProvidersUseCase = fetchUseCase
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.view(.sideBarVisibilityChanged(true)))
        await store.send(.settings(.open))
        await store.send(.settings(.select(.account)))
        await store.receive(.settings(.account(.open)))
        await store.receive(.settings(.account(.setProviders(currentProvider: nil, allProviders: []))))

        await store.send(.view(.sideBarVisibilityChanged(false)))
        await store.send(.view(.sideBarVisibilityChanged(true)))
        await store.send(.settings(.select(.theme)))

        #expect(await fetchUseCase.executeCallCount() == 1)

        await store.send(.settings(.select(.account)))
        await store.receive(.settings(.account(.open)))
        await store.receive(.settings(.account(.setProviders(currentProvider: nil, allProviders: []))))

        #expect(await fetchUseCase.executeCallCount() == 2)
    }

    @Test("CompositionFeature는 설정 목록까지 돌아온 뒤 창을 넓혀 계정 화면이 나오면 한 번 조회하고 다시 좁혀도 계정 화면을 이어서 표시한다")
    func CompositionFeature는_설정_목록까지_돌아온_뒤_창을_넓혀_계정_화면이_나오면_한_번_조회하고_다시_좁혀도_계정_화면을_이어서_표시한다() async {
        let fetchUseCase = CompositionFetchAuthProvidersUseCaseSpy()
        var state = CompositionFeature.State()
        state.selectedTab = .profile
        state.settings.selectedRoute = .account
        state.settings.screen = .list
        let store = TestStore(initialState: state) {
            CompositionFeature()
        } withDependencies: {
            $0.fetchAuthProvidersUseCase = fetchUseCase
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.view(.sideBarVisibilityChanged(true)))
        await store.receive(.settings(.account(.open)))
        await store.receive(.settings(.account(.setProviders(currentProvider: nil, allProviders: []))))

        #expect(store.state.settings.screen == .detail)

        await store.send(.settings(.account(.setAlert(.signOut))))
        await store.send(.view(.sideBarVisibilityChanged(false)))
        await store.send(.view(.sideBarVisibilityChanged(true)))

        // 폭이 바뀌어도 계정 화면이 이어져 다시 조회하지 않고 알림창 유지
        #expect(store.state.isAccountOpen)
        #expect(store.state.settings.account.alert != nil)
        #expect(await fetchUseCase.executeCallCount() == 1)
    }

    @Test("CompositionFeature는 창 폭이 바뀔 때는 계정 화면의 창 정보를 유지하고 계정 화면을 나가면 지운다")
    func CompositionFeature는_창_폭이_바뀔_때는_계정_화면의_창_정보를_유지하고_계정_화면을_나가면_지운다() async {
        let context = AuthPresentationContext(identifier: "scene")
        let store = TestStore(initialState: CompositionFeature.State()) {
            CompositionFeature()
        } withDependencies: {
            $0.fetchAuthProvidersUseCase = CompositionFetchAuthProvidersUseCaseSpy()
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.view(.sideBarVisibilityChanged(true)))
        await store.send(.settings(.open))
        await store.send(.settings(.select(.account)))
        await store.receive(.settings(.account(.open)))
        await store.send(.settings(.account(.setPresentationContext(context))))
        await store.send(.view(.sideBarVisibilityChanged(false)))
        await store.send(.view(.sideBarVisibilityChanged(true)))

        #expect(store.state.settings.account.presentationContext == context)

        await store.send(.settings(.select(.theme)))
        await store.receive(.settings(.account(.setPresentationContext(nil))))

        #expect(store.state.settings.account.presentationContext == nil)
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
