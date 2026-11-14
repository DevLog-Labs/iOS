//
//  DevelopmentRecordRepositoryImplTests.swift
//  DataTests
//
//  Created by opfic on 8/28/26.
//

import Foundation
import Testing
import Domain
@testable import Data

struct DevelopmentRecordRepositoryImplTests {
    @Test("기록 생성은 Data 초안 요청을 서비스에 전달한다")
    func 기록_생성은_Data_초안_요청을_서비스에_전달한다() async throws {
        let service = DevelopmentRecordServiceSpy(response: makeRecordResponse())
        let repository = DevelopmentRecordRepositoryImpl(service: service)
        let draft = try DevelopmentRecord.Draft(
            title: "기록",
            markdownContent: "본문",
            baseVersionId: nil,
            updatedAt: .distantPast
        )

        let record = try await repository.createRecord(
            id: "record-1",
            goalId: "goal-1",
            draft: draft
        )

        let request = try #require(await service.createRequest())
        #expect(record.id == "record-1")
        #expect(request.goalId == "goal-1")
        #expect(request.recordId == "record-1")
        #expect(request.draft.title == "기록")
    }

    @Test("기록 확정은 버전 종류와 원본 버전을 서비스에 전달한다")
    func 기록_확정은_버전_종류와_원본_버전을_서비스에_전달한다() async throws {
        let service = DevelopmentRecordServiceSpy(version: makeVersionResponse())
        let repository = DevelopmentRecordRepositoryImpl(service: service)

        let version = try await repository.confirmDraft(
            goalId: "goal-1",
            recordId: "record-1",
            confirmation: .init(
                versionId: "version-2",
                kind: .correction,
                sourceVersionId: "version-1",
                draftRevisionId: "revision-1"
            )
        )

        let request = try #require(await service.confirmationRequest())
        #expect(version.kind == .correction)
        #expect(request.versionId == "version-2")
        #expect(request.kind == "correction")
        #expect(request.sourceVersionId == "version-1")
        #expect(request.draftRevisionId == "revision-1")
    }
}

private actor DevelopmentRecordServiceSpy: DevelopmentRecordService {
    struct CreateRequest {
        let goalId: String
        let recordId: String
        let draft: DevelopmentRecordDraftRequest
    }

    private let response: DevelopmentRecordResponse
    private let version: DevelopmentRecordVersionResponse
    private var recordedCreateRequest: CreateRequest?
    private var recordedConfirmationRequest: DevelopmentRecordConfirmationRequest?

    init(
        response: DevelopmentRecordResponse = makeRecordResponse(),
        version: DevelopmentRecordVersionResponse = makeVersionResponse()
    ) {
        self.response = response
        self.version = version
    }

    func createRecord(
        goalId: String,
        recordId: String,
        request: DevelopmentRecordCreateRequest
    ) async throws -> DevelopmentRecordResponse {
        recordedCreateRequest = .init(goalId: goalId, recordId: recordId, draft: request.draft)
        return response
    }

    func fetchRecords(goalId: String) async throws -> [DevelopmentRecordResponse] {
        [response]
    }

    func fetchRecord(goalId: String, recordId: String) async throws -> DevelopmentRecordResponse {
        response
    }

    func fetchVersions(
        goalId: String,
        recordId: String
    ) async throws -> [DevelopmentRecordVersionResponse] {
        [version]
    }

    func fetchVersion(
        goalId: String,
        recordId: String,
        versionId: String
    ) async throws -> DevelopmentRecordVersionResponse {
        version
    }

    func saveDraft(
        goalId: String,
        recordId: String,
        request: DevelopmentRecordDraftRequest
    ) async throws -> DevelopmentRecordResponse {
        response
    }

    func confirmDraft(
        goalId: String,
        recordId: String,
        request: DevelopmentRecordConfirmationRequest
    ) async throws -> DevelopmentRecordVersionResponse {
        recordedConfirmationRequest = request
        return version
    }

    func restoreVersion(
        goalId: String,
        recordId: String,
        request: DevelopmentRecordRestoreRequest
    ) async throws -> DevelopmentRecordVersionResponse {
        version
    }

    func createRequest() -> CreateRequest? {
        recordedCreateRequest
    }

    func confirmationRequest() -> DevelopmentRecordConfirmationRequest? {
        recordedConfirmationRequest
    }
}

private func makeRecordResponse() -> DevelopmentRecordResponse {
    DevelopmentRecordResponse(
        id: "record-1",
        goalId: "goal-1",
        currentVersion: nil,
        draft: .init(
            title: "기록",
            markdownContent: "본문",
            baseVersionId: nil,
            updatedAt: .distantPast
        ),
        createdAt: .distantPast
    )
}

private func makeVersionResponse() -> DevelopmentRecordVersionResponse {
    DevelopmentRecordVersionResponse(
        id: "version-2",
        recordId: "record-1",
        number: 2,
        title: "기록",
        markdownContent: "본문",
        kind: "correction",
        sourceVersionId: "version-1",
        confirmedAt: .distantPast
    )
}
