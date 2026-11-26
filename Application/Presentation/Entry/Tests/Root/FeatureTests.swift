//
//  FeatureTests.swift
//  EntryTests
//
//  Created by opfic on 6/17/26.
//

import Core
import Foundation
import PresentationShared
import Testing
@testable import Entry

@MainActor
struct FeatureTests {
    @Test("Feature networkStatusChanged는 기존 Root 상태관리처럼 alert 문구와 표시 상태를 갱신한다")
    func RootFeature_networkStatusChanged는_기존_Root_상태관리처럼_alert_문구와_표시_상태를_갱신한다() async {
        let adapter = RootStoreTestAdapter()

        await verifyNetworkDisconnectedAlert(adapter: adapter)
    }

    @Test("Feature setAlert(false)는 기존 Root 상태관리처럼 alert 문구를 유지한 채 표시 상태를 해제한다")
    func RootFeature_setAlert_false는_기존_Root_상태관리처럼_alert_문구를_유지한_채_표시_상태를_해제한다() async {
        let adapter = RootStoreTestAdapter()

        await verifySetAlert(adapter: adapter)
    }

    @Test("Feature setTheme은 기존 Root 상태관리처럼 테마 상태를 갱신한다")
    func RootFeature_setTheme은_기존_Root_상태관리처럼_테마_상태를_갱신한다() async {
        let adapter = RootStoreTestAdapter()

        await verifyThemeUpdate(adapter: adapter)
    }

    @Test("Feature didLogined(false)는 기존 Root 상태관리처럼 signIn 상태를 갱신하고 login 화면 추적을 요청한다")
    func RootFeature_didLogined_false는_기존_Root_상태관리처럼_signIn_상태를_갱신하고_login_화면_추적을_요청한다() async {
        let trackSpy = RootTrackAnalyticsEventUseCaseSpy()
        let adapter = RootStoreTestAdapter(trackAnalyticsEventUseCase: trackSpy)

        await verifyDidLoginedFalse(adapter: adapter, trackAnalyticsEventUseCaseSpy: trackSpy)
    }

    @Test("Feature didLogined(false)는 앱 badge 초기화를 요청한다")
    func RootFeature_didLogined_false는_앱_badge_초기화를_요청한다() async {
        let badgeSpy = RootApplicationBadgeCountSpy()
        let adapter = RootStoreTestAdapter(badgeCountSpy: badgeSpy)

        await adapter.didLogined(false)
        await waitUntil {
            badgeSpy.counts == [0]
        }

        #expect(badgeSpy.counts == [0])
    }

    @Test("Feature didLogined(true)는 기존 Root 상태관리처럼 signIn 상태를 true로 갱신하고 selectedTab을 home으로 되돌린다")
    func RootFeature_didLogined_true는_기존_Root_상태관리처럼_signIn_상태를_true로_갱신하고_selectedTab을_home으로_되돌린다() async {
        let trackSpy = RootTrackAnalyticsEventUseCaseSpy()
        let adapter = RootStoreTestAdapter(trackAnalyticsEventUseCase: trackSpy)

        await verifyDidLoginedTrue(adapter: adapter, trackAnalyticsEventUseCaseSpy: trackSpy)
    }

    @Test("Feature onAppear는 기존 Root 상태관리처럼 session, network, theme 관찰을 한 번만 시작한다")
    func RootFeature_onAppear는_기존_Root_상태관리처럼_session_network_theme_관찰을_한_번만_시작한다() async {
        let sessionSpy = ObserveAuthSessionUseCaseSpy(currentValue: true)
        let networkSpy = RootObserveNetworkConnectivityUseCaseSpy(currentValue: true)
        let themeSpy = RootObserveSystemThemeUseCaseSpy(currentValue: .automatic)
        let adapter = RootStoreTestAdapter(
            sessionUseCase: sessionSpy,
            networkConnectivityUseCase: networkSpy,
            systemThemeUseCase: themeSpy
        )

        await adapter.onAppear()
        await adapter.onAppear()

        #expect(sessionSpy.observeCallCount == 1)
        #expect(networkSpy.observeCallCount == 1)
        #expect(themeSpy.observeCallCount == 1)
    }

    @Test("Feature onAppear는 기존 Root 상태관리처럼 초기 publisher 값으로 signIn, network, theme 상태를 반영한다")
    func RootFeature_onAppear는_기존_Root_상태관리처럼_초기_publisher_값으로_signIn_network_theme_상태를_반영한다() async {
        let adapter = RootStoreTestAdapter(
            sessionUseCase: ObserveAuthSessionUseCaseSpy(currentValue: false),
            networkConnectivityUseCase: RootObserveNetworkConnectivityUseCaseSpy(currentValue: false),
            systemThemeUseCase: RootObserveSystemThemeUseCaseSpy(currentValue: .dark)
        )

        await verifyObservedInitialValues(adapter: adapter)
    }

    @Test("Feature onAppear는 앱 badge 초기화를 요청한다")
    func RootFeature_onAppear는_앱_badge_초기화를_요청한다() async {
        let badgeSpy = RootApplicationBadgeCountSpy()
        let adapter = RootStoreTestAdapter(badgeCountSpy: badgeSpy)

        await adapter.onAppear()
        await adapter.onAppear()
        await waitUntil {
            badgeSpy.counts == [0, 0]
        }

        #expect(badgeSpy.counts == [0, 0])
    }

    @Test("Feature onAppear는 로그인 상태와 무관하게 업데이트를 한 번만 확인한다")
    func RootFeature_onAppear는_로그인_상태와_무관하게_업데이트를_한_번만_확인한다() async {
        let checkSpy = RootCheckAppUpdateUseCaseSpy()
        let adapter = RootStoreTestAdapter(
            sessionUseCase: ObserveAuthSessionUseCaseSpy(currentValue: false),
            checkAppUpdateUseCase: checkSpy
        )

        await adapter.onAppear()
        await adapter.onAppear()

        #expect(await checkSpy.executeCallCount() == 1)
    }

    @Test("업데이트 확인에 실패하면 업데이트 알림을 표시하지 않는다")
    func 업데이트_확인에_실패하면_업데이트_알림을_표시하지_않는다() async {
        let checkSpy = RootCheckAppUpdateUseCaseSpy(
            result: .failure(CheckAppUpdateUseCaseTestError.fetchFailed)
        )
        let adapter = RootStoreTestAdapter(checkAppUpdateUseCase: checkSpy)

        await adapter.onAppear()

        #expect(await checkSpy.executeCallCount() == 1)
        #expect(adapter.snapshot.alertTitle == nil)
        #expect(adapter.snapshot.alertMessage == nil)
    }

    @Test("필수 업데이트 알림은 네트워크 연결 알림보다 우선한다")
    func 필수_업데이트_알림은_네트워크_연결_알림보다_우선한다() async {
        let adapter = RootStoreTestAdapter(
            networkConnectivityUseCase: RootObserveNetworkConnectivityUseCaseSpy(currentValue: false),
            checkAppUpdateUseCase: RootCheckAppUpdateUseCaseSpy(result: .success(true))
        )

        await adapter.onAppear()

        #expect(
            adapter.snapshot.alertTitle
                == String(localized: "root_app_update_title", bundle: PresentationResources.bundle)
        )
        #expect(
            adapter.snapshot.alertMessage
                == String(localized: "root_app_update_message", bundle: PresentationResources.bundle)
        )
    }

    @Test("업데이트 버튼은 App Store 열기를 요청한다")
    func 업데이트_버튼은_App_Store_열기를_요청한다() async throws {
        let appStoreURL = try #require(URL(string: "https://apps.apple.com/us/app/devlog/id6760288611"))
        let openSpy = RootOpenURLSpy()
        let adapter = RootStoreTestAdapter(
            checkAppUpdateUseCase: RootCheckAppUpdateUseCaseSpy(result: .success(true)),
            appStoreURL: appStoreURL,
            openURLSpy: openSpy
        )

        await adapter.onAppear()
        await adapter.tapUpdateButton()
        await waitUntil {
            await openSpy.openCallCount() == 1
        }

        #expect(await openSpy.openCallCount() == 1)
        #expect(await openSpy.openedURLs() == [appStoreURL])
    }

    @Test("RootFeature는 TodoDetail sheet 표시와 해제를 store state로 관리한다")
    func RootFeature는_TodoDetail_sheet_표시와_해제를_store_state로_관리한다() async {
        let adapter = RootStoreTestAdapter()

        await verifyTodoDetailSheetPresentation(adapter: adapter)
    }

    @Test("RootFeature는 로그인 확인 전 위젯 경로를 보관하고 확인 뒤 적용한다")
    func RootFeature는_로그인_확인_전_위젯_경로를_보관하고_확인_뒤_적용한다() async {
        let adapter = RootStoreTestAdapter()

        await verifyWidgetRouteOpensWhenSignedIn(adapter: adapter)
    }

    @Test("RootFeature는 로그인 확인 전 들어온 위젯 Todo 경로를 로그인 확인 뒤 현재 탭의 시트로 연다")
    func RootFeature는_로그인_확인_전_들어온_위젯_Todo_경로를_로그인_확인_뒤_현재_탭의_시트로_연다() async {
        let adapter = RootStoreTestAdapter()

        await adapter.openWidgetRoute(.todayTodo("todo-1"))
        #expect(adapter.widgetRoute == .todayTodo("todo-1"))

        await adapter.didLogined(true)
        #expect(adapter.snapshot.selectedTab == .home)
        #expect(adapter.widgetRoute == .todayTodo("todo-1"))
        #expect(adapter.sheetTodoId == "todo-1")
    }

    @Test("RootFeature는 로그아웃 상태에서 들어온 위젯 경로를 로그인한 뒤에도 적용하지 않는다")
    func RootFeature는_로그아웃_상태에서_들어온_위젯_경로를_로그인한_뒤에도_적용하지_않는다() async {
        let adapter = RootStoreTestAdapter()

        await adapter.didLogined(false)
        await adapter.openWidgetRoute(.todayTodo("todo-1"))
        #expect(adapter.widgetRoute == nil)

        await adapter.didLogined(true)
        #expect(adapter.snapshot.selectedTab == .home)
        #expect(adapter.sheetTodoId == nil)
    }

    @Test("로그아웃하면 적용된 위젯 경로를 지운다")
    func 로그아웃하면_적용된_위젯_경로를_지운다() async {
        let adapter = RootStoreTestAdapter()

        await adapter.didLogined(true)
        await adapter.openWidgetRoute(.tab(.today))
        await adapter.didLogined(false)

        #expect(adapter.widgetRoute == nil)
    }

    @Test("위젯 Todo 시트는 현재 선택된 탭을 유지한다")
    func 위젯_Todo_시트는_현재_선택된_탭을_유지한다() async {
        let adapter = RootStoreTestAdapter()

        await adapter.didLogined(true)
        await adapter.selectTab(.profile)
        await adapter.openWidgetRoute(.todayTodo("todo-2"))

        #expect(adapter.snapshot.selectedTab == .profile)
        #expect(adapter.sheetTodoId == "todo-2")
    }

    @Test("위젯 상단 경로는 Today 탭만 선택한다")
    func 위젯_상단_경로는_Today_탭만_선택한다() async {
        let adapter = RootStoreTestAdapter()

        await adapter.didLogined(true)
        await adapter.selectTab(.profile)
        await adapter.openWidgetRoute(.tab(.today))

        #expect(adapter.snapshot.selectedTab == .today)
        #expect(adapter.sheetTodoId == nil)

        await adapter.openWidgetRoute(.todayTodo("todo-1"))
        #expect(adapter.snapshot.selectedTab == .today)
        #expect(adapter.sheetTodoId == "todo-1")
    }

    @Test("로그인하면 저장된 사이드바 폭을 읽어 앱 화면 상태를 만든다")
    func 로그인하면_저장된_사이드바_폭을_읽어_앱_화면_상태를_만든다() async {
        let adapter = RootStoreTestAdapter(sideBarWidth: 300)

        await adapter.didLogined(true)

        #expect(adapter.snapshot.selectedTab == .home)
        #expect(adapter.sideBarWidth == 300)
    }

    @Test("사이드바 폭을 읽는 동안 로그아웃하면 앱 화면 상태를 만들지 않는다")
    func 사이드바_폭을_읽는_동안_로그아웃하면_앱_화면_상태를_만들지_않는다() async {
        var state = Feature.State()
        state.signIn = false
        let store = TestStore(initialState: state) {
            Feature()
        }

        await store.send(.sideBarWidthFetched(300))

        #expect(store.state.composition == nil)
    }
}

private enum CheckAppUpdateUseCaseTestError: Error {
    case fetchFailed
}
