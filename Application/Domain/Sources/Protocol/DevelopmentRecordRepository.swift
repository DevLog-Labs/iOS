//
//  DevelopmentRecordRepository.swift
//  Domain
//
//  Created by opfic on 8/27/26.
//

public protocol DevelopmentRecordRepository {
    func createRecord(
        id: String,
        goalId: String,
        draft: DevelopmentRecord.Draft
    ) async throws -> DevelopmentRecord
    func fetchRecords(goalId: String) async throws -> [DevelopmentRecord]
    func fetchRecord(goalId: String, recordId: String) async throws -> DevelopmentRecord
    func fetchVersion(
        goalId: String,
        recordId: String,
        versionId: String
    ) async throws -> DevelopmentRecord.Version
    func fetchVersions(goalId: String, recordId: String) async throws -> [DevelopmentRecord.Version]
    func saveDraft(
        goalId: String,
        recordId: String,
        expectedRevisionId: String?,
        draft: DevelopmentRecord.Draft
    ) async throws -> DevelopmentRecord
    func confirmDraft(
        goalId: String,
        recordId: String,
        confirmation: DevelopmentRecord.Confirmation
    ) async throws -> DevelopmentRecord.Version
    func restoreVersion(
        goalId: String,
        recordId: String,
        versionId: String,
        sourceVersionId: String
    ) async throws -> DevelopmentRecord.Version
}
