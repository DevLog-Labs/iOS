//
//  GoalDetailFeatureTests.swift
//  DevelopmentTests
//
//  Created by opfic on 9/13/26.
//

import Testing
import Domain
import Foundation
import PresentationShared
@testable import HomeTab

@MainActor
struct GoalDetailFeatureTests {
    @Test("타임라인은 최신 기록부터 정렬하고 최신 확정 버전을 구성한다")
    func 타임라인은_최신_기록부터_정렬하고_최신_확정_버전을_구성한다() async throws {
        let goal = try makeDevelopmentGoal(title: "개발 목표와 기록 이력 구성")
        let confirmedRecord = try makeConfirmedDevelopmentRecord(id: "confirmed")
        let draftRecord = try makeDevelopmentRecord(
            id: "draft",
            createdAt: Date(timeIntervalSince1970: 1_700_000_300)
        )
        let version = try makeDevelopmentRecordVersion(recordId: confirmedRecord.id)
        let items = [
            RecordTimelineItem(record: draftRecord, currentVersion: nil),
            RecordTimelineItem(record: confirmedRecord, currentVersion: version)
        ]
        let store = TestStore(
            initialState: GoalDetailFeature.State(goalId: goal.id)
        ) {
            GoalDetailFeature()
        } withDependencies: {
            $0.developmentFetchGoalUseCase = FetchDevelopmentGoalUseCaseStub(result: .success(goal))
            $0.developmentFetchRecordsUseCase = FetchDevelopmentRecordsUseCaseStub(
                result: .success([draftRecord, confirmedRecord])
            )
            $0.developmentFetchRecordVersionUseCase = FetchDevelopmentRecordVersionUseCaseStub(
                resultByRecordId: [confirmedRecord.id: .success(version)]
            )
            $0.developmentFetchTodosUseCase = FetchTodosUseCaseStub()
        }

        await store.send(.view(.fetch)) {
            $0.isLoading = true
            $0.isTodoLoading = true
        }
        await store.receive(.store(.loaded(goal: goal, items: items))) {
            $0.goal = goal
            $0.items = items
            $0.isLoading = false
            $0.hasLoaded = true
        }
        await store.receive(.store(.loadedTodos([]))) {
            $0.isTodoLoading = false
            $0.hasLoadedTodos = true
        }
    }

    @Test("타임라인 새로고침은 변경된 현재 버전을 반영한다")
    func 타임라인_새로고침은_변경된_현재_버전을_반영한다() async throws {
        let goal = try makeDevelopmentGoal()
        let previousVersion = try makeDevelopmentRecordVersion(id: "version-1")
        let currentVersion = try makeDevelopmentRecordVersion(
            id: "version-2",
            number: 2,
            title: "변경된 기록",
            kind: .correction,
            sourceVersionId: previousVersion.id
        )
        let previousRecord = try makeConfirmedDevelopmentRecord(versionId: previousVersion.id)
        let currentRecord = try makeConfirmedDevelopmentRecord(
            versionId: currentVersion.id,
            versionNumber: currentVersion.number
        )
        let previousItem = RecordTimelineItem(
            record: previousRecord,
            currentVersion: previousVersion
        )
        let currentItem = RecordTimelineItem(
            record: currentRecord,
            currentVersion: currentVersion
        )
        var state = GoalDetailFeature.State(goalId: goal.id)
        state.goal = goal
        state.items = [previousItem]
        state.hasLoaded = true
        let store = TestStore(initialState: state) {
            GoalDetailFeature()
        } withDependencies: {
            $0.developmentFetchGoalUseCase = FetchDevelopmentGoalUseCaseStub(result: .success(goal))
            $0.developmentFetchRecordsUseCase = FetchDevelopmentRecordsUseCaseStub(
                result: .success([currentRecord])
            )
            $0.developmentFetchRecordVersionUseCase = FetchDevelopmentRecordVersionUseCaseStub(
                resultByRecordId: [currentRecord.id: .success(currentVersion)]
            )
            $0.developmentFetchTodosUseCase = FetchTodosUseCaseStub()
        }

        await store.send(.view(.refresh)) {
            $0.isLoading = true
            $0.isTodoLoading = true
        }
        await store.receive(.store(.loaded(goal: goal, items: [currentItem]))) {
            $0.items = [currentItem]
            $0.isLoading = false
        }
        await store.receive(.store(.loadedTodos([]))) {
            $0.isTodoLoading = false
            $0.hasLoadedTodos = true
        }
    }

    @Test("타임라인 조회 실패는 입력 가능한 재조회 상태를 유지한다")
    func 타임라인_조회_실패는_입력_가능한_재조회_상태를_유지한다() async throws {
        let goal = try makeDevelopmentGoal()
        let store = TestStore(
            initialState: GoalDetailFeature.State(goalId: goal.id)
        ) {
            GoalDetailFeature()
        } withDependencies: {
            $0.developmentFetchGoalUseCase = FetchDevelopmentGoalUseCaseStub(result: .success(goal))
            $0.developmentFetchRecordsUseCase = FetchDevelopmentRecordsUseCaseStub(
                result: .failure(RecordTestError.failed)
            )
            $0.developmentFetchRecordVersionUseCase = FetchDevelopmentRecordVersionUseCaseStub(
                resultByRecordId: [:]
            )
            $0.developmentFetchTodosUseCase = FetchTodosUseCaseStub()
        }

        await store.send(.view(.fetch)) {
            $0.isLoading = true
            $0.isTodoLoading = true
        }
        await store.receive(.store(.failed)) {
            $0.isLoading = false
            $0.hasLoadFailure = true
            $0.alert = makeRecordErrorAlert("development_record_timeline_error_message")
        }
        await store.receive(.store(.loadedTodos([]))) {
            $0.isTodoLoading = false
            $0.hasLoadedTodos = true
        }
        await store.send(.view(.refresh)) {
            $0.isLoading = true
            $0.isTodoLoading = true
            $0.hasLoadFailure = false
        }
        await store.receive(.store(.failed)) {
            $0.isLoading = false
            $0.hasLoadFailure = true
        }
        await store.receive(.store(.loadedTodos([]))) {
            $0.isTodoLoading = false
        }
    }

    @Test("상태 전환 성공은 후속 재조회 없이 요청 상태를 반영한다")
    func 상태_전환_성공은_후속_재조회_없이_요청_상태를_반영한다() async throws {
        let goal = try makeDevelopmentGoal()
        let spy = UpdateDevelopmentGoalStatusUseCaseSpy()
        var state = GoalDetailFeature.State(goalId: goal.id)
        state.goal = goal
        state.hasLoaded = true
        let store = TestStore(initialState: state) {
            GoalDetailFeature()
        } withDependencies: {
            $0.developmentUpdateGoalStatusUseCase = spy
            $0.developmentFetchGoalUseCase = FetchDevelopmentGoalUseCaseStub(
                result: .failure(RecordTestError.failed)
            )
        }

        await store.send(.view(.selectStatus(.archived))) {
            $0.alert = GoalDetailFeature.transitionConfirmationAlert(.archived)
        }
        await store.send(.alert(.presented(.confirmTransition(.archived)))) {
            $0.alert = nil
            $0.isTransitioning = true
        }
        await store.receive(.store(.transitioned(.archived))) {
            $0.updatedGoalStatus = .archived
            $0.isTransitioning = false
        }

        #expect(await spy.requests() == [
            .init(goalId: goal.id, status: .archived)
        ])
    }

    @Test("반영한 상태는 다음 상태 전환의 기준으로 사용한다")
    func 반영한_상태는_다음_상태_전환의_기준으로_사용한다() async throws {
        let goal = try makeDevelopmentGoal()
        var state = GoalDetailFeature.State(goalId: goal.id)
        state.goal = goal
        state.updatedGoalStatus = .archived
        state.hasLoaded = true
        let store = TestStore(initialState: state) {
            GoalDetailFeature()
        }

        await store.send(.view(.selectStatus(.inProgress))) {
            $0.alert = GoalDetailFeature.transitionConfirmationAlert(.inProgress)
        }
    }

    @Test("완료되거나 보관된 목표는 진행 중으로 되돌릴 수 있다")
    func 완료되거나_보관된_목표는_진행_중으로_되돌릴_수_있다() async throws {
        for status in [DevelopmentGoal.Status.completed, .archived] {
            let goal = try makeDevelopmentGoal(status: status)
            let spy = UpdateDevelopmentGoalStatusUseCaseSpy()
            var state = GoalDetailFeature.State(goalId: goal.id)
            state.goal = goal
            state.hasLoaded = true
            let store = TestStore(initialState: state) {
                GoalDetailFeature()
            } withDependencies: {
                $0.developmentUpdateGoalStatusUseCase = spy
            }

            await store.send(.view(.selectStatus(.inProgress))) {
                $0.alert = GoalDetailFeature.transitionConfirmationAlert(.inProgress)
            }
            await store.send(.alert(.presented(.confirmTransition(.inProgress)))) {
                $0.alert = nil
                $0.isTransitioning = true
            }
            await store.receive(.store(.transitioned(.inProgress))) {
                $0.updatedGoalStatus = .inProgress
                $0.isTransitioning = false
            }

            #expect(await spy.requests() == [
                .init(goalId: goal.id, status: .inProgress)
            ])
        }
    }

    @Test("개발 기록이 없으면 목표 완료 전에 기록 작성을 안내한다")
    func 개발_기록이_없으면_목표_완료_전에_기록_작성을_안내한다() async throws {
        let goal = try makeDevelopmentGoal()
        let spy = UpdateDevelopmentGoalStatusUseCaseSpy()
        var state = GoalDetailFeature.State(goalId: goal.id)
        state.goal = goal
        state.hasLoaded = true
        let store = TestStore(initialState: state) {
            GoalDetailFeature()
        } withDependencies: {
            $0.developmentUpdateGoalStatusUseCase = spy
        }

        await store.send(.view(.selectStatus(.completed))) {
            $0.alert = GoalDetailFeature.completionBlockingAlert(items: [])
        }

        #expect(await spy.requests().isEmpty)
    }

    @Test("최신 기록이 초안이면 목표 완료 전에 기록 확정을 안내한다")
    func 최신_기록이_초안이면_목표_완료_전에_기록_확정을_안내한다() async throws {
        let goal = try makeDevelopmentGoal()
        let draft = try makeDevelopmentRecord(
            id: "draft",
            createdAt: Date(timeIntervalSince1970: 1_700_000_300)
        )
        let confirmed = try makeConfirmedDevelopmentRecord(id: "confirmed")
        let version = try makeDevelopmentRecordVersion(recordId: confirmed.id)
        let items = [
            RecordTimelineItem(record: draft, currentVersion: nil),
            RecordTimelineItem(record: confirmed, currentVersion: version)
        ]
        let spy = UpdateDevelopmentGoalStatusUseCaseSpy()
        var state = GoalDetailFeature.State(goalId: goal.id)
        state.goal = goal
        state.items = items
        state.hasLoaded = true
        let store = TestStore(initialState: state) {
            GoalDetailFeature()
        } withDependencies: {
            $0.developmentUpdateGoalStatusUseCase = spy
        }

        await store.send(.view(.selectStatus(.completed))) {
            $0.alert = GoalDetailFeature.completionBlockingAlert(items: items)
        }

        #expect(await spy.requests().isEmpty)
    }

    @Test("정정 초안이 남아 있으면 목표 완료 전에 초안 확정을 안내한다")
    func 정정_초안이_남아_있으면_목표_완료_전에_초안_확정을_안내한다() async throws {
        let goal = try makeDevelopmentGoal()
        let version = try makeDevelopmentRecordVersion()
        let record = try makeConfirmedDevelopmentRecord(
            draft: makeDevelopmentRecordDraft(baseVersionId: version.id)
        )
        let item = RecordTimelineItem(record: record, currentVersion: version)
        let spy = UpdateDevelopmentGoalStatusUseCaseSpy()
        var state = GoalDetailFeature.State(goalId: goal.id)
        state.goal = goal
        state.items = [item]
        state.hasLoaded = true
        let store = TestStore(initialState: state) {
            GoalDetailFeature()
        } withDependencies: {
            $0.developmentUpdateGoalStatusUseCase = spy
        }

        await store.send(.view(.selectStatus(.completed))) {
            $0.alert = GoalDetailFeature.completionBlockingAlert(items: [item])
        }

        #expect(await spy.requests().isEmpty)
    }

    @Test("모든 기록이 확정되면 확인 후 목표를 완료한다")
    func 모든_기록이_확정되면_확인_후_목표를_완료한다() async throws {
        let goal = try makeDevelopmentGoal()
        let record = try makeConfirmedDevelopmentRecord()
        let version = try makeDevelopmentRecordVersion()
        let item = RecordTimelineItem(record: record, currentVersion: version)
        let spy = UpdateDevelopmentGoalStatusUseCaseSpy()
        var state = GoalDetailFeature.State(goalId: goal.id)
        state.goal = goal
        state.items = [item]
        state.hasLoaded = true
        let store = TestStore(initialState: state) {
            GoalDetailFeature()
        } withDependencies: {
            $0.developmentUpdateGoalStatusUseCase = spy
        }

        await store.send(.view(.selectStatus(.completed))) {
            $0.alert = GoalDetailFeature.transitionConfirmationAlert(.completed)
        }
        await store.send(.alert(.presented(.confirmTransition(.completed)))) {
            $0.alert = nil
            $0.isTransitioning = true
        }
        await store.receive(.store(.transitioned(.completed))) {
            $0.updatedGoalStatus = .completed
            $0.isTransitioning = false
        }

        #expect(await spy.requests() == [
            .init(goalId: goal.id, status: .completed)
        ])
    }

    @Test("목표 상태 전환 실패는 현재 상태를 유지하고 오류를 표시한다")
    func 목표_상태_전환_실패는_현재_상태를_유지하고_오류를_표시한다() async throws {
        let goal = try makeDevelopmentGoal()
        let spy = UpdateDevelopmentGoalStatusUseCaseSpy(result: .failure(RecordTestError.failed))
        var state = GoalDetailFeature.State(goalId: goal.id)
        state.goal = goal
        state.hasLoaded = true
        let store = TestStore(initialState: state) {
            GoalDetailFeature()
        } withDependencies: {
            $0.developmentUpdateGoalStatusUseCase = spy
        }

        await store.send(.view(.selectStatus(.archived))) {
            $0.alert = GoalDetailFeature.transitionConfirmationAlert(.archived)
        }
        await store.send(.alert(.presented(.confirmTransition(.archived)))) {
            $0.alert = nil
            $0.isTransitioning = true
        }
        await store.receive(.store(.transitionFailed)) {
            $0.isTransitioning = false
            $0.alert = GoalDetailFeature.transitionErrorAlert
        }

        #expect(store.state.goal == goal)
        #expect(await spy.requests() == [
            .init(goalId: goal.id, status: .archived)
        ])
    }

    @Test("목표 수정은 불러온 목표로 수정 화면을 연다")
    func 목표_수정은_불러온_목표로_수정_화면을_연다() async throws {
        let goal = try makeDevelopmentGoal()
        var state = GoalDetailFeature.State(goalId: goal.id)
        state.goal = goal
        state.hasLoaded = true
        let store = TestStore(initialState: state) {
            GoalDetailFeature()
        }

        await store.send(.view(.editGoal)) {
            $0.goalEdit = GoalCreateFeature.State(goal: goal)
        }
    }

    @Test("기록 작성이 열려 있으면 목표 수정을 열지 않는다")
    func 기록_작성이_열려_있으면_목표_수정을_열지_않는다() async throws {
        let goal = try makeDevelopmentGoal()
        var state = GoalDetailFeature.State(goalId: goal.id)
        state.goal = goal
        state.hasLoaded = true
        state.recordEditor = RecordEditorFeature.State(
            goalId: goal.id,
            goalTitle: goal.title,
            recordId: "record",
            versionId: "version"
        )
        let store = TestStore(initialState: state) {
            GoalDetailFeature()
        }

        await store.send(.view(.editGoal))
    }

    @Test("목표 수정 저장은 상세 목표를 바꾸고 수정을 알린다")
    func 목표_수정_저장은_상세_목표를_바꾸고_수정을_알린다() async throws {
        let goal = try makeDevelopmentGoal(status: .archived)
        let updated = try makeDevelopmentGoal(title: "바꾼 제목", status: .archived)
        var state = GoalDetailFeature.State(goalId: goal.id)
        state.goal = goal
        state.updatedGoalStatus = .archived
        state.hasLoaded = true
        state.goalEdit = GoalCreateFeature.State(goal: goal)
        let store = TestStore(initialState: state) {
            GoalDetailFeature()
        }

        await store.send(.goalEdit(.presented(.delegate(.saved(updated))))) {
            $0.goal = updated
            $0.updatedGoalStatus = nil
            $0.goalEdit = nil
        }
        await store.receive(.delegate(.goalUpdated))
    }
}
