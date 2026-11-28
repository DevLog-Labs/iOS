//
//  SideBarNavigation.swift
//  PresentationShared
//
//  Created by opfic on 11/15/26.
//

import SwiftUI

// 사이드바 트리에서 고르는 위치
public enum SideBarLocation: Hashable {
    case home
    case today
    case notification
    case todoCategory(String)
    // 사이드바 트리의 Todo 묶음에서 연 카테고리 관리
    case todoCategoryManagement
    case developmentGoal(String)
    // 사이드바 항목이 아닌 홈 검색, 사이드바에서 아무 항목도 고르지 않은 상태
    case search
    case profile
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

public extension View {
    // 탭 루트 화면이 사이드바에 표시할 위치와 묶음 하위 항목을 올리고 사이드바 요청을 받음
    // 사이드바가 있는 창으로 켜지거나 좁은 창에서 넓어지면 하위 항목을 채우도록 onLoad 호출
    func compositionLeft(
        location: SideBarLocation,
        content: SideBarContent,
        onLoad: @escaping () -> Void,
        onRequest: @escaping (SideBarRequest) -> Void
    ) -> some View {
        modifier(CompositionLeftModifier(
            location: location,
            sideBarContent: content,
            onLoad: onLoad,
            onRequest: onRequest
        ))
    }
}

private struct CompositionLeftModifier: ViewModifier {
    @Environment(\.sideBarRequest) private var sideBarRequest
    @Environment(\.usesDesktopLayout) private var usesDesktopLayout
    let location: SideBarLocation
    let sideBarContent: SideBarContent
    let onLoad: () -> Void
    let onRequest: (SideBarRequest) -> Void

    func body(content: Content) -> some View {
        content
            .preference(key: SideBarLocationPreferenceKey.self, value: location)
            .preference(key: SideBarContentPreferenceKey.self, value: sideBarContent)
            // 사이드바 요청으로 처음 여는 탭도 그 요청을 반영
            .onChange(of: sideBarRequest, initial: true) { _, request in
                if let request {
                    onRequest(request)
                }
            }
            .onChange(of: usesDesktopLayout, initial: true) { _, usesDesktopLayout in
                if usesDesktopLayout {
                    onLoad()
                }
            }
    }
}
