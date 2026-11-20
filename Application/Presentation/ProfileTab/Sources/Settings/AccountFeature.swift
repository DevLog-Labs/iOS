//
//  AccountFeature.swift
//  ProfileTab
//
//  Created by opfic on 6/11/26.
//

import Core
import Domain
import Foundation
import PresentationShared

@Reducer
struct AccountFeature {
    enum ActiveLoadingRow: Equatable {
        case signOut
        case deleteAuth
    }

    @ObservableState
    struct State: Equatable {
        @Presents var alert: AlertState<Action.Alert>?
        var currentProvider: AuthProvider?
        var connectedProviders: [AuthProvider] = []
        var disconnectedProviders: [AuthProvider] = []
        var activeLoadingProvider: AuthProvider?
        var activeLoadingRow: ActiveLoadingRow?
        var loading = LoadingFeature.State()
        var presentationContext: AuthPresentationContext?

        var isLoading: Bool {
            loading.isLoading
        }
    }

    enum Action {
        case alert(PresentationAction<Alert>)
        case onAppear
        case linkWithProvider(AuthProvider)
        case setPresentationContext(AuthPresentationContext?)
        case unlinkFromProvider(AuthProvider)
        case setAlert(AlertType)
        case setProviders(currentProvider: AuthProvider?, allProviders: [AuthProvider])
        case loading(LoadingFeature.Action)

        enum Alert: Equatable {
            case tapDeleteAuthButton
            case tapSignOutButton
        }
    }

    enum AlertType: Equatable {
        case signOut
        case deleteAuth
        case linkEmailNotFound
        case linkEmailMismatch
        case linkCredentialAlreadyInUse
        case githubEmailConflict
        case error
    }

    @Dependency(\.fetchAuthProvidersUseCase) var fetchProvidersUseCase
    @Dependency(\.linkAuthProviderUseCase) var linkProviderUseCase
    @Dependency(\.unlinkAuthProviderUseCase) var unlinkProviderUseCase
    @Dependency(\.deleteAuthUseCase) var deleteAuthUseCase
    @Dependency(\.signOutUseCase) var signOutUseCase

    var body: some ReducerOf<Self> {
        Scope(state: \.loading, action: \.loading) {
            LoadingFeature()
        }
        Reduce { state, action in
            switch action {
            case .alert(.presented(.tapDeleteAuthButton)):
                state.alert = nil
                state.activeLoadingRow = .deleteAuth
                return deleteAuthEffect()
            case .alert(.presented(.tapSignOutButton)):
                state.alert = nil
                state.activeLoadingRow = .signOut
                return signOutEffect()
            case .alert:
                break
            case .onAppear:
                // 화면을 떠난 뒤 실패한 요청의 알림창은 다시 들어올 때 띄우지 않음
                state.alert = nil
                return fetchProvidersEffect()
            case .linkWithProvider(let provider):
                guard !state.isLoading,
                      let context = state.presentationContext
                else {
                    return .none
                }
                state.activeLoadingProvider = provider
                return linkProviderEffect(
                    provider,
                    context: context
                )
            case .setPresentationContext(let context):
                state.presentationContext = context
            case .unlinkFromProvider(let provider):
                guard !state.isLoading else { return .none }
                state.activeLoadingProvider = provider
                return unlinkProviderEffect(provider)
            case .setAlert(let type):
                state.alert = Self.alertState(for: type)
            case .setProviders(let currentProvider, let allProviders):
                state.currentProvider = currentProvider
                state.connectedProviders = allProviders.filter { $0 != currentProvider }
                state.disconnectedProviders = AuthProvider.allCases
                    .filter { !allProviders.contains($0) }
            case .loading(.end):
                if !state.isLoading {
                    state.activeLoadingProvider = nil
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
    var fetchAuthProvidersUseCase: FetchAuthProvidersUseCase {
        get { self[FetchAuthProvidersUseCaseKey.self] }
        set { self[FetchAuthProvidersUseCaseKey.self] = newValue }
    }

    var linkAuthProviderUseCase: LinkAuthProviderUseCase {
        get { self[LinkAuthProviderUseCaseKey.self] }
        set { self[LinkAuthProviderUseCaseKey.self] = newValue }
    }

    var unlinkAuthProviderUseCase: UnlinkAuthProviderUseCase {
        get { self[UnlinkAuthProviderUseCaseKey.self] }
        set { self[UnlinkAuthProviderUseCaseKey.self] = newValue }
    }

    var deleteAuthUseCase: DeleteAuthUseCase {
        get { self[DeleteAuthUseCaseKey.self] }
        set { self[DeleteAuthUseCaseKey.self] = newValue }
    }

    var signOutUseCase: SignOutUseCase {
        get { self[SignOutUseCaseKey.self] }
        set { self[SignOutUseCaseKey.self] = newValue }
    }
}

private enum FetchAuthProvidersUseCaseKey: DependencyKey {
    static var liveValue: FetchAuthProvidersUseCase {
        preconditionFailure("FetchAuthProvidersUseCase must be provided.")
    }

    static var testValue: FetchAuthProvidersUseCase {
        liveValue
    }
}

private enum LinkAuthProviderUseCaseKey: DependencyKey {
    static var liveValue: LinkAuthProviderUseCase {
        preconditionFailure("LinkAuthProviderUseCase must be provided.")
    }

    static var testValue: LinkAuthProviderUseCase {
        liveValue
    }
}

private enum UnlinkAuthProviderUseCaseKey: DependencyKey {
    static var liveValue: UnlinkAuthProviderUseCase {
        preconditionFailure("UnlinkAuthProviderUseCase must be provided.")
    }

    static var testValue: UnlinkAuthProviderUseCase {
        liveValue
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

private extension AccountFeature {
    func fetchProvidersEffect() -> Effect<Action> {
        .run { [fetchProvidersUseCase] send in
            do {
                let providers = try await fetchProvidersUseCase.execute()
                await send(.setProviders(
                    currentProvider: providers.currentProvider,
                    allProviders: providers.allProviders
                ))
            } catch {
                await send(.setAlert(.error))
            }
        }
    }

    func linkProviderEffect(
        _ provider: AuthProvider,
        context: AuthPresentationContext
    ) -> Effect<Action> {
        .run { [fetchProvidersUseCase, linkProviderUseCase] send in
            await send(.loading(.begin(target: .default, mode: .delayed)))
            do {
                let linked = try await AuthPresentationContext
                    .$current
                    .withValue(context) {
                        try await linkProviderUseCase.execute(provider)
                    }
                guard linked else {
                    await send(.loading(.end(target: .default, mode: .delayed)))
                    return
                }

                await ToastPresenter.present(
                    message: String(
                        localized: "account_toast_link_success",
                        bundle: PresentationResources.bundle
                    ),
                    systemImage: "checkmark.circle"
                )
                let providers = try await fetchProvidersUseCase.execute()
                await send(.setProviders(
                    currentProvider: providers.currentProvider,
                    allProviders: providers.allProviders
                ))
                await send(.loading(.end(target: .default, mode: .delayed)))
            } catch {
                await send(.loading(.end(target: .default, mode: .delayed)))
                await send(.setAlert(Self.linkAlertType(for: error)))
            }
        }
    }

    func unlinkProviderEffect(_ provider: AuthProvider) -> Effect<Action> {
        .run { [fetchProvidersUseCase, unlinkProviderUseCase] send in
            await send(.loading(.begin(target: .default, mode: .delayed)))
            do {
                try await unlinkProviderUseCase.execute(provider)
                await ToastPresenter.present(
                    message: String(
                        localized: "account_toast_unlink_success",
                        bundle: PresentationResources.bundle
                    ),
                    systemImage: "checkmark.circle"
                )
                let providers = try await fetchProvidersUseCase.execute()
                await send(.setProviders(
                    currentProvider: providers.currentProvider,
                    allProviders: providers.allProviders
                ))
                await send(.loading(.end(target: .default, mode: .delayed)))
            } catch {
                await send(.loading(.end(target: .default, mode: .delayed)))
                await send(.setAlert(.error))
            }
        }
    }

    func deleteAuthEffect() -> Effect<Action> {
        .run { [deleteAuthUseCase] send in
            await send(.loading(.begin(target: .default, mode: .delayed)))
            do {
                try await deleteAuthUseCase.execute()
                // 유스케이스 완료가 LoginView 전환 완료를 의미하지 않으므로 화면이 교체될 때까지 로딩 유지
            } catch {
                // 로딩보다 알림창을 먼저 띄워 좁아진 창의 설정 화면이 알림창 전에 닫히지 않게 함
                await send(.setAlert(.error))
                await send(.loading(.end(target: .default, mode: .delayed)))
            }
        }
    }

    func signOutEffect() -> Effect<Action> {
        .run { [signOutUseCase] send in
            await send(.loading(.begin(target: .default, mode: .delayed)))
            do {
                try await signOutUseCase.execute()
                // 유스케이스 완료가 LoginView 전환 완료를 의미하지 않으므로 화면이 교체될 때까지 로딩 유지
            } catch {
                // 로딩보다 알림창을 먼저 띄워 좁아진 창의 설정 화면이 알림창 전에 닫히지 않게 함
                await send(.setAlert(.error))
                await send(.loading(.end(target: .default, mode: .delayed)))
            }
        }
    }

    static func linkAlertType(for error: Error) -> AlertType {
        guard let authError = error as? AuthError else {
            return .error
        }

        switch authError {
        case .linkEmailNotFound:
            return .linkEmailNotFound
        case .linkEmailMismatch:
            return .linkEmailMismatch
        case .linkCredentialAlreadyInUse:
            return .linkCredentialAlreadyInUse
        case .githubEmailConflict:
            return .githubEmailConflict
        case .notAuthenticated, .failedToUnlinkLastProvider, .emailNotFound, .unsupportedProvider:
            return .error
        }
    }

    static func alertState(for type: AlertType) -> AlertState<Action.Alert> {
        let title: String
        let message: String

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
        case .linkEmailNotFound:
            title = String(localized: "account_alert_email_unavailable_title", bundle: PresentationResources.bundle)
            message = String(localized: "account_alert_email_unavailable_message", bundle: PresentationResources.bundle)
        case .linkEmailMismatch:
            title = String(localized: "account_alert_cannot_link_title", bundle: PresentationResources.bundle)
            message = String(localized: "account_alert_cannot_link_message", bundle: PresentationResources.bundle)
        case .linkCredentialAlreadyInUse:
            title = String(localized: "account_alert_already_linked_title", bundle: PresentationResources.bundle)
            message = String(localized: "account_alert_already_linked_message", bundle: PresentationResources.bundle)
        case .githubEmailConflict:
            title = String(localized: "account_alert_github_email_conflict_title", bundle: PresentationResources.bundle)
            message = String(
                localized: "account_alert_github_email_conflict_message",
                bundle: PresentationResources.bundle
            )
        case .error:
            title = String(localized: "common_error_title", bundle: PresentationResources.bundle)
            message = String(localized: "common_error_message", bundle: PresentationResources.bundle)
        }

        return AlertState {
            TextState(title)
        } actions: {
            ButtonState(role: .cancel) {
                TextState(String(localized: "common_close", bundle: PresentationResources.bundle))
            }
        } message: {
            TextState(message)
        }
    }
}
