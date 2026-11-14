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
    @ObservableState
    struct State: Equatable {
        @Presents var alert: AlertState<Never>?
        var currentProvider: AuthProvider?
        var connectedProviders: [AuthProvider] = []
        var disconnectedProviders: [AuthProvider] = []
        var activeLoadingProvider: AuthProvider?
        var loading = LoadingFeature.State()
        var presentationContext: AuthPresentationContext?

        var isLoading: Bool {
            loading.isLoading
        }
    }

    enum Action {
        case alert(PresentationAction<Never>)
        case onAppear
        case linkWithProvider(AuthProvider)
        case setPresentationContext(AuthPresentationContext?)
        case unlinkFromProvider(AuthProvider)
        case setAlert(AlertType)
        case setProviders(currentProvider: AuthProvider?, allProviders: [AuthProvider])
        case loading(LoadingFeature.Action)
    }

    enum AlertType: Equatable {
        case linkEmailNotFound
        case linkEmailMismatch
        case linkCredentialAlreadyInUse
        case githubEmailConflict
        case error
    }

    @Dependency(\.fetchAuthProvidersUseCase) var fetchProvidersUseCase
    @Dependency(\.linkAuthProviderUseCase) var linkProviderUseCase
    @Dependency(\.unlinkAuthProviderUseCase) var unlinkProviderUseCase

    var body: some ReducerOf<Self> {
        Scope(state: \.loading, action: \.loading) {
            LoadingFeature()
        }
        Reduce { state, action in
            switch action {
            case .alert:
                break
            case .onAppear:
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

    static func alertState(for type: AlertType) -> AlertState<Never> {
        let title: String
        let message: String

        switch type {
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
