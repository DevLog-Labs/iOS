//
//  UpdateDevelopmentGoalUseCaseImpl.swift
//  Domain
//
//  Created by opfic on 11/23/26.
//

public final class UpdateDevelopmentGoalUseCaseImpl: UpdateDevelopmentGoalUseCase {
    private let repository: DevelopmentGoalRepository

    init(_ repository: DevelopmentGoalRepository) {
        self.repository = repository
    }

    public func execute(_ goalId: String, title: String, description: String) async throws -> DevelopmentGoal {
        try await repository.updateGoal(goalId, title: title, description: description)
    }
}
