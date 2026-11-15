//
//  Feature.swift
//  Entry
//
//  Created by opfic on 6/17/26.
//

import Combine
import PresentationShared
import Core
import Domain
import Foundation

@Reducer
struct Feature {
    private enum CancelID: Hashable {
        case networkConnectivity
        case session
        case theme
    }

    @ObservableState
    struct State: Equatable {
        @Presents var alert: AlertState<Action.Alert>?
        @Presents var sheet: SheetState?
        var hasCheckedAppUpdate = false
        var isAppUpdateRequired = false
        var isNetworkConnected = true
        var signIn: Bool?
        var theme: SystemTheme = .automatic
        var selectedMainTab = MainTab.home
        var widgetRoute: WidgetRoute?
        var isObservingNetworkConnectivity = false
        var isObservingSession = false
        var isObservingTheme = false
    }

    @ObservableState
    struct SheetState: Equatable, Identifiable {
        let todoId: String
        var id: String { todoId }
    }

    enum Action: BindableAction, Equatable {
        case alert(PresentationAction<Alert>)
        case appUpdateCheckCompleted(Bool)
        case binding(BindingAction<State>)
        case sheet(PresentationAction<Sheet>)
        case onAppear
        case presentTodoDetail(String)
        case openWidgetRoute(WidgetRoute)
        case networkStatusChanged(Bool)
        case setTheme(SystemTheme)
        case didLogined(Bool)

        enum Alert: Equatable {
            case tapUpdateButton
        }

        enum Sheet: Equatable {
            case tapCloseButton
        }
    }

    @Dependency(\.observeAuthSessionUseCase) var observeAuthSessionUseCase
    @Dependency(\.rootNetworkConnectivityUseCase) var networkConnectivityUseCase
    @Dependency(\.rootSystemThemeUseCase) var systemThemeUseCase
    @Dependency(\.trackAnalyticsEventUseCase) var trackAnalyticsEventUseCase
    @Dependency(\.checkAppUpdateUseCase) var checkAppUpdateUseCase
    @Dependency(\.appStoreURL) var appStoreURL
    @Dependency(\.openURL) var openURL
    @Dependency(\.setApplicationBadgeCount) var setApplicationBadgeCount

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .alert(.presented(.tapUpdateButton)):
                return openAppStoreEffect()
            case .alert:
                break
            case .appUpdateCheckCompleted(let isRequired):
                guard isRequired else { break }
                state.isAppUpdateRequired = true
                state.alert = Self.appUpdateAlertState()
            case .binding:
                break
            case .sheet(.dismiss), .sheet(.presented(.tapCloseButton)):
                state.sheet = nil
            case .sheet:
                break
            case .onAppear:
                var effect = clearApplicationBadgeCountEffect()

                if !state.hasCheckedAppUpdate {
                    state.hasCheckedAppUpdate = true
                    effect = .merge(effect, checkAppUpdateEffect())
                }

                if !state.isObservingNetworkConnectivity {
                    state.isObservingNetworkConnectivity = true
                    effect = .merge(effect, observeNetworkConnectivityEffect())
                }

                if !state.isObservingSession {
                    state.isObservingSession = true
                    effect = .merge(effect, observeSessionEffect())
                }

                if !state.isObservingTheme {
                    state.isObservingTheme = true
                    effect = .merge(effect, observeThemeEffect())
                }

                return effect
            case .presentTodoDetail(let todoId):
                state.sheet = .init(todoId: todoId)
            case .openWidgetRoute(let route):
                // 로그아웃 상태면 로그인 화면만 보이고 위젯 경로는 버림
                guard state.signIn != false else { break }
                // 로그인 여부를 확인하기 전이면 경로를 보관했다가 로그인 확인 뒤 적용
                state.widgetRoute = route
                guard state.signIn == true else { break }
                Self.applyWidgetRoute(route, to: &state)
            case .networkStatusChanged(let isConnected):
                let wasConnected = state.isNetworkConnected
                state.isNetworkConnected = isConnected
                if wasConnected && !isConnected && !state.isAppUpdateRequired {
                    state.alert = Self.networkDisconnectedAlertState()
                }
            case .setTheme(let theme):
                state.theme = theme
            case .didLogined(let result):
                let wasSignedIn = state.signIn == true
                state.signIn = result
                if result {
                    if !wasSignedIn, let route = state.widgetRoute {
                        Self.applyWidgetRoute(route, to: &state)
                    } else {
                        state.selectedMainTab = .home
                    }
                } else {
                    state.widgetRoute = nil
                    return .merge(
                        trackLoginScreenEffect(),
                        clearApplicationBadgeCountEffect()
                    )
                }
            }

            return .none
        }
        .ifLet(\.$alert, action: \.alert)
        .ifLet(\.$sheet, action: \.sheet) {
            SheetFeature()
        }
    }

    private static func applyWidgetRoute(_ route: WidgetRoute, to state: inout State) {
        switch route {
        case .tab(let tab):
            state.selectedMainTab = tab
        case .todayTodo(let id):
            state.sheet = .init(todoId: id)
        }
    }
}

private struct SheetFeature: Reducer {
    typealias State = Feature.SheetState
    typealias Action = Feature.Action.Sheet

    var body: some ReducerOf<Self> {
        EmptyReducer()
    }
}

extension DependencyValues {
    var appStoreURL: URL? {
        get { self[AppStoreURLKey.self] }
        set { self[AppStoreURLKey.self] = newValue }
    }

    var checkAppUpdateUseCase: CheckAppUpdateUseCase {
        get { self[CheckAppUpdateUseCaseKey.self] }
        set { self[CheckAppUpdateUseCaseKey.self] = newValue }
    }

    var observeAuthSessionUseCase: ObserveAuthSessionUseCase {
        get { self[ObserveAuthSessionUseCaseKey.self] }
        set { self[ObserveAuthSessionUseCaseKey.self] = newValue }
    }

    var rootNetworkConnectivityUseCase: ObserveNetworkConnectivityUseCase {
        get { self[NetworkConnectivityUseCaseKey.self] }
        set { self[NetworkConnectivityUseCaseKey.self] = newValue }
    }

    var rootSystemThemeUseCase: ObserveSystemThemeUseCase {
        get { self[SystemThemeUseCaseKey.self] }
        set { self[SystemThemeUseCaseKey.self] = newValue }
    }
}

private enum AppStoreURLKey: DependencyKey {
    static let liveValue = configuredAppStoreURL()
    static let testValue: URL? = nil
}

private func configuredAppStoreURL() -> URL? {
    guard let rawValue = Bundle.main.object(forInfoDictionaryKey: "APP_STORE_URL") as? String else {
        return nil
    }

    let urlString = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !urlString.isEmpty, !urlString.hasPrefix("$(") else { return nil }
    return URL(string: urlString)
}

private enum CheckAppUpdateUseCaseKey: DependencyKey {
    static var liveValue: CheckAppUpdateUseCase {
        preconditionFailure("CheckAppUpdateUseCase must be provided.")
    }

    static var testValue: CheckAppUpdateUseCase {
        liveValue
    }
}

private enum ObserveAuthSessionUseCaseKey: DependencyKey {
    static var liveValue: ObserveAuthSessionUseCase {
        preconditionFailure("ObserveAuthSessionUseCase must be provided.")
    }

    static var testValue: ObserveAuthSessionUseCase {
        liveValue
    }
}

private enum NetworkConnectivityUseCaseKey: DependencyKey {
    static var liveValue: ObserveNetworkConnectivityUseCase {
        preconditionFailure("ObserveNetworkConnectivityUseCase must be provided.")
    }

    static var testValue: ObserveNetworkConnectivityUseCase {
        liveValue
    }
}

private enum SystemThemeUseCaseKey: DependencyKey {
    static var liveValue: ObserveSystemThemeUseCase {
        preconditionFailure("ObserveSystemThemeUseCase must be provided.")
    }

    static var testValue: ObserveSystemThemeUseCase {
        liveValue
    }
}

private extension Feature {
    func checkAppUpdateEffect() -> Effect<Action> {
        .run { [checkAppUpdateUseCase] send in
            let isRequired = (try? await checkAppUpdateUseCase.execute()) ?? false
            await send(.appUpdateCheckCompleted(isRequired))
        }
    }

    func openAppStoreEffect() -> Effect<Action> {
        .run { [appStoreURL, openURL] _ in
            guard let appStoreURL else { return }
            await openURL(appStoreURL)
        }
    }

    func clearApplicationBadgeCountEffect() -> Effect<Action> {
        .run { [setApplicationBadgeCount] _ in
            try? await setApplicationBadgeCount(0)
        }
    }

    func observeNetworkConnectivityEffect() -> Effect<Action> {
        .publisher { [networkConnectivityUseCase] in
            networkConnectivityUseCase.observe()
                .map(Action.networkStatusChanged)
        }
        .cancellable(id: CancelID.networkConnectivity, cancelInFlight: true)
    }

    func observeSessionEffect() -> Effect<Action> {
        .publisher { [observeAuthSessionUseCase] in
            observeAuthSessionUseCase.observe()
                .removeDuplicates()
                .map(Action.didLogined)
        }
        .cancellable(id: CancelID.session, cancelInFlight: true)
    }

    func observeThemeEffect() -> Effect<Action> {
        .publisher { [systemThemeUseCase] in
            systemThemeUseCase.observe()
                .removeDuplicates()
                .map(Action.setTheme)
        }
        .cancellable(id: CancelID.theme, cancelInFlight: true)
    }

    func trackLoginScreenEffect() -> Effect<Action> {
        .run { [trackAnalyticsEventUseCase] _ in
            trackAnalyticsEventUseCase.execute(.screenView("login"))
        }
    }

    static func appUpdateAlertState() -> AlertState<Action.Alert> {
        AlertState {
            TextState(String(localized: "root_app_update_title", bundle: PresentationResources.bundle))
        } actions: {
            ButtonState(action: .tapUpdateButton) {
                TextState(String(localized: "root_app_update_action", bundle: PresentationResources.bundle))
            }
        } message: {
            TextState(String(localized: "root_app_update_message", bundle: PresentationResources.bundle))
        }
    }

    static func networkDisconnectedAlertState() -> AlertState<Action.Alert> {
        AlertState {
            TextState(String(localized: "root_network_disconnected_title", bundle: PresentationResources.bundle))
        } actions: {
            ButtonState(role: .cancel) {
                TextState(String(localized: "common_close", bundle: PresentationResources.bundle))
            }
        } message: {
            TextState(String(localized: "root_network_disconnected_message", bundle: PresentationResources.bundle))
        }
    }
}
