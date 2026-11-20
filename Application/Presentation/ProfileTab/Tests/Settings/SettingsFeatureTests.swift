//
//  SettingsFeatureTests.swift
//  ProfileTabTests
//
//  Created by opfic on 6/12/26.
//

import Core
import Domain
import Foundation
import PresentationShared
import Testing
@testable import ProfileTab

@MainActor
struct SettingsFeatureTests {
    @Test("prod 환경이면 베타 테스트 URL을 제공한다")
    func prod_환경이면_베타_테스트_URL을_제공한다() {
        let url = SettingsFeature.State.betaTestURL(
            appEnvironment: "prod",
            testFlightURL: "https://testflight.apple.com/join/b8mpr4UN"
        )

        #expect(url == URL(string: "https://testflight.apple.com/join/b8mpr4UN"))
    }

    @Test("staging 환경이면 베타 테스트 URL을 제공하지 않는다")
    func staging_환경이면_베타_테스트_URL을_제공하지_않는다() {
        let url = SettingsFeature.State.betaTestURL(
            appEnvironment: "staging",
            testFlightURL: "https://testflight.apple.com/join/b8mpr4UN"
        )

        #expect(url == nil)
    }

    @Test("미치환 환경값이면 베타 테스트 URL을 제공하지 않는다")
    func 미치환_환경값이면_베타_테스트_URL을_제공하지_않는다() {
        let url = SettingsFeature.State.betaTestURL(
            appEnvironment: "$(APP_ENVIRONMENT)",
            testFlightURL: "https://testflight.apple.com/join/b8mpr4UN"
        )

        #expect(url == nil)
    }

    @Test("네트워크 상태 관찰 결과를 상태에 반영한다")
    func 네트워크_상태_관찰_결과를_상태에_반영한다() async {
        let networkSpy = ObserveNetworkConnectivityUseCaseSpy()
        let adapter = SettingsStoreTestAdapter(networkUseCase: networkSpy)

        await adapter.startObserving()
        networkSpy.currentValueSubject.send(false)
        await adapter.drainReceivedActions()

        #expect(!adapter.isNetworkConnected)
    }

    @Test("테마를 변경하면 상태를 갱신하고 설정 저장을 요청한다")
    func 테마를_변경하면_상태를_갱신하고_설정_저장을_요청한다() async {
        let updateSpy = UpdateSystemThemeUseCaseSpy()
        let adapter = SettingsStoreTestAdapter(updateThemeUseCase: updateSpy)

        await adapter.setTheme(.dark)

        #expect(adapter.theme == .dark)
        #expect(updateSpy.themes == [.dark])
    }

    @Test("테마 관찰 결과를 상태에 반영한다")
    func 테마_관찰_결과를_상태에_반영한다() async {
        let themeSpy = ObserveSystemThemeUseCaseSpy()
        let updateSpy = UpdateSystemThemeUseCaseSpy()
        let adapter = SettingsStoreTestAdapter(
            themeUseCase: themeSpy,
            updateThemeUseCase: updateSpy
        )

        await adapter.startObserving()
        themeSpy.subject.send(.light)
        await adapter.drainReceivedActions()

        #expect(adapter.theme == .light)
        #expect(updateSpy.themes == [.light])
    }
}

@MainActor
private struct SettingsStoreTestAdapter {
    private let store: TestStoreOf<SettingsFeature>

    var theme: SystemTheme { store.state.theme }
    var isNetworkConnected: Bool { store.state.isNetworkConnected }

    init(
        networkUseCase: ObserveNetworkConnectivityUseCase = ObserveNetworkConnectivityUseCaseSpy(),
        themeUseCase: ObserveSystemThemeUseCase = ObserveSystemThemeUseCaseSpy(),
        updateThemeUseCase: UpdateSystemThemeUseCase = UpdateSystemThemeUseCaseSpy()
    ) {
        store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        } withDependencies: {
            $0.profileNetworkConnectivityUseCase = networkUseCase
            $0.profileSystemThemeUseCase = themeUseCase
            $0.updateSystemThemeUseCase = updateThemeUseCase
        }
        store.exhaustivity = .off(showSkippedAssertions: false)
    }

    func startObserving() async {
        await store.send(.startObserving)
    }

    func setTheme(_ theme: SystemTheme) async {
        await store.send(.binding(.set(\.theme, theme))) {
            $0.theme = theme
        }
    }

    func drainReceivedActions() async {
        await store.skipReceivedActions(strict: false)
        await store.skipReceivedActions(strict: false)
        await store.skipReceivedActions(strict: false)
        await store.skipReceivedActions(strict: false)
    }
}
