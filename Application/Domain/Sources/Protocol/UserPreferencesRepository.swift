//
//  UserPreferencesRepository.swift
//  Domain
//
//  Created by 최윤진 on 2/25/26.
//

import Foundation
import Combine
import Core

public protocol UserPreferencesRepository {
    func observeSystemTheme() -> AnyPublisher<SystemTheme, Never>
    func systemTheme() -> SystemTheme
    func setSystemTheme(_ theme: SystemTheme)

    func recentSearchQueries() -> [String]
    func setRecentSearchQueries(_ queries: [String])

    func pushNotificationSortOrder() -> PushNotificationQuery.SortOrder
    func setPushNotificationSortOrder(_ order: PushNotificationQuery.SortOrder)

    func pushNotificationTimeFilter() -> PushNotificationQuery.TimeFilter
    func setPushNotificationTimeFilter(_ filter: PushNotificationQuery.TimeFilter)

    func pushNotificationUnreadOnly() -> Bool
    func setPushNotificationUnreadOnly(_ value: Bool)

    func heatmapActivityTypes() -> [String]
    func setHeatmapActivityTypes(_ activityTypes: [String])

    func todayDisplayOptions() -> TodayDisplayOptions
    func setTodayDisplayOptions(_ options: TodayDisplayOptions)

    // 로그아웃하면 지워지는 Mac 사이드바 폭
    func sideBarWidth() -> Double?
    func setSideBarWidth(_ width: Double)
}
