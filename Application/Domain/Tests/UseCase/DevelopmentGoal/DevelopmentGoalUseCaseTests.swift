//
//  DevelopmentGoalUseCaseTests.swift
//  DomainTests
//
//  Created by opfic on 8/27/26.
//

import Foundation
import Testing
@testable import Domain

struct DevelopmentGoalUseCaseTests {
    @Test("목표 생성은 주입한 ID와 입력값을 Repository에 전달한다")
    func 목표_생성은_주입한_ID와_입력값을_Repository에_전달한다() async throws {
        let goal = try makeGoal(id: "goal-1")
        let repository = DevelopmentGoalRepositorySpy(goal: goal)
        let useCase = CreateDevelopmentGoalUseCaseImpl(repository, idProvider: { "goal-1" })

        let result = try await useCase.execute(title: "목표", description: "설명")

        #expect(result == goal)
        #expect(await repository.createRequests() == [
            .init(id: "goal-1", title: "목표", description: "설명")
        ])
    }

    @Test("단건 목표 조회는 Repository 결과를 반환한다")
    func 단건_목표_조회는_Repository_결과를_반환한다() async throws {
        let goal = try makeGoal(id: "goal-1")
        let repository = DevelopmentGoalRepositorySpy(goal: goal)
        let useCase = FetchDevelopmentGoalUseCaseImpl(repository)

        let result = try await useCase.execute("goal-1")

        #expect(result == goal)
        #expect(await repository.fetchedGoalIds() == ["goal-1"])
    }

    @Test("목표 목록 조회는 상태를 필터링하고 생성 시각과 ID 오름차순으로 정렬한다")
    func 목표_목록_조회는_상태를_필터링하고_생성_시각과_ID_오름차순으로_정렬한다() async throws {
        let laterGoal = try makeGoal(id: "goal-3", createdAt: .distantFuture)
        let archivedGoal = try makeGoal(id: "goal-2", status: .archived)
        let earlierGoal = try makeGoal(id: "goal-1")
        let repository = DevelopmentGoalRepositorySpy(
            goal: earlierGoal,
            goals: [laterGoal, archivedGoal, earlierGoal]
        )
        let useCase = FetchDevelopmentGoalsUseCaseImpl(repository)

        let result = try await useCase.execute(.init(status: .inProgress))

        #expect(result == [earlierGoal, laterGoal])
        #expect(await repository.queries() == [.init(status: .inProgress)])
    }

    @Test("진행 중 목표의 보관 전환은 완료 검증 문맥 없이 요청한다")
    func 진행_중_목표의_보관_전환은_완료_검증_문맥_없이_요청한다() async throws {
        let goal = try makeGoal(id: "goal-1")
        let repository = DevelopmentGoalRepositorySpy(goal: goal)
        let useCase = UpdateDevelopmentGoalStatusUseCaseImpl(repository)

        try await useCase.execute("goal-1", to: .archived)

        #expect(await repository.transitions() == [
            .init(goalId: "goal-1", status: .archived, completionSnapshot: nil)
        ])
    }

    @Test("완료 전환은 유효한 전체 기록 문맥을 Repository에 전달한다")
    func 완료_전환은_유효한_전체_기록_문맥을_Repository에_전달한다() async throws {
        let goal = try makeGoal(id: "goal-1")
        let record = try makeConfirmedRecord(id: "record-1", createdAt: .distantPast)
        let snapshot = DevelopmentGoal.CompletionSnapshot(goal: goal, records: [record])
        let repository = DevelopmentGoalRepositorySpy(goal: goal, snapshot: snapshot)
        let useCase = UpdateDevelopmentGoalStatusUseCaseImpl(repository)

        try await useCase.execute("goal-1", to: .completed)

        #expect(await repository.completionSnapshotGoalIds() == ["goal-1"])
        #expect(await repository.transitions() == [
            .init(goalId: "goal-1", status: .completed, completionSnapshot: snapshot)
        ])
    }

    @Test("완료 스냅샷의 목표 상태가 전환을 허용하지 않으면 완료를 거부한다")
    func 완료_스냅샷의_목표_상태가_전환을_허용하지_않으면_완료를_거부한다() async throws {
        let goal = try makeGoal(id: "goal-1")
        let archivedGoal = try makeGoal(id: "goal-1", status: .archived)
        let record = try makeConfirmedRecord(id: "record-1", createdAt: .distantPast)
        let snapshot = DevelopmentGoal.CompletionSnapshot(goal: archivedGoal, records: [record])
        let repository = DevelopmentGoalRepositorySpy(goal: goal, snapshot: snapshot)
        let useCase = UpdateDevelopmentGoalStatusUseCaseImpl(repository)

        await expectDomainError(.invalidDevelopmentGoalTransition) {
            try await useCase.execute("goal-1", to: .completed)
        }
        #expect(await repository.transitions().isEmpty)
    }

    @Test("기록이 없으면 완료 전환을 거부한다")
    func 기록이_없으면_완료_전환을_거부한다() async throws {
        let goal = try makeGoal(id: "goal-1")
        let snapshot = DevelopmentGoal.CompletionSnapshot(goal: goal, records: [])
        let repository = DevelopmentGoalRepositorySpy(goal: goal, snapshot: snapshot)
        let useCase = UpdateDevelopmentGoalStatusUseCaseImpl(repository)

        await expectDomainError(.developmentGoalCompletionRequiresRecord) {
            try await useCase.execute("goal-1", to: .completed)
        }
        #expect(await repository.transitions().isEmpty)
    }

    @Test("마지막 기록에 현재 버전이 없으면 완료 전환을 거부한다")
    func 마지막_기록에_현재_버전이_없으면_완료_전환을_거부한다() async throws {
        let goal = try makeGoal(id: "goal-1")
        let record = try makeInitialDraftRecord(id: "record-1", createdAt: .distantPast)
        let snapshot = DevelopmentGoal.CompletionSnapshot(goal: goal, records: [record])
        let repository = DevelopmentGoalRepositorySpy(goal: goal, snapshot: snapshot)
        let useCase = UpdateDevelopmentGoalStatusUseCaseImpl(repository)

        await expectDomainError(.developmentGoalCompletionNeedsVersion) {
            try await useCase.execute("goal-1", to: .completed)
        }
        #expect(await repository.transitions().isEmpty)
    }

    @Test("남은 초안이 있으면 완료 전환을 거부한다")
    func 남은_초안이_있으면_완료_전환을_거부한다() async throws {
        let goal = try makeGoal(id: "goal-1")
        let draftRecord = try makeDraftRecord(id: "record-1", createdAt: .distantPast)
        let confirmedRecord = try makeConfirmedRecord(id: "record-2", createdAt: .distantFuture)
        let snapshot = DevelopmentGoal.CompletionSnapshot(
            goal: goal,
            records: [confirmedRecord, draftRecord]
        )
        let repository = DevelopmentGoalRepositorySpy(goal: goal, snapshot: snapshot)
        let useCase = UpdateDevelopmentGoalStatusUseCaseImpl(repository)

        await expectDomainError(.developmentGoalCompletionHasDraft) {
            try await useCase.execute("goal-1", to: .completed)
        }
        #expect(await repository.transitions().isEmpty)
    }
}

private actor DevelopmentGoalRepositorySpy: DevelopmentGoalRepository {
    struct CreateRequest: Equatable {
        let id: String
        let title: String
        let description: String
    }

    struct TransitionRequest: Equatable {
        let goalId: String
        let status: DevelopmentGoal.Status
        let completionSnapshot: DevelopmentGoal.CompletionSnapshot?
    }

    private let goal: DevelopmentGoal
    private let goals: [DevelopmentGoal]
    private let snapshot: DevelopmentGoal.CompletionSnapshot?
    private var recordedCreateRequests = [CreateRequest]()
    private var recordedFetchedGoalIds = [String]()
    private var recordedQueries = [DevelopmentGoal.Query]()
    private var recordedCompletionSnapshotGoalIds = [String]()
    private var recordedTransitions = [TransitionRequest]()

    init(
        goal: DevelopmentGoal,
        goals: [DevelopmentGoal]? = nil,
        snapshot: DevelopmentGoal.CompletionSnapshot? = nil
    ) {
        self.goal = goal
        self.goals = goals ?? [goal]
        self.snapshot = snapshot
    }

    func createGoal(
        id: String,
        title: String,
        description: String
    ) async throws -> DevelopmentGoal {
        recordedCreateRequests.append(.init(id: id, title: title, description: description))
        return goal
    }

    func updateGoal(
        _ goalId: String,
        title: String,
        description: String
    ) async throws -> DevelopmentGoal {
        goal
    }

    func fetchGoal(_ goalId: String) async throws -> DevelopmentGoal {
        recordedFetchedGoalIds.append(goalId)
        return goal
    }

    func fetchGoals(_ query: DevelopmentGoal.Query) async throws -> [DevelopmentGoal] {
        recordedQueries.append(query)
        return goals
    }

    func fetchCompletionSnapshot(for goalId: String) async throws -> DevelopmentGoal.CompletionSnapshot {
        recordedCompletionSnapshotGoalIds.append(goalId)
        guard let snapshot else {
            throw DevelopmentGoalRepositorySpyError.snapshotNotFound
        }
        return snapshot
    }

    func transitionGoalStatus(
        _ goalId: String,
        to status: DevelopmentGoal.Status,
        completionSnapshot: DevelopmentGoal.CompletionSnapshot?
    ) async throws {
        recordedTransitions.append(
            .init(
                goalId: goalId,
                status: status,
                completionSnapshot: completionSnapshot
            )
        )
    }

    func createRequests() -> [CreateRequest] {
        recordedCreateRequests
    }

    func fetchedGoalIds() -> [String] {
        recordedFetchedGoalIds
    }

    func queries() -> [DevelopmentGoal.Query] {
        recordedQueries
    }

    func completionSnapshotGoalIds() -> [String] {
        recordedCompletionSnapshotGoalIds
    }

    func transitions() -> [TransitionRequest] {
        recordedTransitions
    }
}

private enum DevelopmentGoalRepositorySpyError: Error {
    case snapshotNotFound
}

private func makeGoal(
    id: String,
    status: DevelopmentGoal.Status = .inProgress,
    createdAt: Date = .distantPast
) throws -> DevelopmentGoal {
    try DevelopmentGoal(
        id: id,
        title: "개발 목표",
        description: "설명",
        status: status,
        createdAt: createdAt,
        updatedAt: createdAt,
        completedAt: status == .completed ? createdAt : nil
    )
}

private func makeInitialDraftRecord(id: String, createdAt: Date) throws -> DevelopmentRecord {
    let draft = try DevelopmentRecord.Draft(
        title: "기록",
        markdownContent: "본문",
        baseVersionId: nil,
        updatedAt: createdAt
    )
    return try DevelopmentRecord(
        id: id,
        goalId: "goal-1",
        currentVersion: nil,
        draft: draft,
        createdAt: createdAt
    )
}

private func makeConfirmedRecord(id: String, createdAt: Date) throws -> DevelopmentRecord {
    let currentVersion = try DevelopmentRecord.CurrentVersion(id: "version-\(id)", number: 1)
    return try DevelopmentRecord(
        id: id,
        goalId: "goal-1",
        currentVersion: currentVersion,
        draft: nil,
        createdAt: createdAt
    )
}

private func makeDraftRecord(id: String, createdAt: Date) throws -> DevelopmentRecord {
    let currentVersion = try DevelopmentRecord.CurrentVersion(id: "version-\(id)", number: 1)
    let draft = try DevelopmentRecord.Draft(
        title: "정정 초안",
        markdownContent: "본문",
        baseVersionId: currentVersion.id,
        updatedAt: createdAt
    )
    return try DevelopmentRecord(
        id: id,
        goalId: "goal-1",
        currentVersion: currentVersion,
        draft: draft,
        createdAt: createdAt
    )
}

private func expectDomainError(
    _ expected: DomainLayerError,
    operation: () async throws -> Void
) async {
    do {
        try await operation()
        Issue.record("DomainLayerError가 필요")
    } catch let error as DomainLayerError {
        #expect(error == expected)
    } catch {
        Issue.record("예상하지 않은 오류: \(error)")
    }
}
