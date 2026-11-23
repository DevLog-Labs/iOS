//
//  DevelopmentGoalService.swift
//  Data
//
//  Created by opfic on 8/28/26.
//

public protocol DevelopmentGoalService {
    func createGoal(
        goalId: String,
        request: DevelopmentGoalCreateRequest
    ) async throws -> DevelopmentGoalResponse
    func updateGoal(
        goalId: String,
        request: DevelopmentGoalUpdateRequest
    ) async throws -> DevelopmentGoalResponse
    func fetchGoal(goalId: String) async throws -> DevelopmentGoalResponse
    func fetchGoals(_ query: DevelopmentGoalQuery) async throws -> [DevelopmentGoalResponse]
    func fetchCompletionSnapshot(
        goalId: String
    ) async throws -> DevelopmentGoalCompletionResponse
    func transitionGoalStatus(
        goalId: String,
        request: DevelopmentGoalStatusRequest
    ) async throws
}
