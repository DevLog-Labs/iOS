//
//  DetailSideBarFeatureTests.swift
//  EntryTests
//
//  Created by opfic on 11/25/26.
//

import Foundation
import PresentationShared
import Testing
@testable import Entry

@MainActor
struct DetailSideBarFeatureTests {
    @Test("DetailSideBarFeature는 사라지는 화면이 다른 화면이 고른 세부 정보 사이드바 대상을 지우지 않게 한다")
    func DetailSideBarFeature는_사라지는_화면이_다른_화면이_고른_세부_정보_사이드바_대상을_지우지_않게_한다() async {
        let store = TestStore(initialState: DetailSideBarFeature.State()) {
            DetailSideBarFeature()
        }
        store.exhaustivity = .off(showSkippedAssertions: false)
        let goal = UUID()
        let category = UUID()

        await store.send(.targetChanged(.home, .hosted, owner: goal))
        await store.send(.targetChanged(.home, .hosted, owner: category))
        await store.send(.ownerRemoved(.home, owner: goal))

        #expect(store.state.targets[.home] == .hosted)

        await store.send(.ownerRemoved(.home, owner: category))

        #expect(store.state.targets[.home] == nil)
    }

    @Test("DetailSideBarFeature는 위 화면이 사라지면 아래 화면이 고른 세부 정보 사이드바 대상을 다시 표시한다")
    func DetailSideBarFeature는_위_화면이_사라지면_아래_화면이_고른_세부_정보_사이드바_대상을_다시_표시한다() async {
        let store = TestStore(initialState: DetailSideBarFeature.State()) {
            DetailSideBarFeature()
        }
        store.exhaustivity = .off(showSkippedAssertions: false)
        let list = UUID()
        let editor = UUID()

        await store.send(.targetChanged(.home, .todo(id: "todo", isEditable: true), owner: list))
        await store.send(.targetChanged(.home, .hosted, owner: editor))
        await store.send(.targetChanged(.home, .todo(id: "other", isEditable: true), owner: list))

        #expect(store.state.targets[.home] == .hosted)

        await store.send(.ownerRemoved(.home, owner: editor))

        #expect(store.state.targets[.home] == .todo(id: "other", isEditable: true))
    }

    @Test("DetailSideBarFeature는 먼저 나타난 화면이 나중에 대상을 골라도 나중에 나타난 화면의 대상을 유지한다")
    func DetailSideBarFeature는_먼저_나타난_화면이_나중에_대상을_골라도_나중에_나타난_화면의_대상을_유지한다() async {
        let store = TestStore(initialState: DetailSideBarFeature.State()) {
            DetailSideBarFeature()
        }
        store.exhaustivity = .off(showSkippedAssertions: false)
        let list = UUID()
        let editor = UUID()

        await store.send(.targetChanged(.home, nil, owner: list))
        await store.send(.targetChanged(.home, .hosted, owner: editor))
        await store.send(.targetChanged(.home, .todo(id: "todo", isEditable: true), owner: list))

        #expect(store.state.targets[.home] == .hosted)

        await store.send(.ownerRemoved(.home, owner: editor))

        #expect(store.state.targets[.home] == .todo(id: "todo", isEditable: true))
    }
}
