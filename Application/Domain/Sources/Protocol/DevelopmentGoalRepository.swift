//
//  DevelopmentGoalRepository.swift
//  Domain
//
//  Created by opfic on 8/27/26.
//

public protocol DevelopmentGoalRepository {
    func createGoal(
        id: String,
        title: String,
        description: String
    ) async throws -> DevelopmentGoal
    func updateGoal(
        _ goalId: String,
        title: String,
        description: String
    ) async throws -> DevelopmentGoal
    func fetchGoal(_ goalId: String) async throws -> DevelopmentGoal
    func fetchGoals(_ query: DevelopmentGoal.Query) async throws -> [DevelopmentGoal]
    func fetchCompletionSnapshot(for goalId: String) async throws -> DevelopmentGoal.CompletionSnapshot
    func transitionGoalStatus(
        _ goalId: String,
        to status: DevelopmentGoal.Status,
        completionSnapshot: DevelopmentGoal.CompletionSnapshot?
    ) async throws
}
