//
//  AppGraph+PresentationDependencies.swift
//  App
//
//  Created by opfic on 9/7/26.
//

import Presentation

extension AppGraph {
    func preparePresentationDependencies() {
        prepareDependencies { dependencies in
            prepareEntryDependencies(&dependencies)
            prepareDevelopmentDependencies(&dependencies)
            prepareTodoDependencies(&dependencies)
            prepareHomeDependencies(&dependencies)
            prepareTodayDependencies(&dependencies)
            prepareNotificationDependencies(&dependencies)
            prepareProfileDependencies(&dependencies)
        }
    }
}

private extension AppGraph {
    func prepareDevelopmentDependencies(_ dependencies: inout DependencyValues) {
        DevelopmentDependencyPreparation.prepareGoal(
            &dependencies,
            createGoalUseCase: developmentGraphSet
                .developmentGoalUseCaseGraph
                .createDevelopmentGoalUseCase,
            fetchGoalUseCase: developmentGraphSet
                .developmentGoalUseCaseGraph
                .fetchDevelopmentGoalUseCase,
            updateGoalStatusUseCase: developmentGraphSet
                .developmentGoalUseCaseGraph
                .updateDevelopmentGoalStatusUseCase
        )
        DevelopmentDependencyPreparation.prepareQuery(
            &dependencies,
            fetchRecordsUseCase: developmentGraphSet
                .developmentRecordQueryUseCaseGraph
                .fetchDevelopmentRecordsUseCase,
            fetchRecordHistoryUseCase: developmentGraphSet
                .developmentRecordQueryUseCaseGraph
                .fetchDevelopmentRecordHistoryUseCase,
            fetchRecordVersionUseCase: developmentGraphSet
                .developmentRecordQueryUseCaseGraph
                .fetchDevelopmentRecordVersionUseCase
        )
        DevelopmentDependencyPreparation.prepareMutation(
            &dependencies,
            createRecordUseCase: developmentGraphSet
                .developmentRecordMutationUseCaseGraph
                .createDevelopmentRecordUseCase,
            saveRecordDraftUseCase: developmentGraphSet
                .developmentRecordMutationUseCaseGraph
                .saveDevelopmentRecordDraftUseCase,
            confirmRecordUseCase: developmentGraphSet
                .developmentRecordMutationUseCaseGraph
                .confirmDevelopmentRecordUseCase,
            restoreRecordUseCase: developmentGraphSet
                .developmentRecordMutationUseCaseGraph
                .restoreDevelopmentRecordUseCase
        )
        DevelopmentDependencyPreparation.prepareTodo(
            &dependencies,
            fetchTodosUseCase: todoGraphSet.todoUseCaseGraph.fetchTodosUseCase,
            updateTodoGoalUseCase: todoGraphSet.todoGoalUseCaseGraph.updateTodoGoalUseCase
        )
    }

    func prepareEntryDependencies(_ dependencies: inout DependencyValues) {
        PresentationDependencyPreparation.prepareRoot(
            &dependencies,
            sessionUseCase: authenticationGraphSet.authSessionUseCaseGraph.observeAuthSessionUseCase,
            networkConnectivityUseCase: networkConnectivityGraphSet
                .networkConnectivityUseCaseGraph
                .observeNetworkConnectivityUseCase,
            systemThemeUseCase: userPreferencesGraphSet
                .userPreferencesUseCaseGraph
                .observeSystemThemeUseCase,
            checkAppUpdateUseCase: appUpdateGraphSet.appUpdateUseCaseGraph.checkAppUpdateUseCase
        )
        PresentationDependencyPreparation.prepareLogin(
            &dependencies,
            signInUseCase: authenticationGraphSet.authenticationUseCaseGraph.signInUseCase
        )
        PresentationDependencyPreparation.prepareMain(
            &dependencies,
            observeUnreadPushCountUseCase: pushNotificationGraphSet
                .pushNotificationUseCaseGraph
                .observeUnreadPushCountUseCase
        )
    }

    func prepareTodoDependencies(_ dependencies: inout DependencyValues) {
        TodoDependencyPreparation.prepareDetail(
            &dependencies,
            fetchTodoByIdUseCase: todoGraphSet.todoUseCaseGraph.fetchTodoByIdUseCase,
            fetchReferenceItemsUseCase: todoGraphSet.todoUseCaseGraph.fetchReferenceItemsUseCase
        )
        TodoDependencyPreparation.prepareEditor(
            &dependencies,
            fetchTodoCategoryPreferencesUseCase: todoGraphSet
                .todoCategoryUseCaseGraph
                .fetchTodoCategoryPreferencesUseCase,
            fetchReferenceItemsUseCase: todoGraphSet.todoUseCaseGraph.fetchReferenceItemsUseCase,
            upsertTodoUseCase: todoGraphSet.todoUseCaseGraph.upsertTodoUseCase
        )
        HomePresentationDependencyPreparation.prepareTodoListQuery(
            &dependencies,
            fetchTodosUseCase: todoGraphSet.todoUseCaseGraph.fetchTodosUseCase,
            fetchTodoByIdUseCase: todoGraphSet.todoUseCaseGraph.fetchTodoByIdUseCase,
            fetchReferenceItemsUseCase: todoGraphSet.todoUseCaseGraph.fetchReferenceItemsUseCase,
            fetchTodoCategoryPreferencesUseCase: todoGraphSet
                .todoCategoryUseCaseGraph
                .fetchTodoCategoryPreferencesUseCase
        )
        HomePresentationDependencyPreparation.prepareTodoListMutation(
            &dependencies,
            upsertTodoUseCase: todoGraphSet.todoUseCaseGraph.upsertTodoUseCase,
            deleteTodoUseCase: todoGraphSet.todoUseCaseGraph.deleteTodoUseCase,
            undoDeleteTodoUseCase: todoGraphSet.todoUseCaseGraph.undoDeleteTodoUseCase,
            trackAnalyticsEventUseCase: analyticsGraphSet
                .analyticsUseCaseGraph
                .trackAnalyticsEventUseCase
        )
    }

    func prepareHomeDependencies(_ dependencies: inout DependencyValues) {
        HomePresentationDependencyPreparation.prepareDevelopmentGoal(
            &dependencies,
            fetchGoalsUseCase: developmentGraphSet
                .developmentGoalUseCaseGraph
                .fetchDevelopmentGoalsUseCase,
            recentRecordUseCase: developmentGraphSet
                .developmentRecordQueryUseCaseGraph
                .fetchRecentDevelopmentRecordUseCase,
            fetchTodosUseCase: todoGraphSet.todoUseCaseGraph.fetchTodosUseCase
        )
        HomePresentationDependencyPreparation.prepareTodoCategory(
            &dependencies,
            updateTodoCategoryPreferencesUseCase: todoGraphSet
                .todoCategoryUseCaseGraph
                .updateTodoCategoryPreferencesUseCase
        )
        HomePresentationDependencyPreparation.prepareTodo(
            &dependencies,
            networkConnectivityUseCase: networkConnectivityGraphSet
                .networkConnectivityUseCaseGraph
                .observeNetworkConnectivityUseCase
        )
        HomePresentationDependencyPreparation.prepareSearch(
            &dependencies,
            fetchRecentSearchQueriesUseCase: userPreferencesGraphSet
                .userPreferencesUseCaseGraph
                .fetchRecentSearchQueriesUseCase,
            fetchTodosUseCase: todoGraphSet.todoUseCaseGraph.fetchTodosUseCase,
            updateRecentSearchQueriesUseCase: userPreferencesGraphSet
                .userPreferencesUseCaseGraph
                .updateRecentSearchQueriesUseCase
        )
    }

    func prepareTodayDependencies(_ dependencies: inout DependencyValues) {
        TodayPresentationDependencyPreparation.prepare(
            &dependencies,
            fetchTodosUseCase: todoGraphSet.todoUseCaseGraph.fetchTodosUseCase,
            fetchCategoryPreferencesUseCase: todoGraphSet
                .todoCategoryUseCaseGraph
                .fetchTodoCategoryPreferencesUseCase
        )
    }

    func prepareNotificationDependencies(_ dependencies: inout DependencyValues) {
        NotificationDependencyPreparation.prepareQuery(
            &dependencies,
            fetchQueryUseCase: userPreferencesGraphSet
                .userPreferencesUseCaseGraph
                .fetchPushNotificationQueryUseCase,
            updateQueryUseCase: userPreferencesGraphSet
                .userPreferencesUseCaseGraph
                .updatePushNotificationQueryUseCase
        )
        NotificationDependencyPreparation.prepareList(
            &dependencies,
            fetchNotificationsUseCase: pushNotificationGraphSet
                .pushNotificationUseCaseGraph
                .fetchPushNotificationsUseCase,
            deleteNotificationUseCase: pushNotificationGraphSet
                .pushNotificationUseCaseGraph
                .deletePushNotificationUseCase,
            undoDeleteNotificationUseCase: pushNotificationGraphSet
                .pushNotificationUseCaseGraph
                .undoDeletePushNotificationUseCase
        )
        NotificationDependencyPreparation.prepareReadState(
            &dependencies,
            toggleNotificationReadUseCase: pushNotificationGraphSet
                .pushNotificationUseCaseGraph
                .togglePushNotificationReadUseCase
        )
    }

    func prepareProfileDependencies(_ dependencies: inout DependencyValues) {
        ProfilePresentationDependencyPreparation.prepareDevelopmentGoals(
            &dependencies,
            fetchGoalsUseCase: developmentGraphSet
                .developmentGoalUseCaseGraph
                .fetchDevelopmentGoalsUseCase
        )
        ProfilePresentationDependencyPreparation.prepareUser(
            &dependencies,
            fetchUserDataUseCase: userProfileGraphSet.userDataUseCaseGraph.fetchUserDataUseCase,
            fetchProfileImageDataUseCase: userProfileGraphSet
                .profileImageDataUseCaseGraph
                .fetchProfileImageDataUseCase,
            upsertStatusMessageUseCase: userProfileGraphSet
                .userDataUseCaseGraph
                .upsertStatusMessageUseCase
        )
        ProfilePresentationDependencyPreparation.prepareActivity(
            &dependencies,
            fetchTodosUseCase: todoGraphSet.todoUseCaseGraph.fetchTodosUseCase,
            networkConnectivityUseCase: networkConnectivityGraphSet
                .networkConnectivityUseCaseGraph
                .observeNetworkConnectivityUseCase,
            fetchHeatmapActivityTypesUseCase: userPreferencesGraphSet
                .userPreferencesUseCaseGraph
                .fetchHeatmapActivityTypesUseCase,
            updateHeatmapActivityTypesUseCase: userPreferencesGraphSet
                .userPreferencesUseCaseGraph
                .updateHeatmapActivityTypesUseCase
        )
        ProfilePresentationDependencyPreparation.prepareRecentTodos(
            &dependencies,
            todoMutationEventBus: todoGraphSet.todoMutationEventBusGraph.todoMutationEventBus
        )
        ProfilePresentationDependencyPreparation.prepareSettingsSession(
            &dependencies,
            deleteAuthUseCase: authenticationGraphSet.authenticationUseCaseGraph.deleteAuthUseCase,
            signOutUseCase: authenticationGraphSet.authenticationUseCaseGraph.signOutUseCase,
            networkConnectivityUseCase: networkConnectivityGraphSet
                .networkConnectivityUseCaseGraph
                .observeNetworkConnectivityUseCase
        )
        ProfilePresentationDependencyPreparation.prepareSettingsAppearance(
            &dependencies,
            systemThemeUseCase: userPreferencesGraphSet
                .userPreferencesUseCaseGraph
                .observeSystemThemeUseCase,
            updateSystemThemeUseCase: userPreferencesGraphSet
                .userPreferencesUseCaseGraph
                .updateSystemThemeUseCase
        )
        ProfilePresentationDependencyPreparation.prepareAccount(
            &dependencies,
            fetchAuthProvidersUseCase: authenticationGraphSet
                .authProviderUseCaseGraph
                .fetchAuthProvidersUseCase,
            linkAuthProviderUseCase: authenticationGraphSet
                .authProviderUseCaseGraph
                .linkAuthProviderUseCase,
            unlinkAuthProviderUseCase: authenticationGraphSet
                .authProviderUseCaseGraph
                .unlinkAuthProviderUseCase
        )
        ProfilePresentationDependencyPreparation.preparePushSettings(
            &dependencies,
            fetchPushSettingsUseCase: pushNotificationGraphSet
                .pushNotificationUseCaseGraph
                .fetchPushSettingsUseCase,
            updatePushSettingsUseCase: pushNotificationGraphSet
                .pushNotificationUseCaseGraph
                .updatePushSettingsUseCase
        )
    }
}
