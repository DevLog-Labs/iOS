//
//  SettingsFeature.swift
//  ProfileTab
//
//  Created by opfic on 6/12/26.
//

import Combine
import Core
import Domain
import Foundation
import PresentationShared

@Reducer
public struct SettingsFeature {
    private enum CancelID: Hashable {
        case networkConnectivity
        case systemTheme
    }

    public enum Screen: Equatable {
        case list
        // 고른 항목 화면
        case detail
    }

    @ObservableState
    public struct State: Equatable {
        // 계정 화면에서 뒤로 가도 진행 중인 로그아웃, 회원 탈퇴가 취소되지 않게 설정이 보관
        public var account = AccountFeature.State()
        var theme: SystemTheme = .automatic
        var isNetworkConnected = true
        var appVersion = Self.appVersion()
        var betaTestURL = Self.betaTestURL(
            appEnvironment: Bundle.main.object(forInfoDictionaryKey: "APP_ENVIRONMENT") as? String,
            testFlightURL: Bundle.main.object(forInfoDictionaryKey: "TESTFLIGHT_URL") as? String
        )
        var policyURL = Bundle.main.object(forInfoDictionaryKey: "PRIVACY_POLICY_URL") as? String
        // 설정에서 고른 항목, 목록으로 돌아가도 창 전체 설정 화면에 표시할 항목으로 유지
        public var selectedRoute = ProfileRoute.theme
        // 열린 설정 화면, 좁은 창은 프로필 화면에 쌓고 사이드바가 있는 창은 창 전체 설정 화면에 표시
        public var screen: Screen?

        public init() { }

        static func betaTestURL(appEnvironment: String?, testFlightURL: String?) -> URL? {
            guard appEnvironment?.trimmingCharacters(in: .whitespacesAndNewlines) == "prod",
                  let rawValue = testFlightURL else {
                return nil
            }

            let urlString = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !urlString.isEmpty, !urlString.hasPrefix("$(") else {
                return nil
            }

            return URL(string: urlString)
        }

        private static func appVersion() -> String? {
            let marketingVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            let buildNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
            let components = [marketingVersion, buildNumber]
                .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            return components.isEmpty ? nil : components.joined(separator: ".")
        }
    }

    public enum Action: BindableAction, Equatable {
        case account(AccountFeature.Action)
        case binding(BindingAction<State>)
        case open
        case openList
        case select(ProfileRoute)
        case close
        case startObserving
        case networkStatusChanged(Bool)
    }

    @Dependency(\.profileNetworkConnectivityUseCase) var networkConnectivityUseCase
    @Dependency(\.profileSystemThemeUseCase) var systemThemeUseCase
    @Dependency(\.updateSystemThemeUseCase) var updateSystemThemeUseCase

    public init() { }

    public var body: some ReducerOf<Self> {
        Scope(state: \.account, action: \.account) {
            AccountFeature()
        }
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .account:
                break
            case .binding(\.theme):
                return updateSystemThemeEffect(state.theme)
            case .binding:
                break
            case .open:
                // 창 전체 설정 화면을 새로 열 때는 첫 항목부터 표시
                state.selectedRoute = .theme
                state.screen = .detail
            case .openList:
                // 좁은 창에서 설정을 새로 열 때도 앞서 고른 항목 대신 첫 항목을 고른 채 목록 표시
                state.selectedRoute = .theme
                state.screen = .list
            case .select(let route):
                state.selectedRoute = route
                // 앱 정보는 좁은 창에 항목 화면이 없어 설정 목록에서 표시
                state.screen = route == .information ? .list : .detail
            case .close:
                state.screen = nil
            case .startObserving:
                return .merge(
                    observeNetworkConnectivityEffect(),
                    monitorSystemThemeEffect()
                )
            case .networkStatusChanged(let isConnected):
                state.isNetworkConnected = isConnected
            }

            return .none
        }
    }
}

extension DependencyValues {
    var profileNetworkConnectivityUseCase: ObserveNetworkConnectivityUseCase {
        get { self[ObserveNetworkConnectivityUseCaseKey.self] }
        set { self[ObserveNetworkConnectivityUseCaseKey.self] = newValue }
    }

    var profileSystemThemeUseCase: ObserveSystemThemeUseCase {
        get { self[ObserveSystemThemeUseCaseKey.self] }
        set { self[ObserveSystemThemeUseCaseKey.self] = newValue }
    }

    var updateSystemThemeUseCase: UpdateSystemThemeUseCase {
        get { self[UpdateSystemThemeUseCaseKey.self] }
        set { self[UpdateSystemThemeUseCaseKey.self] = newValue }
    }

}

private enum ObserveNetworkConnectivityUseCaseKey: DependencyKey {
    static var liveValue: ObserveNetworkConnectivityUseCase {
        preconditionFailure("ObserveNetworkConnectivityUseCase must be provided.")
    }

    static var testValue: ObserveNetworkConnectivityUseCase {
        liveValue
    }
}

private enum ObserveSystemThemeUseCaseKey: DependencyKey {
    static var liveValue: ObserveSystemThemeUseCase {
        preconditionFailure("ObserveSystemThemeUseCase must be provided.")
    }

    static var testValue: ObserveSystemThemeUseCase {
        liveValue
    }
}

private enum UpdateSystemThemeUseCaseKey: DependencyKey {
    static var liveValue: UpdateSystemThemeUseCase {
        preconditionFailure("UpdateSystemThemeUseCase must be provided.")
    }

    static var testValue: UpdateSystemThemeUseCase {
        liveValue
    }
}

private extension SettingsFeature {
    func observeNetworkConnectivityEffect() -> Effect<Action> {
        .publisher { [networkConnectivityUseCase] in
            networkConnectivityUseCase.observe()
                .map(Action.networkStatusChanged)
        }
        .cancellable(id: CancelID.networkConnectivity, cancelInFlight: true)
    }

    func monitorSystemThemeEffect() -> Effect<Action> {
        .publisher { [systemThemeUseCase] in
            systemThemeUseCase.observe()
                .removeDuplicates()
                .map { .binding(.set(\.theme, $0)) }
        }
        .cancellable(id: CancelID.systemTheme, cancelInFlight: true)
    }

    func updateSystemThemeEffect(_ theme: SystemTheme) -> Effect<Action> {
        .run { [updateSystemThemeUseCase] _ in
            updateSystemThemeUseCase.execute(theme)
        }
    }
}
