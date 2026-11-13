//
//  ConfirmDevelopmentRecordUseCaseImpl.swift
//  Domain
//
//  Created by opfic on 8/27/26.
//

public final class ConfirmDevelopmentRecordUseCaseImpl: ConfirmDevelopmentRecordUseCase {
    private let repository: DevelopmentRecordRepository
    private let goalRepository: DevelopmentGoalRepository

    init(
        _ repository: DevelopmentRecordRepository,
        _ goalRepository: DevelopmentGoalRepository
    ) {
        self.repository = repository
        self.goalRepository = goalRepository
    }

    public func execute(
        goalId: String,
        recordId: String,
        versionId: String,
        baseVersionId: String?,
        draftRevisionId: String?
    ) async throws -> DevelopmentRecord.Version {
        let record = try await repository.fetchRecord(goalId: goalId, recordId: recordId)
        if record.currentVersion?.id == versionId {
            return try await confirmedVersion(
                record: record,
                goalId: goalId,
                recordId: recordId,
                versionId: versionId
            )
        }

        let goal = try await goalRepository.fetchGoal(goalId)
        guard goal.status == .inProgress else {
            throw DomainLayerError.developmentGoalIsNotInProgress
        }

        guard record.id == recordId, record.goalId == goalId else {
            throw DomainLayerError.invalidData(context: "developmentRecord")
        }
        guard let draft = record.draft else {
            throw DomainLayerError.developmentRecordDraftNotFound
        }
        guard record.currentVersion?.id == baseVersionId,
              draft.baseVersionId == baseVersionId,
              draft.revisionId == draftRevisionId else {
            throw DomainLayerError.developmentRecordDraftConflict
        }

        let kind = baseVersionId == nil
            ? DevelopmentRecord.Version.Kind.initial
            : .correction
        do {
            return try await repository.confirmDraft(
                goalId: goalId,
                recordId: recordId,
                confirmation: .init(
                    versionId: versionId,
                    kind: kind,
                    sourceVersionId: baseVersionId,
                    draftRevisionId: draftRevisionId
                )
            )
        } catch {
            guard let record = try? await repository.fetchRecord(
                goalId: goalId,
                recordId: recordId
            ), let version = try? await confirmedVersion(
                record: record,
                goalId: goalId,
                recordId: recordId,
                versionId: versionId
            ) else {
                throw error
            }
            return version
        }
    }
}

private extension ConfirmDevelopmentRecordUseCaseImpl {
    func confirmedVersion(
        record: DevelopmentRecord,
        goalId: String,
        recordId: String,
        versionId: String
    ) async throws -> DevelopmentRecord.Version {
        guard record.currentVersion?.id == versionId else {
            throw DomainLayerError.developmentRecordVersionNotFound
        }
        return try await repository.fetchVersion(
            goalId: goalId,
            recordId: recordId,
            versionId: versionId
        )
    }
}
