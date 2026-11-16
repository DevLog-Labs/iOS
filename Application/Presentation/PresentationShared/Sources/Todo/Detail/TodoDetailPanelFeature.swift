//
//  TodoDetailPanelFeature.swift
//  PresentationShared
//
//  Created by opfic on 11/16/26.
//

import ComposableArchitecture

// Mac 상세 판의 보기 전용 Todo 상세와 판 안 세부 정보 열
@Reducer
public struct TodoDetailPanelFeature {
    @ObservableState
    public struct State: Equatable {
        var detail: TodoDetailFeature.State
        // 판 메뉴의 중요 표시와 완료도 세부 정보 열과 같이 바로 저장
        var sideBar: TodoDetailSideBarFeature.State
        var isDetailColumnPresented = false

        public init(todoId: String, isEditable: Bool) {
            self.detail = TodoDetailFeature.State(todoId: todoId, showEditButton: false)
            self.sideBar = TodoDetailSideBarFeature.State(todoId: todoId, isEditable: isEditable)
        }
    }

    public enum Action: BindableAction {
        case binding(BindingAction<State>)
        case detail(TodoDetailFeature.Action)
        case sideBar(TodoDetailSideBarFeature.Action)
    }

    public init() { }

    public var body: some ReducerOf<Self> {
        BindingReducer()
        Scope(state: \.detail, action: \.detail) {
            TodoDetailFeature()
        }
        Scope(state: \.sideBar, action: \.sideBar) {
            TodoDetailSideBarFeature()
        }
    }
}
