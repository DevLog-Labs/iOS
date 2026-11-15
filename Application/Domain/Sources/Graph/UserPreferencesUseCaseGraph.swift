//
//  UserPreferencesUseCaseGraph.swift
//  Domain
//
//  Created by opfic on 9/7/26.
//

import Cradle

public struct UserPreferencesUseCaseGraphInput {
    public let repository: UserPreferencesRepository

    public init(repository: UserPreferencesRepository) {
        self.repository = repository
    }
}

@DependencyGraph(input: UserPreferencesUseCaseGraphInput.self)
public final class UserPreferencesUseCaseGraph {
    @Provide
    private func makeObserveSystemThemeUseCase() -> ObserveSystemThemeUseCase {
        ObserveSystemThemeUseCaseImpl(input.repository)
    }

    @Provide
    private func makeUpdateSystemThemeUseCase() -> UpdateSystemThemeUseCase {
        UpdateSystemThemeUseCaseImpl(input.repository)
    }

    @Provide
    private func makeFetchRecentSearchQueriesUseCase() -> FetchRecentSearchQueriesUseCase {
        FetchRecentSearchQueriesUseCaseImpl(input.repository)
    }

    @Provide
    private func makeUpdateRecentSearchQueriesUseCase() -> UpdateRecentSearchQueriesUseCase {
        UpdateRecentSearchQueriesUseCaseImpl(input.repository)
    }

    @Provide
    private func makeFetchPushNotificationQueryUseCase() -> FetchPushNotificationQueryUseCase {
        FetchPushNotificationQueryUseCaseImpl(input.repository)
    }

    @Provide
    private func makeUpdatePushNotificationQueryUseCase() -> UpdatePushNotificationQueryUseCase {
        UpdatePushNotificationQueryUseCaseImpl(input.repository)
    }

    @Provide
    private func makeFetchHeatmapActivityTypesUseCase() -> FetchHeatmapActivityTypesUseCase {
        FetchHeatmapActivityTypesUseCaseImpl(input.repository)
    }

    @Provide
    private func makeUpdateHeatmapActivityTypesUseCase() -> UpdateHeatmapActivityTypesUseCase {
        UpdateHeatmapActivityTypesUseCaseImpl(input.repository)
    }

    @Provide
    private func makeFetchTodayDisplayOptionsUseCase() -> FetchTodayDisplayOptionsUseCase {
        FetchTodayDisplayOptionsUseCaseImpl(input.repository)
    }

    @Provide
    private func makeUpdateTodayDisplayOptionsUseCase() -> UpdateTodayDisplayOptionsUseCase {
        UpdateTodayDisplayOptionsUseCaseImpl(input.repository)
    }

    @Provide
    private func makeFetchSideBarWidthUseCase() -> FetchSideBarWidthUseCase {
        FetchSideBarWidthUseCaseImpl(input.repository)
    }

    @Provide
    private func makeUpdateSideBarWidthUseCase() -> UpdateSideBarWidthUseCase {
        UpdateSideBarWidthUseCaseImpl(input.repository)
    }
}
