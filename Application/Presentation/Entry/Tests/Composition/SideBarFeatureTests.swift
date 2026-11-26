//
//  SideBarFeatureTests.swift
//  EntryTests
//
//  Created by opfic on 11/25/26.
//

import Foundation
import PresentationShared
import Testing
@testable import Entry

@MainActor
struct SideBarFeatureTests {
    @Test("SideBarFeature는 다른 경로로 하위 항목에 들어오면 그 묶음을 펼치고 묶음을 접어도 위치를 유지한다")
    func SideBarFeature는_다른_경로로_하위_항목에_들어오면_그_묶음을_펼치고_묶음을_접어도_위치를_유지한다() async {
        let store = TestStore(initialState: SideBarFeature.State()) {
            SideBarFeature()
        }

        await store.send(.locationChanged(.home, .todoCategory("issue"))) {
            $0.locations[.home] = .todoCategory("issue")
            $0.expandedGroups = [.todo]
        }
        await store.send(.tapGroup(.todo)) {
            $0.expandedGroups = []
        }
        #expect(store.state.locations[.home] == .todoCategory("issue"))
        await store.send(.locationChanged(.home, .developmentGoal("goal"))) {
            $0.locations[.home] = .developmentGoal("goal")
            $0.expandedGroups = [.developmentGoal]
        }
    }

    @Test("SideBarFeature는 칸에 작성 화면을 그린 탭의 사이드바 이동 요청을 무시한다")
    func SideBarFeature는_칸에_작성_화면을_그린_탭의_사이드바_이동_요청을_무시한다() async {
        let store = TestStore(initialState: SideBarFeature.State()) {
            SideBarFeature()
        } withDependencies: {
            $0.uuid = .incrementing
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.paneEditingChanged(.home, true))
        await store.send(.tapItem(.home, .open(.home)))

        #expect(store.state.requests[.home] == nil)

        await store.send(.paneEditingChanged(.home, false))
        await store.send(.tapItem(.home, .open(.home)))

        #expect(store.state.requests[.home]?.action == .open(.home))
    }
}
