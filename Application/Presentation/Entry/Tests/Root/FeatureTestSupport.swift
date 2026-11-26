//
//  FeatureTestSupport.swift
//  EntryTests
//
//  Created by opfic on 6/17/26.
//

import Combine
import PresentationShared
import Core
import Domain
import Foundation
import Testing
@testable import Entry

@MainActor
protocol RootStateDriving {
    var snapshot: RootStateSnapshot { get }
    var sheetTodoId: String? { get }
    var widgetRoute: WidgetRoute? { get }

    func onAppear() async
    func setAlert(_ isPresented: Bool) async
    func networkStatusChanged(_ isConnected: Bool) async
    func setTheme(_ theme: SystemTheme) async
    func didLogined(_ signIn: Bool) async
    func presentTodoDetail(_ todoId: String) async
    func dismissSheet() async
    func selectTab(_ tab: AppTab) async
    func openWidgetRoute(_ route: WidgetRoute) async
    func tapUpdateButton() async
}

struct RootStateSnapshot: Equatable {
    let alertTitle: String?
    let alertMessage: String?
    let isNetworkConnected: Bool
    let signIn: Bool?
    let theme: SystemTheme
    let selectedTab: AppTab
}

@MainActor
struct RootStoreTestAdapter: RootStateDriving {
    private let store: TestStoreOf<Feature>

    var snapshot: RootStateSnapshot {
        RootStateSnapshot(
            alertTitle: store.state.alert.map { String(state: $0.title) },
            alertMessage: store.state.alert?.message.map { String(state: $0) },
            isNetworkConnected: store.state.isNetworkConnected,
            signIn: store.state.signIn,
            theme: store.state.theme,
            selectedTab: store.state.selectedTab
        )
    }
    var sheetTodoId: String? { store.state.sheet?.todoId }
    var widgetRoute: WidgetRoute? { store.state.widgetRoute }

    init(
        sessionUseCase: ObserveAuthSessionUseCase = ObserveAuthSessionUseCaseSpy(currentValue: true),
        networkConnectivityUseCase: ObserveNetworkConnectivityUseCase = RootObserveNetworkConnectivityUseCaseSpy(
            currentValue: true
        ),
        systemThemeUseCase: ObserveSystemThemeUseCase = RootObserveSystemThemeUseCaseSpy(
            currentValue: .automatic
        ),
        trackAnalyticsEventUseCase: TrackAnalyticsEventUseCase = RootTrackAnalyticsEventUseCaseSpy(),
        checkAppUpdateUseCase: CheckAppUpdateUseCase = RootCheckAppUpdateUseCaseSpy(),
        appStoreURL: URL? = URL(string: "https://apps.apple.com/us/app/devlog/id6760288611"),
        openURLSpy: RootOpenURLSpy = RootOpenURLSpy(),
        badgeCountSpy: RootApplicationBadgeCountSpy = RootApplicationBadgeCountSpy()
    ) {
        store = TestStore(initialState: Feature.State()) {
            Feature()
        } withDependencies: {
            $0.observeAuthSessionUseCase = sessionUseCase
            $0.rootNetworkConnectivityUseCase = networkConnectivityUseCase
            $0.rootSystemThemeUseCase = systemThemeUseCase
            $0.trackAnalyticsEventUseCase = trackAnalyticsEventUseCase
            $0.checkAppUpdateUseCase = checkAppUpdateUseCase
            $0.appStoreURL = appStoreURL
            $0.openURL = .init { url in
                await openURLSpy.open(url)
                return true
            }
            $0.setApplicationBadgeCount = { count in
                try await badgeCountSpy.setBadgeCount(count)
            }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)
    }

    func onAppear() async {
        await store.send(.onAppear)
        await drainReceivedActions()
    }

    func setAlert(_ isPresented: Bool) async {
        if isPresented {
            await store.send(.networkStatusChanged(false))
        } else {
            await store.send(.alert(.dismiss))
        }
    }

    func networkStatusChanged(_ isConnected: Bool) async {
        await store.send(.networkStatusChanged(isConnected))
    }

    func setTheme(_ theme: SystemTheme) async {
        await store.send(.setTheme(theme))
    }

    func didLogined(_ signIn: Bool) async {
        await store.send(.didLogined(signIn))
    }

    func presentTodoDetail(_ todoId: String) async {
        await store.send(.presentTodoDetail(todoId))
    }

    func dismissSheet() async {
        await store.send(.sheet(.dismiss))
    }

    func selectTab(_ tab: AppTab) async {
        await store.send(.binding(.set(\.selectedTab, tab)))
    }

    func openWidgetRoute(_ route: WidgetRoute) async {
        await store.send(.openWidgetRoute(route))
    }

    func tapUpdateButton() async {
        await store.send(.alert(.presented(.tapUpdateButton)))
    }

    private func drainReceivedActions() async {
        for _ in 0..<8 {
            await store.skipReceivedActions(strict: false)
        }
    }
}

@MainActor
func verifyNetworkDisconnectedAlert(adapter: some RootStateDriving) async {
    await adapter.networkStatusChanged(false)

    #expect(
        adapter.snapshot
            == RootStateSnapshot(
                alertTitle: String(
                    localized: "root_network_disconnected_title",
                    bundle: PresentationResources.bundle
                ),
                alertMessage: String(
                    localized: "root_network_disconnected_message",
                    bundle: PresentationResources.bundle
                ),
                isNetworkConnected: false,
                signIn: nil,
                theme: .automatic,
                selectedTab: .home
            )
    )
}

@MainActor
func verifySetAlert(adapter: some RootStateDriving) async {
    await adapter.networkStatusChanged(false)
    await adapter.setAlert(false)

    #expect(
        adapter.snapshot
            == RootStateSnapshot(
                alertTitle: nil,
                alertMessage: nil,
                isNetworkConnected: false,
                signIn: nil,
                theme: .automatic,
                selectedTab: .home
            )
    )
}

@MainActor
func verifyThemeUpdate(adapter: some RootStateDriving) async {
    await adapter.setTheme(.dark)

    #expect(adapter.snapshot.theme == .dark)
    #expect(adapter.snapshot.alertTitle == nil)
    #expect(adapter.snapshot.selectedTab == .home)
}

@MainActor
func verifyDidLoginedFalse(
    adapter: some RootStateDriving,
    trackAnalyticsEventUseCaseSpy: RootTrackAnalyticsEventUseCaseSpy
) async {
    await adapter.didLogined(false)
    await waitUntil {
        trackAnalyticsEventUseCaseSpy.screenNames == ["login"]
    }

    #expect(adapter.snapshot.signIn == false)
    #expect(adapter.snapshot.selectedTab == .home)
    #expect(trackAnalyticsEventUseCaseSpy.screenNames == ["login"])
}

@MainActor
func verifyDidLoginedTrue(
    adapter: some RootStateDriving,
    trackAnalyticsEventUseCaseSpy: RootTrackAnalyticsEventUseCaseSpy
) async {
    await adapter.selectTab(.today)
    await adapter.didLogined(true)

    #expect(adapter.snapshot.signIn == true)
    #expect(adapter.snapshot.selectedTab == .home)
    #expect(trackAnalyticsEventUseCaseSpy.screenNames.isEmpty)
}

@MainActor
func verifyObservedInitialValues(adapter: some RootStateDriving) async {
    await adapter.onAppear()
    await waitUntil {
        let snapshot = adapter.snapshot
        return snapshot.signIn == false
            && !snapshot.isNetworkConnected
            && snapshot.theme == .dark
            && snapshot.alertTitle
                == String(localized: "root_network_disconnected_title", bundle: PresentationResources.bundle)
    }

    #expect(
        adapter.snapshot
            == RootStateSnapshot(
                alertTitle: String(
                    localized: "root_network_disconnected_title",
                    bundle: PresentationResources.bundle
                ),
                alertMessage: String(
                    localized: "root_network_disconnected_message",
                    bundle: PresentationResources.bundle
                ),
                isNetworkConnected: false,
                signIn: false,
                theme: .dark,
                selectedTab: .home
            )
    )
}

@MainActor
func verifyTodoDetailSheetPresentation(adapter: some RootStateDriving) async {
    await adapter.presentTodoDetail("todo-1")
    #expect(adapter.sheetTodoId == "todo-1")

    await adapter.dismissSheet()
    #expect(adapter.sheetTodoId == nil)
}

@MainActor
func verifyWidgetRouteOpensWhenSignedIn(adapter: some RootStateDriving) async {
    await adapter.openWidgetRoute(.tab(.today))
    #expect(adapter.snapshot.selectedTab == .home)
    #expect(adapter.widgetRoute == .tab(.today))

    await adapter.didLogined(true)
    #expect(adapter.snapshot.selectedTab == .today)
    #expect(adapter.widgetRoute == .tab(.today))
    #expect(adapter.sheetTodoId == nil)

    await adapter.presentTodoDetail("push-todo")
    await adapter.openWidgetRoute(.todayTodo("todo-1"))
    #expect(adapter.snapshot.selectedTab == .today)
    #expect(adapter.sheetTodoId == "todo-1")
}

final class ObserveAuthSessionUseCaseSpy: ObserveAuthSessionUseCase {
    let subject: CurrentValueSubject<Bool, Never>
    private(set) var observeCallCount = 0

    init(currentValue: Bool) {
        subject = CurrentValueSubject(currentValue)
    }

    func observe() -> AnyPublisher<Bool, Never> {
        observeCallCount += 1
        return subject.eraseToAnyPublisher()
    }
}

final class RootObserveNetworkConnectivityUseCaseSpy: ObserveNetworkConnectivityUseCase {
    let subject: CurrentValueSubject<Bool, Never>
    private(set) var observeCallCount = 0

    init(currentValue: Bool) {
        subject = CurrentValueSubject(currentValue)
    }

    func observe() -> AnyPublisher<Bool, Never> {
        observeCallCount += 1
        return subject.eraseToAnyPublisher()
    }
}

final class RootObserveSystemThemeUseCaseSpy: ObserveSystemThemeUseCase {
    let subject: CurrentValueSubject<SystemTheme, Never>
    private(set) var observeCallCount = 0

    init(currentValue: SystemTheme) {
        subject = CurrentValueSubject(currentValue)
    }

    func observe() -> AnyPublisher<SystemTheme, Never> {
        observeCallCount += 1
        return subject.eraseToAnyPublisher()
    }
}

final class RootTrackAnalyticsEventUseCaseSpy: TrackAnalyticsEventUseCase {
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

actor RootCheckAppUpdateUseCaseSpy: CheckAppUpdateUseCase {
    private let result: Result<Bool, Error>
    private var count = 0

    init(result: Result<Bool, Error> = .success(false)) {
        self.result = result
    }

    func execute() async throws -> Bool {
        count += 1
        return try result.get()
    }

    func executeCallCount() -> Int {
        count
    }
}

actor RootOpenURLSpy {
    private var urls = [URL]()

    func open(_ url: URL) {
        urls.append(url)
    }

    func openCallCount() -> Int {
        urls.count
    }

    func openedURLs() -> [URL] {
        urls
    }
}

final class RootApplicationBadgeCountSpy: @unchecked Sendable {
    private let lock = NSLock()
    private var protectedCounts = [Int]()

    var counts: [Int] {
        lock.withLock {
            protectedCounts
        }
    }

    func setBadgeCount(_ count: Int) async throws {
        lock.withLock {
            protectedCounts.append(count)
        }
    }
}
