//
//  GoalDetailDestinationTests.swift
//  DevelopmentTests
//
//  Created by opfic on 9/19/26.
//

import Domain
import Foundation
import PresentationShared
import Testing
@testable import HomeTab

@MainActor
struct GoalDetailDestinationTests {
    @Test("새 기록과 초안은 편집 목적지를 표시한다")
    func 새_기록과_초안은_편집_목적지를_표시한다() async throws {
        let goal = try makeDevelopmentGoal()
        let draft = try makeDevelopmentRecord(id: "draft")
        let item = RecordTimelineItem(record: draft, currentVersion: nil)
        var state = GoalDetailFeature.State(goalId: goal.id)
        state.goal = goal
        state.items = [item]
        state.hasLoaded = true
        let store = TestStore(initialState: state) {
            GoalDetailFeature()
        } withDependencies: {
            $0.uuid = .incrementing
        }

        await store.send(.view(.addRecord)) {
            $0.recordEditor = RecordEditorFeature.State(
                goalId: goal.id,
                goalTitle: goal.title,
                recordId: UUID(0).uuidString,
                versionId: UUID(1).uuidString
            )
        }
        await store.send(.recordEditor(.dismiss)) {
            $0.recordEditor = nil
        }
        await store.send(.view(.continueRecord)) {
            $0.recordEditor = RecordEditorFeature.State(
                goalId: goal.id,
                goalTitle: goal.title,
                record: draft,
                versionId: UUID(2).uuidString
            )
        }
    }

    @Test("확정 기록 선택은 상세 목적지를 표시한다")
    func 확정_기록_선택은_상세_목적지를_표시한다() async throws {
        let goal = try makeDevelopmentGoal()
        let record = try makeConfirmedDevelopmentRecord(id: "record")
        let version = try makeDevelopmentRecordVersion(recordId: record.id)
        let item = RecordTimelineItem(record: record, currentVersion: version)
        var state = GoalDetailFeature.State(goalId: goal.id)
        state.goal = goal
        state.items = [item]
        let store = TestStore(initialState: state) {
            GoalDetailFeature()
        }

        await store.send(.view(.selectRecord(item))) {
            $0.recordDetail = RecordDetailDestination(record: record)
        }
        await store.send(.recordDetail(.dismiss)) {
            $0.recordDetail = nil
            $0.dismissedRecordDetail = RecordDetailDestination(record: record)
        }
        await store.receive(.store(.recordDetailDismissed)) {
            $0.dismissedRecordDetail = nil
        }
        await store.send(.view(.selectRecord(item))) {
            $0.recordDetail = RecordDetailDestination(record: record)
        }
    }

    @Test("창 폭이 바뀌며 같은 차례에 닫힌 기록 상세는 새 자리에서 다시 표시한다")
    func 창_폭이_바뀌며_같은_차례에_닫힌_기록_상세는_새_자리에서_다시_표시한다() async throws {
        let goal = try makeDevelopmentGoal()
        let record = try makeConfirmedDevelopmentRecord(id: "record")
        let feature = GoalDetailFeature()
        var state = GoalDetailFeature.State(goalId: goal.id)
        state.shownOnDesktop = false
        state.recordDetail = RecordDetailDestination(record: record)

        // 빠지는 자리의 닫힘과 새 자리의 나타남이 정리 동작보다 먼저 들어오는 차례
        _ = feature.reduce(into: &state, action: .recordDetail(.dismiss))
        _ = feature.reduce(into: &state, action: .view(.appear(onDesktop: true)))

        #expect(state.recordDetail == RecordDetailDestination(record: record))
        #expect(state.shownOnDesktop == true)
    }

    @Test("같은 자리에서 닫은 기록 상세는 다시 표시하지 않는다")
    func 같은_자리에서_닫은_기록_상세는_다시_표시하지_않는다() async throws {
        let goal = try makeDevelopmentGoal()
        let record = try makeConfirmedDevelopmentRecord(id: "record")
        let feature = GoalDetailFeature()
        var state = GoalDetailFeature.State(goalId: goal.id)
        state.shownOnDesktop = false
        state.recordDetail = RecordDetailDestination(record: record)

        // 좁은 창에서 뒤로 가면 개발 목표가 같은 자리에 다시 나타남
        _ = feature.reduce(into: &state, action: .recordDetail(.dismiss))
        _ = feature.reduce(into: &state, action: .view(.appear(onDesktop: false)))
        #expect(state.recordDetail == nil)

        // 정리 동작이 지난 뒤 창 폭이 바뀌어도 닫은 기록 상세는 다시 표시하지 않음
        _ = feature.reduce(into: &state, action: .store(.recordDetailDismissed))
        _ = feature.reduce(into: &state, action: .view(.appear(onDesktop: true)))
        #expect(state.recordDetail == nil)
    }
}
