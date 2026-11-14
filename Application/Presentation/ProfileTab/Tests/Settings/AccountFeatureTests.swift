//
//  AccountFeatureTests.swift
//  ProfileTabTests
//
//  Created by opfic on 6/11/26.
//

import Testing
import Core
import Foundation
import Domain
import PresentationShared
@testable import ProfileTab

@MainActor
struct AccountFeatureTests {
    @Test("화면이 나타나면 인증 제공자 목록을 가져와 상태에 반영한다")
    func 화면이_나타나면_인증_제공자_목록을_가져와_상태에_반영한다() async {
        let fetchSpy = FetchAuthProvidersUseCaseSpy(
            currentProvider: .google,
            allProviders: [.google, .github]
        )
        let driver = AccountTestDriver(fetchUseCase: fetchSpy)

        driver.onAppear()

        await waitUntil {
            driver.currentProvider == .google
        }

        #expect(fetchSpy.executeCallCount == 1)
        #expect(driver.connectedProviders == [.github])
        #expect(driver.disconnectedProviders == [.apple])
    }

    @Test("연동에 성공하면 선택한 제공자를 연동하고 제공자 목록을 다시 가져온다")
    func 연동에_성공하면_선택한_제공자를_연동하고_제공자_목록을_다시_가져온다() async {
        let fetchSpy = FetchAuthProvidersUseCaseSpy(
            currentProvider: .google,
            allProviders: [.google, .github]
        )
        let linkSpy = LinkAuthProviderUseCaseSpy()
        let driver = AccountTestDriver(
            fetchUseCase: fetchSpy,
            linkUseCase: linkSpy
        )

        driver.linkWithProvider(.github)

        await waitUntil {
            linkSpy.providers == [.github] && fetchSpy.executeCallCount == 1
        }

        #expect(driver.currentProvider == .google)
        #expect(driver.connectedProviders == [.github])
        #expect(driver.disconnectedProviders == [.apple])
        #expect(linkSpy.presentationContextIdentifiers == ["scene-id"])
    }

    @Test("연동 해제에 성공하면 선택한 제공자를 해제하고 제공자 목록을 다시 가져온다")
    func 연동_해제에_성공하면_선택한_제공자를_해제하고_제공자_목록을_다시_가져온다() async {
        let fetchSpy = FetchAuthProvidersUseCaseSpy(
            currentProvider: .google,
            allProviders: [.google]
        )
        let unlinkSpy = UnlinkAuthProviderUseCaseSpy()
        let driver = AccountTestDriver(
            fetchUseCase: fetchSpy,
            unlinkUseCase: unlinkSpy
        )

        driver.unlinkFromProvider(.github)

        await waitUntil {
            unlinkSpy.providers == [.github] && fetchSpy.executeCallCount == 1
        }

        #expect(driver.currentProvider == .google)
        #expect(driver.connectedProviders.isEmpty)
        #expect(driver.disconnectedProviders == [.apple, .github])
    }

    @Test("연동 작업이 지연되면 로딩 상태를 표시하고 완료되면 해제한다")
    func 연동_작업이_지연되면_로딩_상태를_표시하고_완료되면_해제한다() async {
        let clock = TestClock()
        let fetchSpy = FetchAuthProvidersUseCaseSpy(
            currentProvider: .google,
            allProviders: [.google, .github]
        )
        let linkSpy = LinkAuthProviderUseCaseSpy()
        linkSpy.shouldSuspend = true
        let target = LoadingFeature.Target.default
        var state = AccountFeature.State()
        state.presentationContext = AuthPresentationContext(identifier: "scene-id")
        let store = TestStore(initialState: state) {
            AccountFeature()
        } withDependencies: {
            $0.fetchAuthProvidersUseCase = fetchSpy
            $0.linkAuthProviderUseCase = linkSpy
            $0.unlinkAuthProviderUseCase = UnlinkAuthProviderUseCaseSpy()
            $0.continuousClock = clock
        }
        await store.send(.linkWithProvider(.github)) {
            $0.activeLoadingProvider = .github
        }
        await store.receive(\.loading.begin) {
            $0.loading.delayedCountByTarget[target] = 1
            $0.loading.scheduledDelayedTargets = [target]
        }
        #expect(linkSpy.providers == [.github])
        #expect(!store.state.isLoading)

        await clock.advance(by: .milliseconds(300))
        await store.receive(\.loading.delayedLoadingDidBecomeVisible, target) {
            $0.loading.scheduledDelayedTargets = []
            $0.loading.visibleDelayedTargets = [target]
            $0.loading.visibleTargets = [target]
            $0.loading.isLoading = true
        }

        #expect(store.state.isLoading)
        #expect(store.state.activeLoadingProvider == .github)

        linkSpy.resume()
        await store.receive(\.setProviders) {
            $0.currentProvider = .google
            $0.connectedProviders = [.github]
            $0.disconnectedProviders = [.apple]
        }
        await store.receive(\.loading.end) {
            $0.loading.delayedCountByTarget[target] = 0
            $0.loading.visibleDelayedTargets = []
            $0.loading.visibleTargets = []
            $0.loading.isLoading = false
            $0.activeLoadingProvider = nil
        }

        #expect(!store.state.isLoading)
    }

    @Test("인증 제공자 조회에 실패하면 공통 에러 알림을 표시한다")
    func 인증_제공자_조회에_실패하면_공통_에러_알림을_표시한다() async {
        let fetchSpy = FetchAuthProvidersUseCaseSpy()
        fetchSpy.error = AccountTestError.failure
        let driver = AccountTestDriver(fetchUseCase: fetchSpy)

        driver.onAppear()

        await waitUntil {
            driver.alert != nil
        }

        #expect(driver.alert == expectedAlert(
            title: String(localized: "common_error_title", bundle: PresentationResources.bundle),
            message: String(localized: "common_error_message", bundle: PresentationResources.bundle)
        ))
    }

    @Test("연동 실패 에러 유형에 맞는 알림을 표시한다")
    func 연동_실패_에러_유형에_맞는_알림을_표시한다() async {
        let scenarios = [
            AccountLinkFailureScenario(
                error: AuthError.linkEmailNotFound,
                title: String(
                    localized: "account_alert_email_unavailable_title",
                    bundle: PresentationResources.bundle
                ),
                message: String(
                    localized: "account_alert_email_unavailable_message",
                    bundle: PresentationResources.bundle
                )
            ),
            AccountLinkFailureScenario(
                error: AuthError.linkEmailMismatch,
                title: String(localized: "account_alert_cannot_link_title", bundle: PresentationResources.bundle),
                message: String(localized: "account_alert_cannot_link_message", bundle: PresentationResources.bundle)
            ),
            AccountLinkFailureScenario(
                error: AuthError.linkCredentialAlreadyInUse,
                title: String(
                    localized: "account_alert_already_linked_title",
                    bundle: PresentationResources.bundle
                ),
                message: String(
                    localized: "account_alert_already_linked_message",
                    bundle: PresentationResources.bundle
                )
            ),
            AccountLinkFailureScenario(
                error: AuthError.githubEmailConflict,
                title: String(
                    localized: "account_alert_github_email_conflict_title",
                    bundle: PresentationResources.bundle
                ),
                message: String(
                    localized: "account_alert_github_email_conflict_message",
                    bundle: PresentationResources.bundle
                )
            ),
            AccountLinkFailureScenario(
                error: AccountTestError.failure,
                title: String(localized: "common_error_title", bundle: PresentationResources.bundle),
                message: String(localized: "common_error_message", bundle: PresentationResources.bundle)
            )
        ]

        for scenario in scenarios {
            let linkSpy = LinkAuthProviderUseCaseSpy()
            linkSpy.error = scenario.error
            let driver = AccountTestDriver(linkUseCase: linkSpy)

            driver.linkWithProvider(.github)

            await waitUntil {
                driver.alert != nil
            }

            #expect(driver.alert == expectedAlert(
                title: scenario.title,
                message: scenario.message
            ))
        }
    }

    @Test("소셜 로그인이 취소되어도 연동 알림을 표시하지 않는다")
    func 소셜_로그인이_취소되어도_연동_알림을_표시하지_않는다() async {
        let linkSpy = LinkAuthProviderUseCaseSpy()
        linkSpy.linked = false
        let driver = AccountTestDriver(linkUseCase: linkSpy)

        driver.linkWithProvider(.google)

        await waitUntil {
            linkSpy.providers == [.google] && !driver.isLoading
        }

        #expect(driver.alert == nil)
    }

    @Test("연동 해제 실패 시 공통 에러 알림을 표시한다")
    func 연동_해제_실패_시_공통_에러_알림을_표시한다() async {
        let unlinkSpy = UnlinkAuthProviderUseCaseSpy()
        unlinkSpy.error = AccountTestError.failure
        let driver = AccountTestDriver(unlinkUseCase: unlinkSpy)

        driver.unlinkFromProvider(.github)

        await waitUntil {
            driver.alert != nil
        }

        #expect(driver.alert == expectedAlert(
            title: String(localized: "common_error_title", bundle: PresentationResources.bundle),
            message: String(localized: "common_error_message", bundle: PresentationResources.bundle)
        ))
    }

    @Test("알림을 닫으면 알림 상태가 초기화된다")
    func 알림을_닫으면_알림_상태가_초기화된다() async {
        let fetchSpy = FetchAuthProvidersUseCaseSpy()
        fetchSpy.error = AccountTestError.failure
        let driver = AccountTestDriver(fetchUseCase: fetchSpy)

        driver.onAppear()

        await waitUntil {
            driver.alert != nil
        }

        driver.dismissAlert()

        #expect(driver.alert == nil)
    }
}

@MainActor
private struct AccountTestDriver {
    private let feature: StoreOf<AccountFeature>

    var currentProvider: AuthProvider? {
        feature.state.currentProvider
    }

    var connectedProviders: [AuthProvider] {
        feature.state.connectedProviders
    }

    var disconnectedProviders: [AuthProvider] {
        feature.state.disconnectedProviders
    }

    var isLoading: Bool {
        feature.state.isLoading
    }

    var alert: AlertState<Never>? {
        feature.state.alert
    }

    init(
        fetchUseCase: FetchAuthProvidersUseCase = FetchAuthProvidersUseCaseSpy(),
        linkUseCase: LinkAuthProviderUseCase = LinkAuthProviderUseCaseSpy(),
        unlinkUseCase: UnlinkAuthProviderUseCase = UnlinkAuthProviderUseCaseSpy()
    ) {
        var state = AccountFeature.State()
        state.presentationContext = AuthPresentationContext(identifier: "scene-id")
        feature = Store(initialState: state) {
            AccountFeature()
        } withDependencies: {
            $0.fetchAuthProvidersUseCase = fetchUseCase
            $0.linkAuthProviderUseCase = linkUseCase
            $0.unlinkAuthProviderUseCase = unlinkUseCase
            $0.continuousClock = ContinuousClock()
        }
    }

    func onAppear() {
        feature.send(.onAppear)
    }

    func linkWithProvider(_ provider: AuthProvider) {
        feature.send(.linkWithProvider(provider))
    }

    func unlinkFromProvider(_ provider: AuthProvider) {
        feature.send(.unlinkFromProvider(provider))
    }

    func dismissAlert() {
        feature.send(.alert(.dismiss))
    }
}

private struct AccountLinkFailureScenario {
    let error: Error
    let title: String
    let message: String
}

private final class FetchAuthProvidersUseCaseSpy: FetchAuthProvidersUseCase {
    var currentProvider: AuthProvider?
    var allProviders: [AuthProvider]
    var error: Error?
    private(set) var executeCallCount = 0

    init(
        currentProvider: AuthProvider? = nil,
        allProviders: [AuthProvider] = []
    ) {
        self.currentProvider = currentProvider
        self.allProviders = allProviders
    }

    func execute() async throws -> (currentProvider: AuthProvider?, allProviders: [AuthProvider]) {
        executeCallCount += 1

        if let error {
            throw error
        }

        return (currentProvider, allProviders)
    }
}

private final class LinkAuthProviderUseCaseSpy: LinkAuthProviderUseCase {
    var error: Error?
    var linked = true
    var shouldSuspend = false
    private(set) var providers = [AuthProvider]()
    private(set) var presentationContextIdentifiers = [String]()
    private var continuation: CheckedContinuation<Void, Never>?
    private var shouldResume = false

    func execute(_ provider: AuthProvider) async throws -> Bool {
        providers.append(provider)
        presentationContextIdentifiers.append(
            AuthPresentationContext.current?.identifier ?? ""
        )

        if shouldSuspend {
            await withCheckedContinuation { continuation in
                if shouldResume {
                    shouldResume = false
                    continuation.resume()
                } else {
                    self.continuation = continuation
                }
            }
        }

        if let error {
            throw error
        }

        return linked
    }

    func resume() {
        guard let continuation else {
            shouldResume = true
            return
        }

        self.continuation = nil
        continuation.resume()
    }
}

private final class UnlinkAuthProviderUseCaseSpy: UnlinkAuthProviderUseCase {
    var error: Error?
    private(set) var providers = [AuthProvider]()

    func execute(_ provider: AuthProvider) async throws {
        providers.append(provider)

        if let error {
            throw error
        }
    }
}

private enum AccountTestError: Error {
    case failure
}

private func expectedAlert(
    title: String,
    message: String
) -> AlertState<Never> {
    AlertState {
        TextState(title)
    } actions: {
        ButtonState(role: .cancel) {
            TextState(String(localized: "common_close", bundle: PresentationResources.bundle))
        }
    } message: {
        TextState(message)
    }
}
