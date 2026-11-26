//
//  SideBarFeature.swift
//  Entry
//
//  Created by opfic on 11/25/26.
//

import Domain
import Foundation
import PresentationShared

@Reducer
struct SideBarFeature {
    enum Group: Hashable {
        case todo
        case developmentGoal
    }

    @ObservableState
    struct State: Equatable {
        var isCollapsed = false
        // 사용자가 끌어서 정한 폭, 정하지 않았으면 기본 폭
        var width: CGFloat?
        var expandedGroups: Set<Group> = []
        var locations: [AppTab: SideBarLocation] = [:]
        var requests: [AppTab: SideBarRequest] = [:]
        // 칸에 작성 화면을 그린 탭, 덮는 화면처럼 닫기나 저장 버튼으로 닫기 전에는 사이드바로 이동하지 않음
        var paneEditingTabs: Set<AppTab> = []
        var content = SideBarContent()
    }

    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case locationChanged(AppTab, SideBarLocation)
        case contentChanged(SideBarContent)
        case paneEditingChanged(AppTab, Bool)
        case resized(CGFloat)
        case tapGroup(Group)
        case tapItem(AppTab, SideBarRequest.Action)
        case tapSettings
    }

    @Dependency(\.uuid) var uuid
    @Dependency(\.updateSideBarWidthUseCase) var updateSideBarWidthUseCase

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                break
            case .locationChanged(let tab, let location):
                state.locations[tab] = location
                // 홈 카테고리 격자처럼 다른 경로로 하위 항목에 들어오면 그 묶음을 펼침
                switch location {
                case .todoCategory:
                    state.expandedGroups.insert(.todo)
                case .developmentGoal:
                    state.expandedGroups.insert(.developmentGoal)
                case .home, .todoCategoryManagement, .search, .today, .notification, .profile, .settings:
                    break
                }
            case .contentChanged(let content):
                state.content = content
            case .paneEditingChanged(let tab, let isEditing):
                if isEditing {
                    state.paneEditingTabs.insert(tab)
                } else {
                    state.paneEditingTabs.remove(tab)
                }
            case .resized(let width):
                state.width = width
                return .run { [updateSideBarWidthUseCase] _ in
                    updateSideBarWidthUseCase.execute(Double(width))
                }
            case .tapGroup(let group):
                if state.expandedGroups.contains(group) {
                    state.expandedGroups.remove(group)
                } else {
                    state.expandedGroups.insert(group)
                }
            case .tapItem(let tab, let action):
                guard !state.paneEditingTabs.contains(tab) else { break }
                state.requests[tab] = SideBarRequest(id: uuid(), action: action)
            case .tapSettings:
                break
            }

            return .none
        }
    }
}

extension DependencyValues {
    var fetchSideBarWidthUseCase: FetchSideBarWidthUseCase {
        get { self[FetchSideBarWidthUseCaseKey.self] }
        set { self[FetchSideBarWidthUseCaseKey.self] = newValue }
    }

    var updateSideBarWidthUseCase: UpdateSideBarWidthUseCase {
        get { self[UpdateSideBarWidthUseCaseKey.self] }
        set { self[UpdateSideBarWidthUseCaseKey.self] = newValue }
    }
}

private enum FetchSideBarWidthUseCaseKey: DependencyKey {
    static var liveValue: FetchSideBarWidthUseCase {
        preconditionFailure("FetchSideBarWidthUseCase must be provided.")
    }

    static var testValue: FetchSideBarWidthUseCase {
        liveValue
    }
}

private enum UpdateSideBarWidthUseCaseKey: DependencyKey {
    static var liveValue: UpdateSideBarWidthUseCase {
        preconditionFailure("UpdateSideBarWidthUseCase must be provided.")
    }

    static var testValue: UpdateSideBarWidthUseCase {
        liveValue
    }
}
