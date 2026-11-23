//
//  UpdateDevelopmentGoalUseCase.swift
//  Domain
//
//  Created by opfic on 11/23/26.
//

public protocol UpdateDevelopmentGoalUseCase {
    func execute(_ goalId: String, title: String, description: String) async throws -> DevelopmentGoal
}
