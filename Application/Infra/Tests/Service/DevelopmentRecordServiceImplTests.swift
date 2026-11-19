//
//  DevelopmentRecordServiceImplTests.swift
//  InfraTests
//
//  Created by opfic on 8/28/26.
//

import Foundation
import Testing
import FirebaseFirestore
import Data
@testable import Infra

struct DevelopmentRecordServiceImplTests {
    @Test("최초 확정은 첫 버전과 초안 내용을 만든다")
    func 최초_확정은_첫_버전과_초안_내용을_만든다() {
        let mutation = DevelopmentRecordServiceImpl.makeConfirmationMutation(
            recordData: makeRecordData(draftBaseVersionId: nil),
            request: .init(versionId: "version-1", kind: "initial", sourceVersionId: nil)
        )

        #expect(mutation?.number == 1)
        #expect(mutation?.kind == "initial")
        #expect(mutation?.sourceVersionId == nil)
    }

    @Test("정정은 현재 버전과 초안 기준 버전이 일치할 때만 새 버전을 만든다")
    func 정정은_현재_버전과_초안_기준_버전이_일치할_때만_새_버전을_만든다() {
        let mutation = DevelopmentRecordServiceImpl.makeConfirmationMutation(
            recordData: makeRecordData(
                currentVersionId: "version-1",
                currentVersionNumber: 1,
                draftBaseVersionId: "version-1"
            ),
            request: .init(
                versionId: "version-2",
                kind: "correction",
                sourceVersionId: "version-1"
            )
        )

        #expect(mutation?.number == 2)
        #expect(mutation?.sourceVersionId == "version-1")
    }

    @Test("되돌리기는 현재 버전보다 앞선 원본으로 새 rollback 버전을 만든다")
    func 되돌리기는_현재_버전보다_앞선_원본으로_새_rollback_버전을_만든다() {
        let mutation = DevelopmentRecordServiceImpl.makeRestoreMutation(
            recordId: "record-1",
            recordData: makeRecordData(
                currentVersionId: "version-2",
                currentVersionNumber: 2,
                draftBaseVersionId: nil,
                includesDraft: false
            ),
            sourceVersionId: "version-1",
            sourceData: makeVersionData(number: 1)
        )

        #expect(mutation?.number == 3)
        #expect(mutation?.kind == "rollback")
        #expect(mutation?.sourceVersionId == "version-1")
    }

    @Test("이미 현재인 버전은 되돌리기 원본으로 사용할 수 없다")
    func 이미_현재인_버전은_되돌리기_원본으로_사용할_수_없다() {
        let mutation = DevelopmentRecordServiceImpl.makeRestoreMutation(
            recordId: "record-1",
            recordData: makeRecordData(
                currentVersionId: "version-2",
                currentVersionNumber: 2,
                draftBaseVersionId: nil,
                includesDraft: false
            ),
            sourceVersionId: "version-2",
            sourceData: makeVersionData(number: 2)
        )

        #expect(mutation?.number == nil)
    }

    @Test("Draft 저장은 현재 버전과 기준 버전이 같을 때만 저장 데이터를 만든다")
    func Draft_저장은_현재_버전과_기준_버전이_같을_때만_저장_데이터를_만든다() {
        let data = DevelopmentRecordServiceImpl.makeDraftData(
            recordData: makeRecordData(
                currentVersionId: "version-1",
                currentVersionNumber: 1,
                draftBaseVersionId: "version-1"
            ),
            request: .init(
                title: "새 기록",
                markdownContent: "새 본문",
                baseVersionId: "version-1"
            )
        )

        #expect(data?[DevelopmentRecordDraftFieldKey.title.rawValue] as? String == "새 기록")
        #expect(data?[DevelopmentRecordDraftFieldKey.baseVersionId.rawValue] as? String == "version-1")

        let initialData = DevelopmentRecordServiceImpl.makeDraftData(
            recordData: makeRecordData(draftBaseVersionId: nil),
            request: .init(
                title: "첫 기록",
                markdownContent: "첫 본문",
                baseVersionId: nil
            )
        )

        #expect(initialData?[DevelopmentRecordDraftFieldKey.baseVersionId.rawValue] == nil)
    }

    @Test("초안이 없는 확정 기록의 정정 Draft 저장은 데이터를 만든다")
    func 초안이_없는_확정_기록의_정정_Draft_저장은_데이터를_만든다() {
        let recordData = makeRecordData(
            currentVersionId: "version-1",
            currentVersionNumber: 1,
            draftBaseVersionId: nil,
            includesDraft: false
        )
        let data = DevelopmentRecordServiceImpl.makeDraftData(
            recordData: recordData,
            request: .init(
                title: "정정 기록",
                markdownContent: "정정 본문",
                baseVersionId: "version-1",
                revisionId: "revision-1",
                expectedRevisionId: nil
            )
        )
        let staleData = DevelopmentRecordServiceImpl.makeDraftData(
            recordData: recordData,
            request: .init(
                title: "정정 기록",
                markdownContent: "정정 본문",
                baseVersionId: "version-1",
                revisionId: "revision-2",
                expectedRevisionId: "revision-1"
            )
        )

        #expect(data?[DevelopmentRecordDraftFieldKey.baseVersionId.rawValue] as? String == "version-1")
        #expect(data?[DevelopmentRecordDraftFieldKey.revisionId.rawValue] as? String == "revision-1")
        #expect(staleData == nil)
    }

    @Test("기준 버전이 바뀐 Draft 저장은 데이터를 만들지 않는다")
    func 기준_버전이_바뀐_Draft_저장은_데이터를_만들지_않는다() {
        let staleDraft = DevelopmentRecordServiceImpl.makeDraftData(
            recordData: makeRecordData(
                currentVersionId: "version-2",
                currentVersionNumber: 2,
                draftBaseVersionId: nil
            ),
            request: .init(
                title: "기록",
                markdownContent: "본문",
                baseVersionId: "version-1"
            )
        )
        let missingCurrentVersion = DevelopmentRecordServiceImpl.makeDraftData(
            recordData: makeRecordData(draftBaseVersionId: nil),
            request: .init(
                title: "기록",
                markdownContent: "본문",
                baseVersionId: "version-1"
            )
        )

        #expect(staleDraft == nil)
        #expect(missingCurrentVersion == nil)
    }

    @Test("기대한 Draft 개정이 바뀌면 저장과 확정을 거부한다")
    func 기대한_Draft_개정이_바뀌면_저장과_확정을_거부한다() {
        let recordData = makeRecordData(
            currentVersionId: nil,
            currentVersionNumber: nil,
            draftBaseVersionId: nil,
            draftRevisionId: "revision-2"
        )
        let draftData = DevelopmentRecordServiceImpl.makeDraftData(
            recordData: recordData,
            request: .init(
                title: "기록",
                markdownContent: "본문",
                baseVersionId: nil,
                revisionId: "revision-3",
                expectedRevisionId: "revision-1"
            )
        )
        let confirmation = DevelopmentRecordServiceImpl.makeConfirmationMutation(
            recordData: recordData,
            request: .init(
                versionId: "version-1",
                kind: "initial",
                sourceVersionId: nil,
                draftRevisionId: "revision-1"
            )
        )

        #expect(draftData == nil)
        #expect(confirmation == nil)
    }

    private func makeRecordData(
        currentVersionId: String? = nil,
        currentVersionNumber: Int? = nil,
        draftBaseVersionId: String?,
        draftRevisionId: String? = nil,
        includesDraft: Bool = true
    ) -> [String: Any] {
        var data: [String: Any] = [
            DevelopmentRecordFieldKey.createdAt.rawValue: Timestamp(date: Date(timeIntervalSince1970: 0))
        ]
        if let currentVersionId, let currentVersionNumber {
            data[DevelopmentRecordFieldKey.currentVersionId.rawValue] = currentVersionId
            data[DevelopmentRecordFieldKey.currentVersionNumber.rawValue] = currentVersionNumber
        }
        if includesDraft {
            var draft: [String: Any] = [
                DevelopmentRecordDraftFieldKey.title.rawValue: "기록",
                DevelopmentRecordDraftFieldKey.markdownContent.rawValue: "본문",
                DevelopmentRecordDraftFieldKey.updatedAt.rawValue: Timestamp(date: Date(timeIntervalSince1970: 0))
            ]
            if let draftBaseVersionId {
                draft[DevelopmentRecordDraftFieldKey.baseVersionId.rawValue] = draftBaseVersionId
            }
            if let draftRevisionId {
                draft[DevelopmentRecordDraftFieldKey.revisionId.rawValue] = draftRevisionId
            }
            data[DevelopmentRecordFieldKey.draft.rawValue] = draft
        }
        return data
    }

    private func makeVersionData(number: Int) -> [String: Any] {
        [
            DevelopmentRecordVersionFieldKey.versionNumber.rawValue: number,
            DevelopmentRecordVersionFieldKey.title.rawValue: "기록",
            DevelopmentRecordVersionFieldKey.markdownContent.rawValue: "본문",
            DevelopmentRecordVersionFieldKey.changeKind.rawValue: "initial",
            DevelopmentRecordVersionFieldKey.confirmedAt.rawValue: Timestamp(date: Date(timeIntervalSince1970: 0))
        ]
    }
}
