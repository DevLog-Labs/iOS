//
//  DetailSideBarFeature.swift
//  Entry
//
//  Created by opfic on 11/25/26.
//

import Foundation
import PresentationShared

@Reducer
struct DetailSideBarFeature {
    @ObservableState
    struct State: Equatable {
        var isPresented = false
        // 탭마다 대상을 고르는 화면, 대상이 없어도 나타난 순서대로 위치
        var selections: [AppTab: [Selection]] = [:]

        // 탭마다 지금 고른 대상, 대상을 고른 화면 중 가장 나중에 나타난 화면의 대상
        var targets: [AppTab: DetailSideBarTarget] {
            selections.compactMapValues { $0.last { $0.target != nil }?.target }
        }
    }

    struct Selection: Equatable {
        let owner: UUID
        var target: DetailSideBarTarget?
    }

    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case targetChanged(AppTab, DetailSideBarTarget?, owner: UUID)
        case ownerRemoved(AppTab, owner: UUID)
    }

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                break
            case .targetChanged(let tab, let target, let owner):
                // 대상을 바꿔도 화면이 나타난 순서의 자리 유지
                var selections = state.selections[tab, default: []]
                if let index = selections.firstIndex(where: { $0.owner == owner }) {
                    selections[index].target = target
                } else {
                    selections.append(Selection(owner: owner, target: target))
                }
                state.selections[tab] = selections
            case .ownerRemoved(let tab, let owner):
                // 사라지는 화면은 자기 자리만 지우고, 그 아래 화면이 고른 대상을 다시 표시
                state.selections[tab]?.removeAll { $0.owner == owner }
            }

            return .none
        }
    }
}
