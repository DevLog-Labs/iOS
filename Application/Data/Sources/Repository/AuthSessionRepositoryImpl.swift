//
//  AuthSessionRepositoryImpl.swift
//  Data
//
//  Created by 최윤진 on 12/31/25.
//

import Combine
import Domain

final class AuthSessionRepositoryImpl: AuthSessionRepository {
    private enum Key {
        static let preferences = "TodoCategory.preferences"
        // 로그아웃하면 지우는 로그인 세션 동안의 설정 키 접두어
        static let sessionPreferencesPrefix = "Session."
    }

    private let authService: AuthService
    private let todoCategoryService: TodoCategoryService
    private let store: MemoryCacheStore
    private let userDefaultsStore: UserDefaultsStore
    private let provider: AuthSessionStateProvider
    private var cancellables = Set<AnyCancellable>()

    init(
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

        setupObservation()
    }

    func observeSignedIn() -> AnyPublisher<Bool, Never> {
        provider.observeSignedIn()
    }
}

private extension AuthSessionRepositoryImpl {
    func setupObservation() {
        authService.observeSignedIn()
            .removeDuplicates()
            .sink { [weak self] isSignedIn in
                Task { [weak self] in
                    guard let self else { return }

                    if isSignedIn {
                        await self.cachePreferencesIfNeeded()
                    } else {
                        self.clearPreferencesCache()
                    }
                    self.provider.publish(isSignedIn)
                }
            }
            .store(in: &cancellables)
    }

    func cachePreferencesIfNeeded() async {
        if store.value(forKey: Key.preferences) as [TodoCategoryPreferenceResponse]? != nil {
            return
        }

        guard let preferences = try? await todoCategoryService.fetchCategoryPreferences() else {
            return
        }

        store.setValue(preferences, forKey: Key.preferences)
    }

    func clearPreferencesCache() {
        store.setValue(Optional<[TodoCategoryPreferenceResponse]>.none, forKey: Key.preferences)
        userDefaultsStore.removeValues(withPrefix: Key.sessionPreferencesPrefix)
    }
}
