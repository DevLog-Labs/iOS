//
//  AuthSessionRepositoryGraph.swift
//  Data
//
//  Created by opfic on 9/7/26.
//

import Cradle
import Domain

public struct AuthSessionRepositoryGraphInput {
    public let authService: AuthService
    public let todoCategoryService: TodoCategoryService
    public let store: MemoryCacheStore
    public let userDefaultsStore: UserDefaultsStore
    public let provider: AuthSessionStateProvider

    public init(
        authService: AuthService,
        todoCategoryService: TodoCategoryService,
        store: MemoryCacheStore,
        userDefaultsStore: UserDefaultsStore,
        provider: AuthSessionStateProvider
    ) {
        self.authService = authService
        self.todoCategoryService = todoCategoryService
        self.store = store
        self.userDefaultsStore = userDefaultsStore
        self.provider = provider
    }
}

@DependencyGraph(input: AuthSessionRepositoryGraphInput.self)
public final class AuthSessionRepositoryGraph {
    @Provide(.lazy)
    private func makeAuthSessionRepository() -> AuthSessionRepository {
        AuthSessionRepositoryImpl(
            authService: input.authService,
            todoCategoryService: input.todoCategoryService,
            store: input.store,
            userDefaultsStore: input.userDefaultsStore,
            provider: input.provider
        )
    }
}
