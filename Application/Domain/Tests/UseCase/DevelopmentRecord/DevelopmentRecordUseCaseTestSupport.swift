//
//  DevelopmentRecordUseCaseTestSupport.swift
//  DomainTests
//
//  Created by opfic on 8/27/26.
//

import Foundation
import Testing
@testable import Domain

actor DevelopmentRecordGoalRepositorySpy: DevelopmentGoalRepository {
    private let goal: DevelopmentGoal

    init(goal: DevelopmentGoal) {
        self.goal = goal
    }

    func createGoal(
        id: String,
        title: String,
        description: String
    ) async throws -> DevelopmentGoal {
        goal
    }

    func fetchGoal(_ goalId: String) async throws -> DevelopmentGoal {
        goal
    }

    func fetchGoals(_ query: DevelopmentGoal.Query) async throws -> [DevelopmentGoal] {
        [goal]
    }

    func fetchCompletionSnapshot(for goalId: String) async throws -> DevelopmentGoal.CompletionSnapshot {
        .init(goal: goal, records: [])
    }

    func transitionGoalStatus(
        _ goalId: String,
        to status: DevelopmentGoal.Status,
        completionSnapshot: DevelopmentGoal.CompletionSnapshot?
    ) async throws { }
}

actor DevelopmentRecordRepositorySpy: DevelopmentRecordRepository {
    struct CreateRequest: Equatable {
        let id: String
        let goalId: String
        let draft: DevelopmentRecord.Draft
    }

    struct RecordQuery: Equatable {
        let goalId: String
        let recordId: String
    }

    struct VersionQuery: Equatable {
        let goalId: String
        let recordId: String
        let versionId: String
    }

    struct DraftRequest: Equatable {
        let goalId: String
        let recordId: String
        let expectedRevisionId: String?
        let draft: DevelopmentRecord.Draft
    }

    struct ConfirmRequest: Equatable {
        let goalId: String
        let recordId: String
        let versionId: String
        let kind: DevelopmentRecord.Version.Kind
        let sourceVersionId: String?
        let draftRevisionId: String?
    }

    struct RestoreRequest: Equatable {
        let goalId: String
        let recordId: String
        let versionId: String
        let sourceVersionId: String
    }

    private let createResult: DevelopmentRecord?
    private let records: [DevelopmentRecord]
    private var recordsToReturn: [DevelopmentRecord]
    private let versions: [DevelopmentRecord.Version]
    private let savedRecord: DevelopmentRecord?
    private let confirmedVersion: DevelopmentRecord.Version?
    private let confirmError: Error?
    private let restoredVersion: DevelopmentRecord.Version?
    private let restoreError: Error?
    private var recordedCreateRequests = [CreateRequest]()
    private var recordedRecordQueries = [String]()
    private var recordedVersionQueries = [RecordQuery]()
    private var recordedExactVersionQueries = [VersionQuery]()
    private var recordedDraftRequests = [DraftRequest]()
    private var recordedConfirmRequests = [ConfirmRequest]()
    private var recordedRestoreRequests = [RestoreRequest]()

    init(
        createResult: DevelopmentRecord? = nil,
        records: [DevelopmentRecord] = [],
        record: DevelopmentRecord? = nil,
        subsequentRecords: [DevelopmentRecord] = [],
        versions: [DevelopmentRecord.Version] = [],
        savedRecord: DevelopmentRecord? = nil,
        confirmedVersion: DevelopmentRecord.Version? = nil,
        confirmError: Error? = nil,
        restoredVersion: DevelopmentRecord.Version? = nil,
        restoreError: Error? = nil
    ) {
        self.createResult = createResult
        self.records = records
        self.recordsToReturn = record.map { [$0] + subsequentRecords } ?? subsequentRecords
        self.versions = versions
        self.savedRecord = savedRecord
        self.confirmedVersion = confirmedVersion
        self.confirmError = confirmError
        self.restoredVersion = restoredVersion
        self.restoreError = restoreError
    }

    func createRecord(
        id: String,
        goalId: String,
        draft: DevelopmentRecord.Draft
    ) async throws -> DevelopmentRecord {
        recordedCreateRequests.append(.init(id: id, goalId: goalId, draft: draft))
        return try requiredDevelopmentRecordRepositoryResult(createResult)
    }

    func fetchRecords(goalId: String) async throws -> [DevelopmentRecord] {
        recordedRecordQueries.append(goalId)
        return records
    }

    func fetchRecord(goalId: String, recordId: String) async throws -> DevelopmentRecord {
        guard let record = recordsToReturn.first else {
            throw DevelopmentRecordRepositorySpyError.unconfigured
        }
        if 1 < recordsToReturn.count {
            recordsToReturn.removeFirst()
        }
        return record
    }

    func fetchVersions(goalId: String, recordId: String) async throws -> [DevelopmentRecord.Version] {
        recordedVersionQueries.append(.init(goalId: goalId, recordId: recordId))
        return versions
    }

    func fetchVersion(
        goalId: String,
        recordId: String,
        versionId: String
    ) async throws -> DevelopmentRecord.Version {
        recordedExactVersionQueries.append(.init(
            goalId: goalId,
            recordId: recordId,
            versionId: versionId
        ))
        guard let version = versions.first(where: { $0.id == versionId }) else {
            throw DevelopmentRecordRepositorySpyError.unconfigured
        }
        return version
    }

    func saveDraft(
        goalId: String,
        recordId: String,
        expectedRevisionId: String?,
        draft: DevelopmentRecord.Draft
    ) async throws -> DevelopmentRecord {
        recordedDraftRequests.append(.init(
            goalId: goalId,
            recordId: recordId,
            expectedRevisionId: expectedRevisionId,
            draft: draft
        ))
        return try requiredDevelopmentRecordRepositoryResult(savedRecord)
    }

    func confirmDraft(
        goalId: String,
        recordId: String,
        confirmation: DevelopmentRecord.Confirmation
    ) async throws -> DevelopmentRecord.Version {
        recordedConfirmRequests.append(
            .init(
                goalId: goalId,
                recordId: recordId,
                versionId: confirmation.versionId,
                kind: confirmation.kind,
                sourceVersionId: confirmation.sourceVersionId,
                draftRevisionId: confirmation.draftRevisionId
            )
        )
        if let confirmError {
            throw confirmError
        }
        return try requiredDevelopmentRecordRepositoryResult(confirmedVersion)
    }

    func restoreVersion(
        goalId: String,
        recordId: String,
        versionId: String,
        sourceVersionId: String
    ) async throws -> DevelopmentRecord.Version {
        recordedRestoreRequests.append(
            .init(
                goalId: goalId, recordId: recordId, versionId: versionId, sourceVersionId: sourceVersionId)
        )
        if let restoreError {
            throw restoreError
        }
        return try requiredDevelopmentRecordRepositoryResult(restoredVersion)
    }

    func createRequests() -> [CreateRequest] {
        recordedCreateRequests
    }

    func recordQueries() -> [String] {
        recordedRecordQueries
    }

    func versionQueries() -> [RecordQuery] {
        recordedVersionQueries
    }

    func exactVersionQueries() -> [VersionQuery] {
        recordedExactVersionQueries
    }

    func draftRequests() -> [DraftRequest] {
        recordedDraftRequests
    }

    func confirmRequests() -> [ConfirmRequest] {
        recordedConfirmRequests
    }

    func restoreRequests() -> [RestoreRequest] {
        recordedRestoreRequests
    }
}

enum DevelopmentRecordRepositorySpyError: Error {
    case unconfigured
}

func requiredDevelopmentRecordRepositoryResult<Value>(_ value: Value?) throws -> Value {
    guard let value else {
        throw DevelopmentRecordRepositorySpyError.unconfigured
    }
    return value
}

func makeDevelopmentRecordGoal(
    status: DevelopmentGoal.Status = .inProgress
) throws -> DevelopmentGoal {
    try DevelopmentGoal(
        id: "goal-1",
        title: "개발 목표",
        description: "설명",
        status: status,
        createdAt: .distantPast,
        updatedAt: .distantPast,
        completedAt: status == .completed ? .distantPast : nil
    )
}

func makeDevelopmentRecordInitialDraft(
    revisionId: String = "revision-1",
    updatedAt: Date = .distantPast
) throws -> DevelopmentRecord {
    try makeDevelopmentRecord(
        currentVersion: nil,
        draft: DevelopmentRecord.Draft(
            title: "기록",
            markdownContent: "본문",
            baseVersionId: nil,
            revisionId: revisionId,
            updatedAt: updatedAt
        )
    )
}

func makeDevelopmentRecordConfirmed() throws -> DevelopmentRecord {
    try makeDevelopmentRecord(
        currentVersion: DevelopmentRecord.CurrentVersion(id: "version-1", number: 1),
        draft: nil
    )
}

func makeDevelopmentRecord(
    currentVersion: DevelopmentRecord.CurrentVersion?,
    draft: DevelopmentRecord.Draft?
) throws -> DevelopmentRecord {
    try DevelopmentRecord(
        id: "record-1",
        goalId: "goal-1",
        currentVersion: currentVersion,
        draft: draft,
        createdAt: .distantPast
    )
}

func makeDevelopmentRecordInitialVersion() throws -> DevelopmentRecord.Version {
    try DevelopmentRecord.Version(
        id: "version-1",
        recordId: "record-1",
        number: 1,
        title: "기록",
        markdownContent: "본문",
        kind: .initial,
        sourceVersionId: nil,
        confirmedAt: .distantPast
    )
}

func makeDevelopmentRecordCorrectionVersion(
    id: String,
    number: Int = 2,
    sourceVersionId: String
) throws -> DevelopmentRecord.Version {
    try DevelopmentRecord.Version(
        id: id,
        recordId: "record-1",
        number: number,
        title: "정정 기록",
        markdownContent: "본문",
        kind: .correction,
        sourceVersionId: sourceVersionId,
        confirmedAt: .distantPast
    )
}

func expectDevelopmentRecordDomainError<Value>(
    _ expected: DomainLayerError,
    operation: () async throws -> Value
) async {
    do {
        _ = try await operation()
        Issue.record("DomainLayerError가 필요")
    } catch let error as DomainLayerError {
        #expect(error == expected)
    } catch {
        Issue.record("예상하지 않은 오류: \(error)")
    }
}
