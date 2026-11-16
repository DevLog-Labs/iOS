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

    enum ActiveLoadingRow: Equatable {
        case signOut
        case deleteAuth
    }

    @ObservableState
    struct State: Equatable {
        @Presents var alert: AlertState<Action.Alert>?
        var theme: SystemTheme = .automatic
        var isNetworkConnected = true
        var activeLoadingRow: ActiveLoadingRow?
        var loading = LoadingFeature.State()
        var alertType: Action.AlertType?
        var appVersion = Self.appVersion()
        var betaTestURL = Self.betaTestURL(
            appEnvironment: Bundle.main.object(forInfoDictionaryKey: "APP_ENVIRONMENT") as? String,
            testFlightURL: Bundle.main.object(forInfoDictionaryKey: "TESTFLIGHT_URL") as? String
        )
        var policyURL = Bundle.main.object(forInfoDictionaryKey: "PRIVACY_POLICY_URL") as? String
        // 칸 화면에서 설정 옆 칸에, Mac 설정 화면에서 목차 옆에 표시하는 화면
        var selectedRoute = ProfileRoute.theme

        var isLoading: Bool {
            loading.isLoading
        }

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
        case alert(PresentationAction<Alert>)
        case binding(BindingAction<State>)
        case startObserving
        case networkStatusChanged(Bool)
        case setAlert(AlertType)
        case loading(LoadingFeature.Action)

        enum Alert: Equatable {
            case tapDeleteAuthButton
            case tapSignOutButton
        }

        enum AlertType: Equatable {
            case signOut
            case deleteAuth
            case error
        }
    }

    @Dependency(\.deleteAuthUseCase) var deleteAuthUseCase
    @Dependency(\.signOutUseCase) var signOutUseCase
    @Dependency(\.profileNetworkConnectivityUseCase) var networkConnectivityUseCase
    @Dependency(\.profileSystemThemeUseCase) var systemThemeUseCase
    @Dependency(\.updateSystemThemeUseCase) var updateSystemThemeUseCase

    var body: some ReducerOf<Self> {
        Scope(state: \.loading, action: \.loading) {
            LoadingFeature()
        }
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .alert(.presented(.tapDeleteAuthButton)):
                state.alert = nil
                state.alertType = nil
                state.activeLoadingRow = .deleteAuth
                return deleteAuthEffect()
            case .alert(.presented(.tapSignOutButton)):
                state.alert = nil
                state.alertType = nil
                state.activeLoadingRow = .signOut
                return signOutEffect()
            case .alert(.dismiss):
                state.alert = nil
                state.alertType = nil
            case .alert:
                break
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
            case .setAlert(let type):
                state.alert = Self.alertState(for: type)
                state.alertType = type
            case .loading(.end):
                if !state.isLoading {
                    state.activeLoadingRow = nil
                }
            case .loading:
                break
            }

            return .none
        }
        .ifLet(\.$alert, action: \.alert)
    }
}

extension DependencyValues {
    var deleteAuthUseCase: DeleteAuthUseCase {
        get { self[DeleteAuthUseCaseKey.self] }
        set { self[DeleteAuthUseCaseKey.self] = newValue }
    }

    var signOutUseCase: SignOutUseCase {
        get { self[SignOutUseCaseKey.self] }
        set { self[SignOutUseCaseKey.self] = newValue }
    }

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

private enum DeleteAuthUseCaseKey: DependencyKey {
    static var liveValue: DeleteAuthUseCase {
        preconditionFailure("DeleteAuthUseCase must be provided.")
    }

    static var testValue: DeleteAuthUseCase {
        liveValue
    }
}

private enum SignOutUseCaseKey: DependencyKey {
    static var liveValue: SignOutUseCase {
        preconditionFailure("SignOutUseCase must be provided.")
    }

    static var testValue: SignOutUseCase {
        liveValue
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

    func deleteAuthEffect() -> Effect<Action> {
        .run { [deleteAuthUseCase] send in
            await send(.loading(.begin(target: .default, mode: .delayed)))
            do {
                try await deleteAuthUseCase.execute()
                // 유스케이스 완료가 LoginView 전환 완료를 의미하지 않으므로 화면이 교체될 때까지 로딩을 유지한다.
            } catch {
                await send(.loading(.end(target: .default, mode: .delayed)))
                await send(.setAlert(.error))
            }
        }
    }

    func signOutEffect() -> Effect<Action> {
        .run { [signOutUseCase] send in
            await send(.loading(.begin(target: .default, mode: .delayed)))
            do {
                try await signOutUseCase.execute()
                // 유스케이스 완료가 LoginView 전환 완료를 의미하지 않으므로 화면이 교체될 때까지 로딩을 유지한다.
            } catch {
                await send(.loading(.end(target: .default, mode: .delayed)))
                await send(.setAlert(.error))
            }
        }
    }

    static func alertState(for type: Action.AlertType) -> AlertState<Action.Alert> {
        switch type {
        case .signOut:
            return AlertState {
                TextState(String(localized: "settings_alert_sign_out_title", bundle: PresentationResources.bundle))
            } actions: {
                ButtonState(role: .cancel) {
                    TextState(String(localized: "common_cancel", bundle: PresentationResources.bundle))
                }
                ButtonState(role: .destructive, action: .tapSignOutButton) {
                    TextState(String(localized: "common_confirm", bundle: PresentationResources.bundle))
                }
            } message: {
                TextState(String(localized: "settings_alert_sign_out_message", bundle: PresentationResources.bundle))
            }
        case .deleteAuth:
            return AlertState {
                TextState(
                    String(
                        localized: "settings_alert_delete_account_title",
                        bundle: PresentationResources.bundle
                    )
                )
            } actions: {
                ButtonState(role: .cancel) {
                    TextState(String(localized: "common_cancel", bundle: PresentationResources.bundle))
                }
                ButtonState(role: .destructive, action: .tapDeleteAuthButton) {
                    TextState(String(localized: "settings_delete_account_action", bundle: PresentationResources.bundle))
                }
            } message: {
                TextState(
                    String(
                        localized: "settings_alert_delete_account_message",
                        bundle: PresentationResources.bundle
                    )
                )
            }
        case .error:
            return AlertState {
                TextState(String(localized: "common_error_title", bundle: PresentationResources.bundle))
            } actions: {
                ButtonState(role: .cancel) {
                    TextState(String(localized: "common_close", bundle: PresentationResources.bundle))
                }
            } message: {
                TextState(String(localized: "common_error_message", bundle: PresentationResources.bundle))
            }
        }
    }
}
