//
//  UserPreferencesRepositoryImpl.swift
//  Data
//
//  Created by 최윤진 on 2/25/26.
//

import Foundation
import Combine
import Core
import Domain

final class UserPreferencesRepositoryImpl: UserPreferencesRepository {
    private enum Key {
        static let theme = "theme"
        static let recentQueries = "Search.recentQueries"
        static let pushSortOrder = "PushNotification.sortOption"
        static let pushTimeFilter = "PushNotification.timeFilter"
        static let pushUnreadOnly = "PushNotification.showUnreadOnly"
        // 로그아웃하면 AuthSessionRepositoryImpl이 지우는 Session. 접두어 키
        static let sideBarWidth = "Session.SideBar.width"
    }

    private let store: UserDefaultsStore
    private let themeStore: ThemeStore
    private let widgetSnapshotPreferenceStore: WidgetSnapshotPreferenceStore
    private let widgetSyncEventBus: WidgetSyncEventBus

    init(
        store: UserDefaultsStore,
        themeStore: ThemeStore,
        widgetSnapshotPreferenceStore: WidgetSnapshotPreferenceStore,
        widgetSyncEventBus: WidgetSyncEventBus
    ) {
        self.store = store
        self.themeStore = themeStore
        self.widgetSnapshotPreferenceStore = widgetSnapshotPreferenceStore
        self.widgetSyncEventBus = widgetSyncEventBus
        themeStore.send(systemTheme())
    }

    func observeSystemTheme() -> AnyPublisher<SystemTheme, Never> {
        themeStore.observeTheme()
    }

    func systemTheme() -> SystemTheme {
        guard let rawValue = store.string(forKey: Key.theme),
              let theme = SystemTheme(rawValue: rawValue) else {
            return .automatic
        }
        return theme
    }

    func setSystemTheme(_ theme: SystemTheme) {
        store.setString(theme.rawValue, forKey: Key.theme)
        themeStore.send(theme)
    }

    func recentSearchQueries() -> [String] {
        store.stringArray(forKey: Key.recentQueries)
    }

    func setRecentSearchQueries(_ queries: [String]) {
        store.setStringArray(queries, forKey: Key.recentQueries)
    }

    func pushNotificationSortOrder() -> PushNotificationQuery.SortOrder {
        guard let rawValue = store.string(forKey: Key.pushSortOrder) else { return .latest }
        return rawValue == "oldest" ? .oldest : .latest
    }

    func setPushNotificationSortOrder(_ order: PushNotificationQuery.SortOrder) {
        let value = order == .oldest ? "oldest" : "latest"
        store.setString(value, forKey: Key.pushSortOrder)
    }

    func pushNotificationTimeFilter() -> PushNotificationQuery.TimeFilter {
        let id = store.string(forKey: Key.pushTimeFilter) ?? "none"
        return PushNotificationQuery.TimeFilter(id: id)
    }

    func setPushNotificationTimeFilter(_ filter: PushNotificationQuery.TimeFilter) {
        store.setString(filter.id, forKey: Key.pushTimeFilter)
    }

    func pushNotificationUnreadOnly() -> Bool {
        store.bool(forKey: Key.pushUnreadOnly)
    }

    func setPushNotificationUnreadOnly(_ value: Bool) {
        store.setBool(value, forKey: Key.pushUnreadOnly)
    }

    func heatmapActivityTypes() -> [String] {
        widgetSnapshotPreferenceStore.heatmapActivityTypes()
    }

    func setHeatmapActivityTypes(_ activityTypes: [String]) {
        widgetSnapshotPreferenceStore.setHeatmapActivityTypes(activityTypes)
        widgetSyncEventBus.publish(.refreshRequested)
    }

    func todayDisplayOptions() -> TodayDisplayOptions {
        widgetSnapshotPreferenceStore.todayDisplayOptions()
    }

    func setTodayDisplayOptions(_ options: TodayDisplayOptions) {
        widgetSnapshotPreferenceStore.setTodayDisplayOptions(options)
        widgetSyncEventBus.publish(.refreshRequested)
    }

    func sideBarWidth() -> Double? {
        store.value(forKey: Key.sideBarWidth)
    }

    func setSideBarWidth(_ width: Double) {
        store.setValue(width, forKey: Key.sideBarWidth)
    }
}
