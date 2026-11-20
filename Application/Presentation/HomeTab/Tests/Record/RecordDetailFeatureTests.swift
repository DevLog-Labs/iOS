//
//  RecordDetailFeatureTests.swift
//  DevelopmentTests
//
//  Created by opfic on 9/13/26.
//

import Foundation
import Testing
import PresentationShared
@testable import HomeTab

@MainActor
struct RecordDetailFeatureTests {
    @Test("편집과 이력 화면 표시는 Feature 상태를 전환한다")
    func 편집과_이력_화면_표시는_Feature_상태를_전환한다() async throws {
        let previousVersion = try makeDevelopmentRecordVersion(id: "version-1")
        let currentVersion = try makeDevelopmentRecordVersion(
            id: "version-2",
            number: 2,
            kind: .correction,
            sourceVersionId: previousVersion.id
        )
        let record = try makeConfirmedDevelopmentRecord(
            versionId: currentVersion.id,
            versionNumber: currentVersion.number
        )
        var state = RecordDetailFeature.State(goalTitle: "개발 목표", record: record)
        state.versions = [previousVersion, currentVersion]
        state.contentState = .loaded
        let store = TestStore(initialState: state) {
            RecordDetailFeature()
        } withDependencies: {
            $0.uuid = .incrementing
        }
        let editor = RecordEditorFeature.State(
            goalId: record.goalId,
            goalTitle: "개발 목표",
            record: record,
            baseVersion: currentVersion,
            versionId: UUID(0).uuidString
        )
        let history = RecordHistoryDestination(recordID: record.id)
        let versionDetail = RecordVersionDetailDestination(version: previousVersion)

        let destination = RecordEditorDestination(versionID: editor.versionId)

        await store.send(.view(.tapCorrection)) {
            $0.editorContent = editor
            $0.editor = destination
        }
        await store.send(.editor(.dismiss)) {
            $0.editor = nil
            $0.dismissedEditor = destination
        }
        await store.receive(.store(.screensDismissed)) {
            $0.dismissedEditor = nil
            $0.editorContent = nil
        }
        await store.send(.view(.tapHistory)) {
            $0.history = history
        }
        await store.send(.view(.selectVersion(previousVersion))) {
            $0.versionDetail = versionDetail
        }
        await store.send(.history(.dismiss)) {
            $0.history = nil
            $0.versionDetail = nil
            $0.dismissedHistory = history
            $0.dismissedVersionDetail = versionDetail
        }
        await store.receive(.store(.screensDismissed)) {
            $0.dismissedHistory = nil
            $0.dismissedVersionDetail = nil
        }
    }

    @Test("창 폭이 바뀌며 같은 차례에 닫힌 화면은 새 자리에서 다시 표시한다")
    func 창_폭이_바뀌며_같은_차례에_닫힌_화면은_새_자리에서_다시_표시한다() async throws {
        let previousVersion = try makeDevelopmentRecordVersion(id: "version-1")
        let currentVersion = try makeDevelopmentRecordVersion(
            id: "version-2",
            number: 2,
            kind: .correction,
            sourceVersionId: previousVersion.id
        )
        let record = try makeConfirmedDevelopmentRecord(
            versionId: currentVersion.id,
            versionNumber: currentVersion.number
        )
        let feature = RecordDetailFeature()
        var state = RecordDetailFeature.State(goalTitle: "개발 목표", record: record)
        state.versions = [previousVersion, currentVersion]
        state.contentState = .loaded
        state.shownOnDesktop = false
        // 개발 목표가 먼저 넓은 창 자리로 옮겨 간 상태
        state.goalShownOnDesktop = true
        let editor = RecordEditorFeature.State(
            goalId: record.goalId,
            goalTitle: "개발 목표",
            record: record,
            baseVersion: currentVersion
        )
        state.editorContent = editor
        state.editor = RecordEditorDestination(versionID: editor.versionId)
        state.history = RecordHistoryDestination(recordID: record.id)
        state.versionDetail = RecordVersionDetailDestination(version: previousVersion)
        let presented = state

        // 빠지는 자리의 닫힘과 새 자리의 나타남이 정리 동작보다 먼저 들어오는 차례
        _ = feature.reduce(into: &state, action: .versionDetail(.dismiss))
        _ = feature.reduce(into: &state, action: .history(.dismiss))
        _ = feature.reduce(into: &state, action: .editor(.dismiss))
        _ = feature.reduce(into: &state, action: .view(.appear(onDesktop: true)))

        #expect(state.editor == presented.editor)
        #expect(state.editorContent == presented.editorContent)
        #expect(state.history == presented.history)
        #expect(state.versionDetail == presented.versionDetail)
        #expect(state.contentState == .loaded)

        // 정리 동작이 지난 뒤 같은 자리에 다시 나타나면 닫은 화면을 다시 표시하지 않음
        _ = feature.reduce(into: &state, action: .history(.dismiss))
        _ = feature.reduce(into: &state, action: .store(.screensDismissed))
        _ = feature.reduce(into: &state, action: .view(.appear(onDesktop: true)))
        #expect(state.history == nil)

        // 빠지는 자리의 화면이 닫히는 중에 다시 나타나도 나타난 자리를 바꾸지 않음
        _ = feature.reduce(into: &state, action: .view(.appear(onDesktop: false)))
        _ = feature.reduce(into: &state, action: .view(.appearHistory(onDesktop: false)))
        #expect(state.shownOnDesktop == true)
        #expect(state.historyShownOnDesktop == nil)
    }

    @Test("창 폭이 바뀌며 정정 화면이 잠깐 닫혀도 진행 중인 저장을 마친다")
    func 창_폭이_바뀌며_정정_화면이_잠깐_닫혀도_진행_중인_저장을_마친다() async throws {
        let currentVersion = try makeDevelopmentRecordVersion(id: "version-1")
        let record = try makeConfirmedDevelopmentRecord(
            versionId: currentVersion.id,
            versionNumber: currentVersion.number
        )
        let savedRecord = try makeDevelopmentRecord(
            id: record.id,
            draft: makeDevelopmentRecordDraft(title: "정정한 제목")
        )
        let feature = RecordDetailFeature()
        var state = RecordDetailFeature.State(goalTitle: "개발 목표", record: record)
        state.versions = [currentVersion]
        state.contentState = .loaded
        state.shownOnDesktop = false
        // 개발 목표가 먼저 넓은 창 자리로 옮겨 간 상태
        state.goalShownOnDesktop = true
        // 저장 중인 정정 화면
        var editor = RecordEditorFeature.State(
            goalId: record.goalId,
            goalTitle: "개발 목표",
            record: record,
            baseVersion: currentVersion
        )
        editor.isLoading = true
        state.editorContent = editor
        state.editor = RecordEditorDestination(versionID: editor.versionId)
        let presented = state

        // 저장하는 동안 빠지는 자리의 닫힘과 새 자리의 나타남이 정리 동작보다 먼저 들어오는 차례
        _ = feature.reduce(into: &state, action: .editor(.dismiss))
        _ = feature.reduce(into: &state, action: .view(.appear(onDesktop: true)))

        // 정정 상태가 비지 않아 진행 중인 저장의 결과를 받음
        #expect(state.editor == presented.editor)
        #expect(state.editorContent == presented.editorContent)
        _ = feature.reduce(into: &state, action: .editorContent(.store(.saved(savedRecord))))
        #expect(state.editorContent?.isLoading == false)
        #expect(state.editorContent?.result == .saved(savedRecord))
    }

    @Test("상세는 currentVersion과 일치하는 확정 버전을 표시한다")
    func 상세는_currentVersion과_일치하는_확정_버전을_표시한다() async throws {
        let record = try makeConfirmedDevelopmentRecord()
        let version = try makeDevelopmentRecordVersion()
        let store = TestStore(
            initialState: RecordDetailFeature.State(
                goalTitle: "개발 목표",
                record: record
            )
        ) {
            RecordDetailFeature()
        } withDependencies: {
            $0.developmentFetchRecordsUseCase = FetchDevelopmentRecordsUseCaseStub(
                result: .success([record])
            )
            $0.developmentFetchRecordHistoryUseCase = FetchDevelopmentRecordHistoryUseCaseStub(
                resultByRecordId: [record.id: .success([version])]
            )
        }

        await store.send(.view(.fetch)) {
            $0.contentState = .loading
        }
        await store.receive(.store(.loaded(record, [version]))) {
            $0.versions = [version]
            $0.contentState = .loaded
        }
    }

    @Test("확정 전 상세는 이력 조회 없이 초안을 유지한다")
    func 확정_전_상세는_이력_조회_없이_초안을_유지한다() async throws {
        let record = try makeDevelopmentRecord()
        let store = TestStore(
            initialState: RecordDetailFeature.State(
                goalTitle: "개발 목표",
                record: record
            )
        ) {
            RecordDetailFeature()
        }

        let draft = try #require(record.draft)
        #expect(store.state.contentState == .draft(draft))
        await store.send(.view(.fetch))
    }

    @Test("확정 기록 조회 실패는 초안 대신 재시도 상태를 표시한다")
    func 확정_기록_조회_실패는_초안_대신_재시도_상태를_표시한다() async throws {
        let record = try makeConfirmedDevelopmentRecord()
        let store = TestStore(
            initialState: RecordDetailFeature.State(
                goalTitle: "개발 목표",
                record: record
            )
        ) {
            RecordDetailFeature()
        } withDependencies: {
            $0.developmentFetchRecordsUseCase = FetchDevelopmentRecordsUseCaseStub(
                result: .success([record])
            )
            $0.developmentFetchRecordHistoryUseCase = FetchDevelopmentRecordHistoryUseCaseStub(
                resultByRecordId: [record.id: .failure(RecordTestError.failed)]
            )
        }

        await store.send(.view(.fetch)) {
            $0.contentState = .loading
        }
        await store.receive(.store(.loadFailed)) {
            $0.contentState = .failed
            $0.alert = makeRecordErrorAlert("development_record_detail_error_message")
        }
        await store.send(.alert(.dismiss)) {
            $0.alert = nil
        }
        await store.send(.view(.fetch)) {
            $0.contentState = .loading
        }
        await store.receive(.store(.loadFailed)) {
            $0.contentState = .failed
            $0.alert = makeRecordErrorAlert("development_record_detail_error_message")
        }
    }

    @Test("이전 버전 되돌리기는 새 버전을 현재 버전으로 반영한다")
    func 이전_버전_되돌리기는_새_버전을_현재_버전으로_반영한다() async throws {
        let restoreVersionID = "00000000-0000-0000-0000-000000000003"
        let restoreUUID = try #require(UUID(uuidString: restoreVersionID))
        let initialVersion = try makeDevelopmentRecordVersion(id: "version-1")
        let currentVersion = try makeDevelopmentRecordVersion(
            id: "version-2",
            number: 2,
            kind: .correction,
            sourceVersionId: initialVersion.id
        )
        let restoredVersion = try makeDevelopmentRecordVersion(
            id: restoreVersionID,
            number: 3,
            kind: .rollback,
            sourceVersionId: initialVersion.id
        )
        let record = try makeConfirmedDevelopmentRecord(
            versionId: currentVersion.id,
            versionNumber: currentVersion.number
        )
        let spy = RestoreDevelopmentRecordUseCaseSpy(result: .success(restoredVersion))
        var state = RecordDetailFeature.State(goalTitle: "개발 목표", record: record)
        state.versions = [initialVersion, currentVersion]
        state.contentState = .loaded
        let store = TestStore(initialState: state) {
            RecordDetailFeature()
        } withDependencies: {
            $0.developmentRestoreRecordUseCase = spy
            $0.uuid = .constant(restoreUUID)
        }

        await store.send(.view(.restore(initialVersion))) {
            $0.alert = RecordDetailFeature.restoreConfirmationAlert(initialVersion)
        }
        await store.send(.alert(.presented(.confirmRestore(initialVersion)))) {
            $0.alert = nil
            $0.isRestoring = true
            $0.restoreRequest = .init(
                versionID: restoreVersionID,
                sourceVersionID: initialVersion.id
            )
        }
        await store.receive(.store(.restored(restoredVersion))) {
            $0.versions = [initialVersion, currentVersion, restoredVersion]
            $0.currentVersionID = restoredVersion.id
            $0.isRestoring = false
            $0.restoreRequest = nil
            $0.restoredSourceVersionID = initialVersion.id
        }

        #expect(await spy.requests() == [
            .init(
                goalId: record.goalId,
                recordId: record.id,
                versionId: restoreVersionID,
                sourceVersionId: initialVersion.id
            )
        ])
    }

    @Test("되돌리기 실패 재시도는 같은 버전 ID를 사용한다")
    func 되돌리기_실패_재시도는_같은_버전_ID를_사용한다() async throws {
        let restoreVersionID = "00000000-0000-0000-0000-000000000003"
        let restoreUUID = try #require(UUID(uuidString: restoreVersionID))
        let initialVersion = try makeDevelopmentRecordVersion(id: "version-1")
        let currentVersion = try makeDevelopmentRecordVersion(
            id: "version-2",
            number: 2,
            kind: .correction,
            sourceVersionId: initialVersion.id
        )
        let record = try makeConfirmedDevelopmentRecord(
            versionId: currentVersion.id,
            versionNumber: currentVersion.number
        )
        let restoredVersion = try makeDevelopmentRecordVersion(
            id: restoreVersionID,
            number: 3,
            kind: .rollback,
            sourceVersionId: initialVersion.id
        )
        let spy = RestoreDevelopmentRecordUseCaseSpy(
            results: [
                .failure(RecordTestError.failed),
                .success(restoredVersion)
            ]
        )
        var state = RecordDetailFeature.State(goalTitle: "개발 목표", record: record)
        state.versions = [initialVersion, currentVersion]
        state.contentState = .loaded
        let store = TestStore(initialState: state) {
            RecordDetailFeature()
        } withDependencies: {
            $0.developmentRestoreRecordUseCase = spy
            $0.uuid = .constant(restoreUUID)
        }

        await store.send(.view(.restore(initialVersion))) {
            $0.alert = RecordDetailFeature.restoreConfirmationAlert(initialVersion)
        }
        await store.send(.alert(.presented(.confirmRestore(initialVersion)))) {
            $0.alert = nil
            $0.isRestoring = true
            $0.restoreRequest = .init(
                versionID: restoreVersionID,
                sourceVersionID: initialVersion.id
            )
        }
        await store.receive(.store(.restoreFailed)) {
            $0.isRestoring = false
            $0.alert = makeRecordErrorAlert("development_record_restore_error_message")
        }
        await store.send(.alert(.dismiss)) {
            $0.alert = nil
        }
        await store.send(.view(.restore(initialVersion))) {
            $0.alert = RecordDetailFeature.restoreConfirmationAlert(initialVersion)
        }
        await store.send(.alert(.presented(.confirmRestore(initialVersion)))) {
            $0.alert = nil
            $0.isRestoring = true
        }
        await store.receive(.store(.restored(restoredVersion))) {
            $0.versions = [initialVersion, currentVersion, restoredVersion]
            $0.currentVersionID = restoredVersion.id
            $0.isRestoring = false
            $0.restoreRequest = nil
            $0.restoredSourceVersionID = initialVersion.id
        }

        #expect(await spy.requests() == [
            .init(
                goalId: record.goalId,
                recordId: record.id,
                versionId: restoreVersionID,
                sourceVersionId: initialVersion.id
            ),
            .init(
                goalId: record.goalId,
                recordId: record.id,
                versionId: restoreVersionID,
                sourceVersionId: initialVersion.id
            )
        ])
    }

    @Test("정정 초안이 있으면 이전 버전 되돌리기를 시작하지 않는다")
    func 정정_초안이_있으면_이전_버전_되돌리기를_시작하지_않는다() async throws {
        let initialVersion = try makeDevelopmentRecordVersion(id: "version-1")
        let currentVersion = try makeDevelopmentRecordVersion(
            id: "version-2",
            number: 2,
            kind: .correction,
            sourceVersionId: initialVersion.id
        )
        let record = try makeConfirmedDevelopmentRecord(
            versionId: currentVersion.id,
            versionNumber: currentVersion.number,
            draft: makeDevelopmentRecordDraft(baseVersionId: currentVersion.id)
        )
        var state = RecordDetailFeature.State(goalTitle: "개발 목표", record: record)
        state.versions = [initialVersion, currentVersion]
        state.contentState = .loaded
        let store = TestStore(initialState: state) {
            RecordDetailFeature()
        }

        await store.send(.view(.restore(initialVersion)))
    }

    @Test("되돌리기 확인 취소는 복원을 시작하지 않는다")
    func 되돌리기_확인_취소는_복원을_시작하지_않는다() async throws {
        let initialVersion = try makeDevelopmentRecordVersion(id: "version-1")
        let currentVersion = try makeDevelopmentRecordVersion(
            id: "version-2",
            number: 2,
            kind: .correction,
            sourceVersionId: initialVersion.id
        )
        let record = try makeConfirmedDevelopmentRecord(
            versionId: currentVersion.id,
            versionNumber: currentVersion.number
        )
        let spy = RestoreDevelopmentRecordUseCaseSpy(result: .failure(RecordTestError.failed))
        var state = RecordDetailFeature.State(goalTitle: "개발 목표", record: record)
        state.versions = [initialVersion, currentVersion]
        state.contentState = .loaded
        let store = TestStore(initialState: state) {
            RecordDetailFeature()
        } withDependencies: {
            $0.developmentRestoreRecordUseCase = spy
        }

        await store.send(.view(.restore(initialVersion))) {
            $0.alert = RecordDetailFeature.restoreConfirmationAlert(initialVersion)
        }
        await store.send(.alert(.dismiss)) {
            $0.alert = nil
        }

        #expect(await spy.requests().isEmpty)
    }

    @Test("읽기 전용 목표는 이전 버전 되돌리기를 시작하지 않는다")
    func 읽기_전용_목표는_이전_버전_되돌리기를_시작하지_않는다() async throws {
        let initialVersion = try makeDevelopmentRecordVersion(id: "version-1")
        let currentVersion = try makeDevelopmentRecordVersion(
            id: "version-2",
            number: 2,
            kind: .correction,
            sourceVersionId: initialVersion.id
        )
        let record = try makeConfirmedDevelopmentRecord(
            versionId: currentVersion.id,
            versionNumber: currentVersion.number
        )
        let spy = RestoreDevelopmentRecordUseCaseSpy(result: .failure(RecordTestError.failed))
        var state = RecordDetailFeature.State(
            goalTitle: "개발 목표",
            record: record,
            allowsMutation: false
        )
        state.versions = [initialVersion, currentVersion]
        state.contentState = .loaded
        let store = TestStore(initialState: state) {
            RecordDetailFeature()
        } withDependencies: {
            $0.developmentRestoreRecordUseCase = spy
        }

        await store.send(.view(.restore(initialVersion)))

        #expect(await spy.requests().isEmpty)
    }
}
