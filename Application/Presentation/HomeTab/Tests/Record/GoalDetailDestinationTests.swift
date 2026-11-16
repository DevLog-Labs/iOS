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
        }
        await store.send(.view(.selectRecord(item))) {
            $0.recordDetail = RecordDetailDestination(record: record)
        }
    }
}
