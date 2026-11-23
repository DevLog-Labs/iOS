//
//  DevelopmentGoalUseCaseGraph.swift
//  Domain
//
//  Created by opfic on 9/7/26.
//

import Cradle

public struct DevelopmentGoalUseCaseGraphInput {
    public let repository: DevelopmentGoalRepository

    public init(repository: DevelopmentGoalRepository) {
        self.repository = repository
    }
}

@DependencyGraph(input: DevelopmentGoalUseCaseGraphInput.self)
public final class DevelopmentGoalUseCaseGraph {
    @Provide
    private func makeCreateDevelopmentGoalUseCase() -> CreateDevelopmentGoalUseCase {
        CreateDevelopmentGoalUseCaseImpl(input.repository)
    }

    @Provide
    private func makeFetchDevelopmentGoalUseCase() -> FetchDevelopmentGoalUseCase {
        FetchDevelopmentGoalUseCaseImpl(input.repository)
    }

    @Provide
    private func makeFetchDevelopmentGoalsUseCase() -> FetchDevelopmentGoalsUseCase {
        FetchDevelopmentGoalsUseCaseImpl(input.repository)
    }

    @Provide
    private func makeUpdateDevelopmentGoalUseCase() -> UpdateDevelopmentGoalUseCase {
        UpdateDevelopmentGoalUseCaseImpl(input.repository)
    }

    @Provide
    private func makeUpdateDevelopmentGoalStatusUseCase() -> UpdateDevelopmentGoalStatusUseCase {
        UpdateDevelopmentGoalStatusUseCaseImpl(input.repository)
    }
}
