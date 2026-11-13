//
//  RecordFeatureTestSupport.swift
//  DevelopmentTests
//
//  Created by opfic on 9/13/26.
//

import Domain
import Foundation
import PresentationShared

enum RecordTestError: Error {
    case failed
}

func makeRecordErrorAlert<Action>(
    _ messageKey: String.LocalizationValue
) -> AlertState<Action> {
    AlertState {
        TextState(String(localized: "common_error_title", bundle: PresentationResources.bundle))
    } actions: {
        ButtonState(role: .cancel) {
            TextState(String(localized: "common_close", bundle: PresentationResources.bundle))
        }
    } message: {
        TextState(String(localized: messageKey, bundle: PresentationResources.bundle))
    }
}

struct FetchDevelopmentGoalUseCaseStub: FetchDevelopmentGoalUseCase {
    let result: Result<DevelopmentGoal, Error>

    func execute(_ goalId: String) async throws -> DevelopmentGoal {
        try result.get()
    }
}

actor CreateDevelopmentGoalUseCaseSpy: CreateDevelopmentGoalUseCase {
    struct Request: Equatable {
        let title: String
        let description: String
    }

    private let result: Result<DevelopmentGoal, Error>
    private var recordedRequests = [Request]()

    init(result: Result<DevelopmentGoal, Error>) {
        self.result = result
    }

    func execute(title: String, description: String) async throws -> DevelopmentGoal {
        recordedRequests.append(.init(title: title, description: description))
        return try result.get()
    }

    func requests() -> [Request] {
        recordedRequests
    }
}

actor UpdateDevelopmentGoalStatusUseCaseSpy: UpdateDevelopmentGoalStatusUseCase {
    struct Request: Equatable {
        let goalId: String
        let status: DevelopmentGoal.Status
    }

    private let result: Result<Void, Error>
    private var recordedRequests = [Request]()

    init(result: Result<Void, Error> = .success(())) {
        self.result = result
    }

    func execute(_ goalId: String, to status: DevelopmentGoal.Status) async throws {
        recordedRequests.append(.init(goalId: goalId, status: status))
        try result.get()
    }

    func requests() -> [Request] {
        recordedRequests
    }
}

struct FetchDevelopmentRecordsUseCaseStub: FetchDevelopmentRecordsUseCase {
    let result: Result<[DevelopmentRecord], Error>

    func execute(goalId: String) async throws -> [DevelopmentRecord] {
        try result.get()
    }
}

struct FetchDevelopmentRecordHistoryUseCaseStub: FetchDevelopmentRecordHistoryUseCase {
    let resultByRecordId: [String: Result<[DevelopmentRecord.Version], Error>]

    func execute(
        goalId: String,
        recordId: String
    ) async throws -> [DevelopmentRecord.Version] {
        try resultByRecordId[recordId, default: .failure(RecordTestError.failed)].get()
    }
}

struct FetchDevelopmentRecordVersionUseCaseStub: FetchDevelopmentRecordVersionUseCase {
    let resultByRecordId: [String: Result<DevelopmentRecord.Version, Error>]

    func execute(
        goalId: String,
        recordId: String,
        versionId: String
    ) async throws -> DevelopmentRecord.Version {
        try resultByRecordId[recordId, default: .failure(RecordTestError.failed)].get()
    }
}

struct CreateDevelopmentRecordUseCaseStub: CreateDevelopmentRecordUseCase {
    let result: Result<DevelopmentRecord, Error>

    func execute(
        goalId: String,
        recordId: String,
        title: String,
        markdownContent: String
    ) async throws -> DevelopmentRecord {
        try result.get()
    }
}

struct SaveDevelopmentRecordDraftUseCaseStub: SaveDevelopmentRecordDraftUseCase {
    let result: Result<DevelopmentRecord, Error>

    func execute(
        goalId: String,
        recordId: String,
        baseVersionId: String?,
        draftRevisionId: String?,
        content: DevelopmentRecord.Content
    ) async throws -> DevelopmentRecord {
        try result.get()
    }
}

struct ConfirmDevelopmentRecordUseCaseStub: ConfirmDevelopmentRecordUseCase {
    let result: Result<DevelopmentRecord.Version, Error>

    func execute(
        goalId: String,
        recordId: String,
        versionId: String,
        baseVersionId: String?,
        draftRevisionId: String?
    ) async throws -> DevelopmentRecord.Version {
        try result.get()
    }
}

struct RestoreDevelopmentRecordUseCaseStub: RestoreDevelopmentRecordUseCase {
    let result: Result<DevelopmentRecord.Version, Error>

    func execute(
        goalId: String,
        recordId: String,
        versionId: String,
        sourceVersionId: String
    ) async throws -> DevelopmentRecord.Version {
        try result.get()
    }
}

actor CreateDevelopmentRecordUseCaseSpy: CreateDevelopmentRecordUseCase {
    struct Request: Equatable {
        let goalId: String
        let recordId: String
        let title: String
        let markdownContent: String
    }

    private var results: [Result<DevelopmentRecord, Error>]
    private var recordedRequests = [Request]()

    init(result: Result<DevelopmentRecord, Error>) {
        self.results = [result]
    }

    init(results: [Result<DevelopmentRecord, Error>]) {
        self.results = results
    }

    func execute(
        goalId: String,
        recordId: String,
        title: String,
        markdownContent: String
    ) async throws -> DevelopmentRecord {
        recordedRequests.append(.init(
            goalId: goalId,
            recordId: recordId,
            title: title,
            markdownContent: markdownContent
        ))
        guard !results.isEmpty else { throw RecordTestError.failed }
        return try results.removeFirst().get()
    }

    func requests() -> [Request] {
        recordedRequests
    }
}

actor ConfirmDevelopmentRecordUseCaseSpy: ConfirmDevelopmentRecordUseCase {
    struct Request: Equatable {
        let goalId: String
        let recordId: String
        let versionId: String
        let baseVersionId: String?
        let draftRevisionId: String?
    }

    private var results: [Result<DevelopmentRecord.Version, Error>]
    private var recordedRequests = [Request]()

    init(results: [Result<DevelopmentRecord.Version, Error>]) {
        self.results = results
    }

    func execute(
        goalId: String,
        recordId: String,
        versionId: String,
        baseVersionId: String?,
        draftRevisionId: String?
    ) async throws -> DevelopmentRecord.Version {
        recordedRequests.append(.init(
            goalId: goalId,
            recordId: recordId,
            versionId: versionId,
            baseVersionId: baseVersionId,
            draftRevisionId: draftRevisionId
        ))
        guard !results.isEmpty else { throw RecordTestError.failed }
        return try results.removeFirst().get()
    }

    func requests() -> [Request] {
        recordedRequests
    }
}

actor RestoreDevelopmentRecordUseCaseSpy: RestoreDevelopmentRecordUseCase {
    struct Request: Equatable {
        let goalId: String
        let recordId: String
        let versionId: String
        let sourceVersionId: String
    }

    private var results: [Result<DevelopmentRecord.Version, Error>]
    private var recordedRequests = [Request]()

    init(result: Result<DevelopmentRecord.Version, Error>) {
        self.results = [result]
    }

    init(results: [Result<DevelopmentRecord.Version, Error>]) {
        self.results = results
    }

    func execute(
        goalId: String,
        recordId: String,
        versionId: String,
        sourceVersionId: String
    ) async throws -> DevelopmentRecord.Version {
        recordedRequests.append(.init(
            goalId: goalId,
            recordId: recordId,
            versionId: versionId,
            sourceVersionId: sourceVersionId
        ))
        guard !results.isEmpty else { throw RecordTestError.failed }
        return try results.removeFirst().get()
    }

    func requests() -> [Request] {
        recordedRequests
    }
}

func makeDevelopmentGoal(
    title: String = "개발 목표",
    status: DevelopmentGoal.Status = .inProgress
) throws -> DevelopmentGoal {
    let date = Date(timeIntervalSince1970: 1_700_000_000)
    return try DevelopmentGoal(
        id: "goal",
        title: title,
        description: "설명",
        status: status,
        createdAt: date,
        updatedAt: date,
        completedAt: status == .completed ? date : nil
    )
}

func makeDevelopmentRecord(
    id: String = "record",
    currentVersion: DevelopmentRecord.CurrentVersion? = nil,
    draft: DevelopmentRecord.Draft? = nil,
    createdAt: Date = Date(timeIntervalSince1970: 1_700_000_000)
) throws -> DevelopmentRecord {
    try DevelopmentRecord(
        id: id,
        goalId: "goal",
        currentVersion: currentVersion,
        draft: draft ?? makeDevelopmentRecordDraft(),
        createdAt: createdAt
    )
}

func makeConfirmedDevelopmentRecord(
    id: String = "record",
    versionId: String = "version",
    versionNumber: Int = 1,
    draft: DevelopmentRecord.Draft? = nil
) throws -> DevelopmentRecord {
    try DevelopmentRecord(
        id: id,
        goalId: "goal",
        currentVersion: DevelopmentRecord.CurrentVersion(id: versionId, number: versionNumber),
        draft: draft,
        createdAt: Date(timeIntervalSince1970: 1_700_000_000)
    )
}

func makeDevelopmentRecordDraft(
    title: String = "기록 제목",
    markdownContent: String = "# 내용",
    baseVersionId: String? = nil,
    revisionId: String = "revision"
) throws -> DevelopmentRecord.Draft {
    try DevelopmentRecord.Draft(
        title: title,
        markdownContent: markdownContent,
        baseVersionId: baseVersionId,
        revisionId: revisionId,
        updatedAt: Date(timeIntervalSince1970: 1_700_000_100)
    )
}

func makeDevelopmentRecordVersion(
    id: String = "version",
    recordId: String = "record",
    number: Int = 1,
    title: String = "확정 기록",
    markdownContent: String = "# 확정 내용",
    kind: DevelopmentRecord.Version.Kind = .initial,
    sourceVersionId: String? = nil
) throws -> DevelopmentRecord.Version {
    try DevelopmentRecord.Version(
        id: id,
        recordId: recordId,
        number: number,
        title: title,
        markdownContent: markdownContent,
        kind: kind,
        sourceVersionId: sourceVersionId,
        confirmedAt: Date(timeIntervalSince1970: 1_700_000_200 + Double(number))
    )
}
