//
//  DevelopmentRecordUseCaseTests.swift
//  DomainTests
//
//  Created by opfic on 8/27/26.
//

import Foundation
import Testing
@testable import Domain

struct DevelopmentRecordUseCaseTests {
    @Test("진행 중 목표에서 최초 Draft와 함께 기록을 생성한다")
    func 진행_중_목표에서_최초_Draft와_함께_기록을_생성한다() async throws {
        let goal = try makeDevelopmentRecordGoal()
        let createdAt = Date(timeIntervalSinceReferenceDate: 10)
        let record = try makeDevelopmentRecordInitialDraft(updatedAt: createdAt)
        let repository = DevelopmentRecordRepositorySpy(createResult: record)
        let useCase = CreateDevelopmentRecordUseCaseImpl(
            repository,
            DevelopmentRecordGoalRepositorySpy(goal: goal),
            revisionIdProvider: { "revision-1" },
            now: { createdAt }
        )
        let result = try await useCase.execute(
            goalId: "goal-1",
            recordId: "record-1",
            title: "기록",
            markdownContent: "본문"
        )

        #expect(result == record)
        #expect(await repository.createRequests() == [
            .init(
                id: "record-1",
                goalId: "goal-1",
                draft: try DevelopmentRecord.Draft(
                    title: "기록",
                    markdownContent: "본문",
                    baseVersionId: nil,
                    revisionId: "revision-1",
                    updatedAt: createdAt
                )
            )
        ])
    }

    @Test("완료 또는 보관 목표에서 기록 생성을 거부한다")
    func 완료_또는_보관_목표에서_기록_생성을_거부한다() async throws {
        for status in [DevelopmentGoal.Status.completed, .archived] {
            let repository = DevelopmentRecordRepositorySpy()
            let useCase = CreateDevelopmentRecordUseCaseImpl(
                repository,
            DevelopmentRecordGoalRepositorySpy(goal: try makeDevelopmentRecordGoal(status: status))
            )
            await expectDevelopmentRecordDomainError(.developmentGoalIsNotInProgress) {
                try await useCase.execute(
                    goalId: "goal-1",
                    recordId: "record-1",
                    title: "기록",
                    markdownContent: "본문"
                )
            }
            #expect(await repository.createRequests().isEmpty)
        }
    }

    @Test("기록 목록 조회는 Repository 결과를 반환한다")
    func 기록_목록_조회는_Repository_결과를_반환한다() async throws {
        let record = try makeDevelopmentRecordInitialDraft()
        let repository = DevelopmentRecordRepositorySpy(records: [record])
        let useCase = FetchDevelopmentRecordsUseCaseImpl(repository)
        let result = try await useCase.execute(goalId: "goal-1")
        #expect(result == [record])
        #expect(await repository.recordQueries() == ["goal-1"])
    }

    @Test("기록 이력 조회는 Repository 결과를 반환한다")
    func 기록_이력_조회는_Repository_결과를_반환한다() async throws {
        let initialVersion = try makeDevelopmentRecordInitialVersion()
        let repository = DevelopmentRecordRepositorySpy(versions: [initialVersion])
        let useCase = FetchDevelopmentRecordHistoryUseCaseImpl(repository)
        let result = try await useCase.execute(goalId: "goal-1", recordId: "record-1")
        #expect(result == [initialVersion])
        #expect(await repository.versionQueries() == [
            .init(goalId: "goal-1", recordId: "record-1")
        ])
    }

    @Test("기록 버전 조회는 지정한 버전만 반환한다")
    func 기록_버전_조회는_지정한_버전만_반환한다() async throws {
        let version = try makeDevelopmentRecordInitialVersion()
        let repository = DevelopmentRecordRepositorySpy(versions: [version])
        let useCase = FetchDevelopmentRecordVersionUseCaseImpl(repository)

        let result = try await useCase.execute(
            goalId: "goal-1",
            recordId: "record-1",
            versionId: version.id
        )

        #expect(result == version)
        #expect(await repository.exactVersionQueries() == [
            .init(goalId: "goal-1", recordId: "record-1", versionId: version.id)
        ])
    }

    @Test("최초 Draft 저장은 기준 버전 없이 갱신한다")
    func 최초_Draft_저장은_기준_버전_없이_갱신한다() async throws {
        let goal = try makeDevelopmentRecordGoal()
        let record = try makeDevelopmentRecordInitialDraft()
        let savedRecord = try makeDevelopmentRecordInitialDraft()
        let updatedAt = Date(timeIntervalSinceReferenceDate: 20)
        let repository = DevelopmentRecordRepositorySpy(record: record, savedRecord: savedRecord)
        let useCase = SaveDevelopmentRecordDraftUseCaseImpl(
            repository,
            DevelopmentRecordGoalRepositorySpy(goal: goal),
            revisionIdProvider: { "revision-2" },
            now: { updatedAt }
        )
        let result = try await useCase.execute(
            goalId: "goal-1",
            recordId: "record-1",
            baseVersionId: nil,
            draftRevisionId: "revision-1",
            content: .init(title: "수정 기록", markdownContent: "수정 본문")
        )

        #expect(result == savedRecord)
        #expect(await repository.draftRequests() == [
            .init(
                goalId: "goal-1",
                recordId: "record-1",
                expectedRevisionId: "revision-1",
                draft: try DevelopmentRecord.Draft(
                    title: "수정 기록",
                    markdownContent: "수정 본문",
                    baseVersionId: nil,
                    revisionId: "revision-2",
                    updatedAt: updatedAt
                )
            )
        ])
    }

    @Test("확정 버전 기반 Draft 저장은 기준 버전을 유지한다")
    func 확정_버전_기반_Draft_저장은_기준_버전을_유지한다() async throws {
        let goal = try makeDevelopmentRecordGoal()
        let currentVersion = try DevelopmentRecord.CurrentVersion(id: "version-1", number: 1)
        let record = try makeDevelopmentRecord(
            currentVersion: currentVersion,
            draft: DevelopmentRecord.Draft(
                title: "정정 초안",
                markdownContent: "본문",
                baseVersionId: currentVersion.id,
                revisionId: "revision-1",
                updatedAt: .distantPast
            )
        )
        let savedRecord = try makeDevelopmentRecord(
            currentVersion: currentVersion,
            draft: DevelopmentRecord.Draft(
                title: "수정 정정 초안",
                markdownContent: "수정 본문",
                baseVersionId: currentVersion.id,
                updatedAt: .distantFuture
            )
        )
        let updatedAt = Date(timeIntervalSinceReferenceDate: 30)
        let repository = DevelopmentRecordRepositorySpy(record: record, savedRecord: savedRecord)
        let useCase = SaveDevelopmentRecordDraftUseCaseImpl(
            repository,
            DevelopmentRecordGoalRepositorySpy(goal: goal),
            revisionIdProvider: { "revision-2" },
            now: { updatedAt }
        )
        _ = try await useCase.execute(
            goalId: "goal-1",
            recordId: "record-1",
            baseVersionId: currentVersion.id,
            draftRevisionId: "revision-1",
            content: .init(title: "수정 정정 초안", markdownContent: "수정 본문")
        )

        let requests = await repository.draftRequests()
        #expect(requests.first?.draft.baseVersionId == currentVersion.id)
        #expect(requests.first?.draft.updatedAt == updatedAt)
    }

    @Test("확정 기록의 저장은 현재 버전 기준 정정 Draft를 시작한다")
    func 확정_기록의_저장은_현재_버전_기준_정정_Draft를_시작한다() async throws {
        let goal = try makeDevelopmentRecordGoal()
        let record = try makeDevelopmentRecordConfirmed()
        let currentVersion = try #require(record.currentVersion)
        let savedRecord = try makeDevelopmentRecord(
            currentVersion: currentVersion,
            draft: DevelopmentRecord.Draft(
                title: "정정 초안",
                markdownContent: "본문",
                baseVersionId: currentVersion.id,
                updatedAt: .distantFuture
            )
        )
        let updatedAt = Date(timeIntervalSinceReferenceDate: 40)
        let repository = DevelopmentRecordRepositorySpy(record: record, savedRecord: savedRecord)
        let useCase = SaveDevelopmentRecordDraftUseCaseImpl(
            repository,
            DevelopmentRecordGoalRepositorySpy(goal: goal),
            revisionIdProvider: { "revision-2" },
            now: { updatedAt }
        )
        let result = try await useCase.execute(
            goalId: "goal-1",
            recordId: "record-1",
            baseVersionId: currentVersion.id,
            draftRevisionId: nil,
            content: .init(title: "정정 초안", markdownContent: "본문")
        )

        #expect(result == savedRecord)
        #expect(await repository.draftRequests() == [
            .init(
                goalId: "goal-1",
                recordId: "record-1",
                expectedRevisionId: nil,
                draft: try DevelopmentRecord.Draft(
                    title: "정정 초안",
                    markdownContent: "본문",
                    baseVersionId: currentVersion.id,
                    revisionId: "revision-2",
                    updatedAt: updatedAt
                )
            )
        ])
    }

}
