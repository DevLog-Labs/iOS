//
//  SaveDevelopmentRecordDraftUseCaseImpl.swift
//  Domain
//
//  Created by opfic on 8/27/26.
//

import Foundation

public final class SaveDevelopmentRecordDraftUseCaseImpl: SaveDevelopmentRecordDraftUseCase {
    private let repository: DevelopmentRecordRepository
    private let goalRepository: DevelopmentGoalRepository
    private let revisionIdProvider: () -> String
    private let now: () -> Date

    init(
        _ repository: DevelopmentRecordRepository,
        _ goalRepository: DevelopmentGoalRepository,
        revisionIdProvider: @escaping () -> String = { UUID().uuidString },
        now: @escaping () -> Date = Date.init
    ) {
        self.repository = repository
        self.goalRepository = goalRepository
        self.revisionIdProvider = revisionIdProvider
        self.now = now
    }

    public func execute(
        goalId: String,
        recordId: String,
        baseVersionId: String?,
        draftRevisionId: String?,
        content: DevelopmentRecord.Content
    ) async throws -> DevelopmentRecord {
        let goal = try await goalRepository.fetchGoal(goalId)
        guard goal.status == .inProgress else {
            throw DomainLayerError.developmentGoalIsNotInProgress
        }

        let record = try await repository.fetchRecord(goalId: goalId, recordId: recordId)
        guard record.id == recordId, record.goalId == goalId else {
            throw DomainLayerError.invalidData(context: "developmentRecord")
        }
        guard record.currentVersion?.id == baseVersionId else {
            throw DomainLayerError.developmentRecordDraftConflict
        }
        guard record.draft?.revisionId == draftRevisionId else {
            throw DomainLayerError.developmentRecordDraftConflict
        }
        let updatedDraft = try DevelopmentRecord.Draft(
            title: content.title,
            markdownContent: content.markdownContent,
            baseVersionId: baseVersionId,
            revisionId: revisionIdProvider(),
            updatedAt: now()
        )
        return try await repository.saveDraft(
            goalId: goalId,
            recordId: recordId,
            expectedRevisionId: draftRevisionId,
            draft: updatedDraft
        )
    }
}
