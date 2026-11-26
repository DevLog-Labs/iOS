//
//  PresentationDependencyPreparation.swift
//  Entry
//
//  Created by opfic on 9/7/26.
//

import Domain
import HomeTab
import NotificationTab
import PresentationShared
import ProfileTab
import TodayTab

public enum PresentationDependencyPreparation {
    public static func prepareRoot(
        _ dependencies: inout DependencyValues,
        sessionUseCase: ObserveAuthSessionUseCase,
        networkConnectivityUseCase: ObserveNetworkConnectivityUseCase,
        systemThemeUseCase: ObserveSystemThemeUseCase,
        checkAppUpdateUseCase: CheckAppUpdateUseCase
    ) {
        dependencies.observeAuthSessionUseCase = sessionUseCase
        dependencies.rootNetworkConnectivityUseCase = networkConnectivityUseCase
        dependencies.rootSystemThemeUseCase = systemThemeUseCase
        dependencies.checkAppUpdateUseCase = checkAppUpdateUseCase
    }

    public static func prepareLogin(
        _ dependencies: inout DependencyValues,
        signInUseCase: SignInUseCase
    ) {
        dependencies.signInUseCase = signInUseCase
    }

    public static func prepareComposition(
        _ dependencies: inout DependencyValues,
        observeUnreadPushCountUseCase: ObserveUnreadPushCountUseCase,
        fetchSideBarWidthUseCase: FetchSideBarWidthUseCase,
        updateSideBarWidthUseCase: UpdateSideBarWidthUseCase
    ) {
        dependencies.observeUnreadPushCountUseCase = observeUnreadPushCountUseCase
        dependencies.fetchSideBarWidthUseCase = fetchSideBarWidthUseCase
        dependencies.updateSideBarWidthUseCase = updateSideBarWidthUseCase
    }
}

public typealias HomePresentationDependencyPreparation = HomeDependencyPreparation
public typealias NotificationDependencyPreparation = PushNotificationDependencyPreparation
public typealias ProfilePresentationDependencyPreparation = ProfileDependencyPreparation
public typealias TodayPresentationDependencyPreparation = TodayDependencyPreparation

public typealias DevelopmentDependencyPreparation = HomeTab.DevelopmentDependencyPreparation
