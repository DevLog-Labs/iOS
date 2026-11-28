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
    }

    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
    }

    var body: some ReducerOf<Self> {
        BindingReducer()
    }
}
