//
//  SideBarNavigation.swift
//  PresentationShared
//
//  Created by opfic on 11/15/26.
//

import SwiftUI

// Mac 사이드바 트리에서 고르는 위치
public enum SideBarLocation: Hashable {
    case home
    case today
    case notification
    case todoCategory(String)
    case developmentGoal(String)
    case profile
    case settings
}

public struct SideBarGoal: Hashable, Identifiable {
    public let id: String
    public let title: String

    public init(id: String, title: String) {
        self.id = id
        self.title = title
    }
}

// Todo, 개발 목표 묶음의 하위 항목
public struct SideBarContent: Equatable {
    public var todoCategories: [TodoCategoryItem]
    public var developmentGoals: [SideBarGoal]

    public init(
        todoCategories: [TodoCategoryItem] = [],
        developmentGoals: [SideBarGoal] = []
    ) {
        self.todoCategories = todoCategories
        self.developmentGoals = developmentGoals
    }
}

// 사이드바에서 탭 화면으로 보내는 이동과 작성 요청
public struct SideBarRequest: Equatable {
    public enum Action: Equatable {
        case open(SideBarLocation)
        case createTodo
        case manageTodoCategory
    }

    public let id: UUID
    public let action: Action

    public init(id: UUID, action: Action) {
        self.id = id
        self.action = action
    }
}

// 탭 화면이 지금 보여 주는 사이드바 위치 보고
public struct SideBarLocationPreferenceKey: PreferenceKey {
    public static let defaultValue: SideBarLocation? = nil

    public static func reduce(value: inout SideBarLocation?, nextValue: () -> SideBarLocation?) {
        value = nextValue() ?? value
    }
}

// 탭 화면이 불러온 묶음 하위 항목 보고
public struct SideBarContentPreferenceKey: PreferenceKey {
    public static let defaultValue: SideBarContent? = nil

    public static func reduce(value: inout SideBarContent?, nextValue: () -> SideBarContent?) {
        value = nextValue() ?? value
    }
}
