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
struct SettingsFeature {
    private enum CancelID: Hashable {
        case networkConnectivity
        case systemTheme
    }

    @ObservableState
    struct State: Equatable {
        var theme: SystemTheme = .automatic
        var isNetworkConnected = true
        var appVersion = Self.appVersion()
        var betaTestURL = Self.betaTestURL(
            appEnvironment: Bundle.main.object(forInfoDictionaryKey: "APP_ENVIRONMENT") as? String,
            testFlightURL: Bundle.main.object(forInfoDictionaryKey: "TESTFLIGHT_URL") as? String
        )
        var policyURL = Bundle.main.object(forInfoDictionaryKey: "PRIVACY_POLICY_URL") as? String
        // 칸 화면에서 설정 옆 칸에, Mac 설정 화면에서 목차 옆에 표시하는 화면
        var selectedRoute = ProfileRoute.theme

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

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case startObserving
        case networkStatusChanged(Bool)
    }

    @Dependency(\.profileNetworkConnectivityUseCase) var networkConnectivityUseCase
    @Dependency(\.profileSystemThemeUseCase) var systemThemeUseCase
    @Dependency(\.updateSystemThemeUseCase) var updateSystemThemeUseCase

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding(\.theme):
                return updateSystemThemeEffect(state.theme)
            case .binding:
                break
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
