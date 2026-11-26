//
//  AppTab.swift
//  Entry
//
//  Created by opfic on 4/30/26.
//

import Foundation
import PresentationShared

public enum AppTab: Hashable, CaseIterable {
    case home
    case today
    case notification
    case profile

    var title: String {
        switch self {
        case .home:
            String(localized: "nav_home", bundle: PresentationResources.bundle)
        case .today:
            String(localized: "nav_today", bundle: PresentationResources.bundle)
        case .notification:
            String(localized: "nav_notifications", bundle: PresentationResources.bundle)
        case .profile:
            String(localized: "nav_profile", bundle: PresentationResources.bundle)
        }
    }

    var symbolName: String {
        switch self {
        case .home:
            "house.fill"
        case .today:
            "sun.max.fill"
        case .notification:
            "bell.fill"
        case .profile:
            "person.crop.circle.fill"
        }
    }

    // 탭 화면이 위치를 알리기 전 사이드바에 표시하는 위치
    var sideBarLocation: SideBarLocation {
        switch self {
        case .home:
            .home
        case .today:
            .today
        case .notification:
            .notification
        case .profile:
            .profile
        }
    }
}

extension SideBarLocation {
    var tab: AppTab {
        switch self {
        case .home, .todoCategory, .todoCategoryManagement, .developmentGoal, .search:
            .home
        case .today:
            .today
        case .notification:
            .notification
        case .profile, .settings:
            .profile
        }
    }
}
