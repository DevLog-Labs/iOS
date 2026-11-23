//
//  DevelopmentGoalRepositoryImpl.swift
//  Data
//
//  Created by opfic on 8/28/26.
//

import Domain

final class DevelopmentGoalRepositoryImpl: DevelopmentGoalRepository {
    private let service: DevelopmentGoalService

    init(service: DevelopmentGoalService) {
        self.service = service
    }

    func createGoal(
        id: String,
        title: String,
        description: String
    ) async throws -> DevelopmentGoal {
        do {
            let response = try await service.createGoal(
                goalId: id,
                request: .init(title: title, markdownDescription: description)
            )
            return try response.toDomain()
        } catch {
            throw error.toDomain()
        }
    }

    func updateGoal(
        _ goalId: String,
        title: String,
        description: String
    ) async throws -> DevelopmentGoal {
        do {
            let response = try await service.updateGoal(
                goalId: goalId,
                request: .init(title: title, markdownDescription: description)
            )
            return try response.toDomain()
        } catch {
            throw error.toDomain()
        }
    }

    func fetchGoal(_ goalId: String) async throws -> DevelopmentGoal {
        do {
            return try await service.fetchGoal(goalId: goalId).toDomain()
        } catch {
            throw error.toDomain()
        }
    }

    func fetchGoals(_ query: DevelopmentGoal.Query) async throws -> [DevelopmentGoal] {
        do {
            return try await service.fetchGoals(.fromDomain(query)).map { try $0.toDomain() }
        } catch {
            throw error.toDomain()
        }
    }

    func fetchCompletionSnapshot(
        for goalId: String
    ) async throws -> DevelopmentGoal.CompletionSnapshot {
        do {
            return try await service.fetchCompletionSnapshot(goalId: goalId).toDomain()
        } catch {
            throw error.toDomain()
        }
    }

    func transitionGoalStatus(
        _ goalId: String,
        to status: DevelopmentGoal.Status,
        completionSnapshot: DevelopmentGoal.CompletionSnapshot?
    ) async throws {
        do {
            guard status != .completed else {
                throw DomainLayerError.invalidDevelopmentGoalTransition
            }
            try await service.transitionGoalStatus(
                goalId: goalId,
                request: .init(status: .fromDomain(status))
            )
        } catch {
            throw error.toDomain()
        }
    }
}
