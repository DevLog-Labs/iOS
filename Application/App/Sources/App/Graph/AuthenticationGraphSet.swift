//
//  AuthenticationGraphSet.swift
//  App
//
//  Created by opfic on 9/7/26.
//

import Data
import Domain
import Infra
import Persistence
import Widget

final class AuthenticationGraphSet {
    let authenticationRepositoryGraph: AuthenticationRepositoryGraph
    let authDataRepositoryGraph: AuthDataRepositoryGraph
    let authSessionRepositoryGraph: AuthSessionRepositoryGraph
    let authenticationUseCaseGraph: AuthenticationUseCaseGraph
    let authProviderUseCaseGraph: AuthProviderUseCaseGraph
    private(set) lazy var authSessionUseCaseGraph = AuthSessionUseCaseGraph(
        input: AuthSessionUseCaseGraphInput(
            repository: authSessionRepositoryGraph.authSessionRepository
        )
    )

    init(
        authServiceGraph: AuthServiceGraph,
        appleAuthenticationServiceGraph: AppleAuthenticationServiceGraph,
        githubAuthenticationServiceGraph: GithubAuthenticationServiceGraph,
        googleAuthenticationServiceGraph: GoogleAuthenticationServiceGraph,
        userServiceGraph: UserServiceGraph,
        todoCategoryServiceGraph: TodoCategoryServiceGraph,
        memoryCacheStoreGraph: MemoryCacheStoreGraph,
        userDefaultsStoreGraph: UserDefaultsStoreGraph,
        widgetSnapshotUpdaterGraph: WidgetSnapshotUpdaterGraph,
        authSessionStateProviderGraph: AuthSessionStateProviderGraph
    ) {
        self.authenticationRepositoryGraph = AuthenticationRepositoryGraph(
            input: AuthenticationRepositoryGraphInput(
                authService: authServiceGraph.authService,
                appleAuthService: appleAuthenticationServiceGraph.appleAuthenticationService,
                githubAuthService: githubAuthenticationServiceGraph.githubAuthenticationService,
                googleAuthService: googleAuthenticationServiceGraph.googleAuthenticationService,
                userService: userServiceGraph.userService,
                widgetSnapshotUpdater: widgetSnapshotUpdaterGraph.widgetSnapshotUpdater
            )
        )
        self.authDataRepositoryGraph = AuthDataRepositoryGraph(
            input: AuthDataRepositoryGraphInput(
                authService: authServiceGraph.authService,
                appleAuthService: appleAuthenticationServiceGraph.appleAuthenticationService,
                githubAuthService: githubAuthenticationServiceGraph.githubAuthenticationService,
                googleAuthService: googleAuthenticationServiceGraph.googleAuthenticationService
            )
        )
        self.authSessionRepositoryGraph = AuthSessionRepositoryGraph(
            input: AuthSessionRepositoryGraphInput(
                authService: authServiceGraph.authService,
                todoCategoryService: todoCategoryServiceGraph.todoCategoryService,
                store: memoryCacheStoreGraph.memoryCacheStore,
                userDefaultsStore: userDefaultsStoreGraph.userDefaultsStore,
                provider: authSessionStateProviderGraph.authSessionStateProvider
            )
        )
        self.authenticationUseCaseGraph = AuthenticationUseCaseGraph(
            input: AuthenticationUseCaseGraphInput(
                repository: authenticationRepositoryGraph.authenticationRepository
            )
        )
        self.authProviderUseCaseGraph = AuthProviderUseCaseGraph(
            input: AuthProviderUseCaseGraphInput(
                repository: authDataRepositoryGraph.authDataRepository
            )
        )
    }
}
