//
//  DevelopmentRecordConcurrencyUseCaseTests.swift
//  DomainTests
//
//  Created by opfic on 9/13/26.
//

import Testing
@testable import Domain

struct DevelopmentRecordConcurrencyUseCaseTests {
    @Test("기대한 기준 버전이 바뀐 Draft 저장을 거부한다")
    func 기대한_기준_버전이_바뀐_Draft_저장을_거부한다() async throws {
        let goal = try makeDevelopmentRecordGoal()
        let repository = DevelopmentRecordRepositorySpy(record: try makeDevelopmentRecordConfirmed())
        let useCase = SaveDevelopmentRecordDraftUseCaseImpl(
            repository,
            DevelopmentRecordGoalRepositorySpy(goal: goal)
        )

        await expectDevelopmentRecordDomainError(.developmentRecordDraftConflict) {
            try await useCase.execute(
                goalId: "goal-1",
                recordId: "record-1",
                baseVersionId: nil,
                draftRevisionId: nil,
                content: .init(title: "오래된 초안", markdownContent: "본문")
            )
        }
        #expect(await repository.draftRequests().isEmpty)
    }

    @Test("기대한 Draft 개정이 바뀌면 저장과 확정을 거부한다")
    func 기대한_Draft_개정이_바뀌면_저장과_확정을_거부한다() async throws {
        let goal = try makeDevelopmentRecordGoal()
        let record = try makeDevelopmentRecordInitialDraft(revisionId: "revision-2")
        let repository = DevelopmentRecordRepositorySpy(record: record)
        let saveUseCase = SaveDevelopmentRecordDraftUseCaseImpl(
            repository,
            DevelopmentRecordGoalRepositorySpy(goal: goal)
        )
        let confirmUseCase = ConfirmDevelopmentRecordUseCaseImpl(
            repository,
            DevelopmentRecordGoalRepositorySpy(goal: goal)
        )

        await expectDevelopmentRecordDomainError(.developmentRecordDraftConflict) {
            try await saveUseCase.execute(
                goalId: "goal-1",
                recordId: "record-1",
                baseVersionId: nil,
                draftRevisionId: "revision-1",
                content: .init(title: "오래된 초안", markdownContent: "본문")
            )
        }
        await expectDevelopmentRecordDomainError(.developmentRecordDraftConflict) {
            try await confirmUseCase.execute(
                goalId: "goal-1",
                recordId: "record-1",
                versionId: "version-1",
                baseVersionId: nil,
                draftRevisionId: "revision-1"
            )
        }
        #expect(await repository.draftRequests().isEmpty)
        #expect(await repository.confirmRequests().isEmpty)
    }

    @Test("최초 확정 중 현재 버전이 바뀌면 정정 확정으로 전환하지 않는다")
    func 최초_확정_중_현재_버전이_바뀌면_정정_확정으로_전환하지_않는다() async throws {
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
        let repository = DevelopmentRecordRepositorySpy(record: record)
        let useCase = ConfirmDevelopmentRecordUseCaseImpl(
            repository,
            DevelopmentRecordGoalRepositorySpy(goal: goal)
        )

        await expectDevelopmentRecordDomainError(.developmentRecordDraftConflict) {
            try await useCase.execute(
                goalId: "goal-1",
                recordId: "record-1",
                versionId: "version-2",
                baseVersionId: nil,
                draftRevisionId: "revision-1"
            )
        }
        #expect(await repository.confirmRequests().isEmpty)
    }
}
