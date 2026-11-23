//
//  DevelopmentDependencyPreparation.swift
//  HomeTab
//
//  Created by opfic on 10/5/26.
//

import Domain
import PresentationShared

public enum DevelopmentDependencyPreparation {
    public static func prepareGoal(
        _ dependencies: inout DependencyValues,
        createGoalUseCase: CreateDevelopmentGoalUseCase,
        fetchGoalUseCase: FetchDevelopmentGoalUseCase,
        updateGoalUseCase: UpdateDevelopmentGoalUseCase,
        updateGoalStatusUseCase: UpdateDevelopmentGoalStatusUseCase
    ) {
        dependencies.developmentCreateGoalUseCase = createGoalUseCase
        dependencies.developmentFetchGoalUseCase = fetchGoalUseCase
        dependencies.developmentUpdateGoalUseCase = updateGoalUseCase
        dependencies.developmentUpdateGoalStatusUseCase = updateGoalStatusUseCase
    }

    public static func prepareQuery(
        _ dependencies: inout DependencyValues,
        fetchRecordsUseCase: FetchDevelopmentRecordsUseCase,
        fetchRecordHistoryUseCase: FetchDevelopmentRecordHistoryUseCase,
        fetchRecordVersionUseCase: FetchDevelopmentRecordVersionUseCase
    ) {
        dependencies.developmentFetchRecordsUseCase = fetchRecordsUseCase
        dependencies.developmentFetchRecordHistoryUseCase = fetchRecordHistoryUseCase
        dependencies.developmentFetchRecordVersionUseCase = fetchRecordVersionUseCase
    }

    public static func prepareMutation(
        _ dependencies: inout DependencyValues,
        createRecordUseCase: CreateDevelopmentRecordUseCase,
        saveRecordDraftUseCase: SaveDevelopmentRecordDraftUseCase,
        confirmRecordUseCase: ConfirmDevelopmentRecordUseCase,
        restoreRecordUseCase: RestoreDevelopmentRecordUseCase
    ) {
        dependencies.developmentCreateRecordUseCase = createRecordUseCase
        dependencies.developmentSaveRecordDraftUseCase = saveRecordDraftUseCase
        dependencies.developmentConfirmRecordUseCase = confirmRecordUseCase
        dependencies.developmentRestoreRecordUseCase = restoreRecordUseCase
    }

    public static func prepareTodo(
        _ dependencies: inout DependencyValues,
        fetchTodosUseCase: FetchTodosUseCase,
        updateTodoGoalUseCase: UpdateTodoGoalUseCase
    ) {
        dependencies.developmentFetchTodosUseCase = fetchTodosUseCase
        dependencies.developmentUpdateTodoGoalUseCase = updateTodoGoalUseCase
    }
}

extension DependencyValues {
    var developmentCreateGoalUseCase: CreateDevelopmentGoalUseCase {
        get { self[CreateGoalUseCaseKey.self] }
        set { self[CreateGoalUseCaseKey.self] = newValue }
    }

    var developmentFetchGoalUseCase: FetchDevelopmentGoalUseCase {
        get { self[FetchGoalUseCaseKey.self] }
        set { self[FetchGoalUseCaseKey.self] = newValue }
    }

    var developmentFetchRecordsUseCase: FetchDevelopmentRecordsUseCase {
        get { self[FetchRecordsUseCaseKey.self] }
        set { self[FetchRecordsUseCaseKey.self] = newValue }
    }

    var developmentUpdateGoalUseCase: UpdateDevelopmentGoalUseCase {
        get { self[UpdateGoalUseCaseKey.self] }
        set { self[UpdateGoalUseCaseKey.self] = newValue }
    }

    var developmentUpdateGoalStatusUseCase: UpdateDevelopmentGoalStatusUseCase {
        get { self[UpdateGoalStatusUseCaseKey.self] }
        set { self[UpdateGoalStatusUseCaseKey.self] = newValue }
    }

    var developmentFetchRecordHistoryUseCase: FetchDevelopmentRecordHistoryUseCase {
        get { self[FetchRecordHistoryUseCaseKey.self] }
        set { self[FetchRecordHistoryUseCaseKey.self] = newValue }
    }

    var developmentFetchRecordVersionUseCase: FetchDevelopmentRecordVersionUseCase {
        get { self[FetchRecordVersionUseCaseKey.self] }
        set { self[FetchRecordVersionUseCaseKey.self] = newValue }
    }

    var developmentCreateRecordUseCase: CreateDevelopmentRecordUseCase {
        get { self[CreateRecordUseCaseKey.self] }
        set { self[CreateRecordUseCaseKey.self] = newValue }
    }

    var developmentSaveRecordDraftUseCase: SaveDevelopmentRecordDraftUseCase {
        get { self[SaveRecordDraftUseCaseKey.self] }
        set { self[SaveRecordDraftUseCaseKey.self] = newValue }
    }

    var developmentConfirmRecordUseCase: ConfirmDevelopmentRecordUseCase {
        get { self[ConfirmRecordUseCaseKey.self] }
        set { self[ConfirmRecordUseCaseKey.self] = newValue }
    }

    var developmentRestoreRecordUseCase: RestoreDevelopmentRecordUseCase {
        get { self[RestoreRecordUseCaseKey.self] }
        set { self[RestoreRecordUseCaseKey.self] = newValue }
    }

    var developmentFetchTodosUseCase: FetchTodosUseCase {
        get { self[FetchTodosUseCaseKey.self] }
        set { self[FetchTodosUseCaseKey.self] = newValue }
    }

    var developmentUpdateTodoGoalUseCase: UpdateTodoGoalUseCase {
        get { self[UpdateTodoGoalUseCaseKey.self] }
        set { self[UpdateTodoGoalUseCaseKey.self] = newValue }
    }
}

private enum CreateGoalUseCaseKey: DependencyKey {
    static var liveValue: CreateDevelopmentGoalUseCase {
        preconditionFailure("CreateDevelopmentGoalUseCase must be provided.")
    }
}

private enum FetchGoalUseCaseKey: DependencyKey {
    static var liveValue: FetchDevelopmentGoalUseCase {
        preconditionFailure("FetchDevelopmentGoalUseCase must be provided.")
    }
}

private enum FetchRecordsUseCaseKey: DependencyKey {
    static var liveValue: FetchDevelopmentRecordsUseCase {
        preconditionFailure("FetchDevelopmentRecordsUseCase must be provided.")
    }
}

private enum UpdateGoalUseCaseKey: DependencyKey {
    static var liveValue: UpdateDevelopmentGoalUseCase {
        preconditionFailure("UpdateDevelopmentGoalUseCase must be provided.")
    }
}

private enum UpdateGoalStatusUseCaseKey: DependencyKey {
    static var liveValue: UpdateDevelopmentGoalStatusUseCase {
        preconditionFailure("UpdateDevelopmentGoalStatusUseCase must be provided.")
    }
}

private enum FetchRecordHistoryUseCaseKey: DependencyKey {
    static var liveValue: FetchDevelopmentRecordHistoryUseCase {
        preconditionFailure("FetchDevelopmentRecordHistoryUseCase must be provided.")
    }
}

private enum FetchRecordVersionUseCaseKey: DependencyKey {
    static var liveValue: FetchDevelopmentRecordVersionUseCase {
        preconditionFailure("FetchDevelopmentRecordVersionUseCase must be provided.")
    }
}

private enum CreateRecordUseCaseKey: DependencyKey {
    static var liveValue: CreateDevelopmentRecordUseCase {
        preconditionFailure("CreateDevelopmentRecordUseCase must be provided.")
    }
}

private enum SaveRecordDraftUseCaseKey: DependencyKey {
    static var liveValue: SaveDevelopmentRecordDraftUseCase {
        preconditionFailure("SaveDevelopmentRecordDraftUseCase must be provided.")
    }
}

private enum ConfirmRecordUseCaseKey: DependencyKey {
    static var liveValue: ConfirmDevelopmentRecordUseCase {
        preconditionFailure("ConfirmDevelopmentRecordUseCase must be provided.")
    }
}

private enum RestoreRecordUseCaseKey: DependencyKey {
    static var liveValue: RestoreDevelopmentRecordUseCase {
        preconditionFailure("RestoreDevelopmentRecordUseCase must be provided.")
    }
}

private enum FetchTodosUseCaseKey: DependencyKey {
    static var liveValue: FetchTodosUseCase {
        preconditionFailure("FetchTodosUseCase must be provided.")
    }
}

private enum UpdateTodoGoalUseCaseKey: DependencyKey {
    static var liveValue: UpdateTodoGoalUseCase {
        preconditionFailure("UpdateTodoGoalUseCase must be provided.")
    }
}
