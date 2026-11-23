//
//  DevelopmentGoalRepositoryImplTests.swift
//  DataTests
//
//  Created by opfic on 8/28/26.
//

import Foundation
import Testing
import Domain
@testable import Data

struct DevelopmentGoalRepositoryImplTests {
    @Test("목표 생성은 markdownDescription 요청을 서비스에 전달한다")
    func 목표_생성은_markdownDescription_요청을_서비스에_전달한다() async throws {
        let service = DevelopmentGoalServiceSpy()
        let repository = DevelopmentGoalRepositoryImpl(service: service)

        let goal = try await repository.createGoal(
            id: "goal-1",
            title: "목표",
            description: "설명"
        )

        let request = try #require(await service.createRequest())
        #expect(goal.id == "goal-1")
        #expect(request.goalId == "goal-1")
        #expect(request.markdownDescription == "설명")
    }

    @Test("목표 수정은 제목과 markdownDescription 요청을 서비스에 전달한다")
    func 목표_수정은_제목과_markdownDescription_요청을_서비스에_전달한다() async throws {
        let service = DevelopmentGoalServiceSpy()
        let repository = DevelopmentGoalRepositoryImpl(service: service)

        let goal = try await repository.updateGoal(
            "goal-1",
            title: "바꾼 목표",
            description: "바꾼 설명"
        )

        let request = try #require(await service.updateRequest())
        #expect(goal.id == "goal-1")
        #expect(request.goalId == "goal-1")
        #expect(request.title == "바꾼 목표")
        #expect(request.markdownDescription == "바꾼 설명")
    }

    @Test("완료 검증 문맥은 목표 서비스 응답만으로 복원한다")
    func 완료_검증_문맥은_목표_서비스_응답만으로_복원한다() async throws {
        let service = DevelopmentGoalServiceSpy()
        let repository = DevelopmentGoalRepositoryImpl(service: service)

        let snapshot = try await repository.fetchCompletionSnapshot(for: "goal-1")

        #expect(snapshot.goal.id == "goal-1")
        #expect(snapshot.records.map(\.id) == ["record-1"])
        #expect(await service.completionSnapshotGoalIds() == ["goal-1"])
    }

    @Test("목표 상태 전환은 Data 상태를 서비스에 전달한다")
    func 목표_상태_전환은_Data_상태를_서비스에_전달한다() async throws {
        let service = DevelopmentGoalServiceSpy()
        let repository = DevelopmentGoalRepositoryImpl(service: service)

        try await repository.transitionGoalStatus(
            "goal-1",
            to: .archived,
            completionSnapshot: nil
        )

        let request = try #require(await service.transitionRequest())
        #expect(request.goalId == "goal-1")
        #expect(request.status == .archived)
    }

    @Test("목표 완료 전환은 서비스에 전달하지 않는다")
    func 목표_완료_전환은_서비스에_전달하지_않는다() async {
        let service = DevelopmentGoalServiceSpy()
        let repository = DevelopmentGoalRepositoryImpl(service: service)

        await #expect(throws: DomainLayerError.invalidDevelopmentGoalTransition) {
            try await repository.transitionGoalStatus(
                "goal-1",
                to: .completed,
                completionSnapshot: nil
            )
        }

        #expect(await service.transitionRequest() == nil)
    }
}

private actor DevelopmentGoalServiceSpy: DevelopmentGoalService {
    struct CreateRequest {
        let goalId: String
        let markdownDescription: String
    }

    struct UpdateRequest {
        let goalId: String
        let title: String
        let markdownDescription: String
    }

    struct TransitionRequest {
        let goalId: String
        let status: DevelopmentGoalStatus
    }

    private let goal = DevelopmentGoalResponse(
        id: "goal-1",
        title: "목표",
        markdownDescription: "설명",
        status: .inProgress,
        createdAt: .distantPast,
        updatedAt: .distantPast,
        completedAt: nil
    )
    private let record = DevelopmentRecordResponse(
        id: "record-1",
        goalId: "goal-1",
        currentVersion: .init(id: "version-1", number: 1),
        draft: nil,
        createdAt: .distantPast
    )
    private var recordedCreateRequest: CreateRequest?
    private var recordedUpdateRequest: UpdateRequest?
    private var recordedCompletionSnapshotGoalIds = [String]()
    private var recordedTransitionRequest: TransitionRequest?

    func createGoal(
        goalId: String,
        request: DevelopmentGoalCreateRequest
    ) async throws -> DevelopmentGoalResponse {
        recordedCreateRequest = .init(
            goalId: goalId,
            markdownDescription: request.markdownDescription
        )
        return goal
    }

    func updateGoal(
        goalId: String,
        request: DevelopmentGoalUpdateRequest
    ) async throws -> DevelopmentGoalResponse {
        recordedUpdateRequest = .init(
            goalId: goalId,
            title: request.title,
            markdownDescription: request.markdownDescription
        )
        return goal
    }

    func fetchGoal(goalId: String) async throws -> DevelopmentGoalResponse {
        goal
    }

    func fetchGoals(_ query: DevelopmentGoalQuery) async throws -> [DevelopmentGoalResponse] {
        [goal]
    }

    func fetchCompletionSnapshot(
        goalId: String
    ) async throws -> DevelopmentGoalCompletionResponse {
        recordedCompletionSnapshotGoalIds.append(goalId)
        return .init(goal: goal, records: [record])
    }

    func transitionGoalStatus(
        goalId: String,
        request: DevelopmentGoalStatusRequest
    ) async throws {
        recordedTransitionRequest = .init(goalId: goalId, status: request.status)
    }

    func createRequest() -> CreateRequest? {
        recordedCreateRequest
    }

    func updateRequest() -> UpdateRequest? {
        recordedUpdateRequest
    }

    func completionSnapshotGoalIds() -> [String] {
        recordedCompletionSnapshotGoalIds
    }

    func transitionRequest() -> TransitionRequest? {
        recordedTransitionRequest
    }
}
