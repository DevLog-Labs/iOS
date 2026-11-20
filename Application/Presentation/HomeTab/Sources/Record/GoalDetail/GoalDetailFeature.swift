//
//  GoalDetailFeature.swift
//  Development
//
//  Created by opfic on 9/13/26.
//

import Core
import Domain
import Foundation
import PresentationShared

struct RecordTimelineItem: Equatable, Identifiable {
    let record: DevelopmentRecord
    let currentVersion: DevelopmentRecord.Version?

    var id: String { record.id }
    var title: String { record.draft?.title ?? currentVersion?.title ?? "" }
    var hasDraft: Bool { record.draft != nil }
    var isUnconfirmed: Bool { currentVersion == nil }
    var versionNumber: Int? { hasDraft ? nil : currentVersion?.number }
    var date: Date { record.draft?.updatedAt ?? currentVersion?.confirmedAt ?? record.createdAt }
}

@Reducer
struct GoalDetailFeature {
    @ObservableState
    struct State: Equatable {
        @Presents var alert: AlertState<Action.Alert>?
        // 넓은 창의 칸과 시트가 같은 상태를 그려 창 폭이 바뀌어도 작성 중인 기록 유지
        @Presents var recordEditor: RecordEditorFeature.State?
        @Presents var recordDetail: RecordDetailDestination?
        @Presents var todoDetail: TodoDetailDestination?
        @Presents var todoLinkSheet: GoalTodoLinkFeature.State?
        // 창 폭이 바뀌어 기록 상세 표시가 잠깐 닫혀도 진행 중인 조회·되돌리기와 안에서 연 화면을 잃지 않도록 따로 보관하는 상세 상태
        var recordDetailContent: RecordDetailFeature.State?
        let goalId: String
        var goal: DevelopmentGoal?
        var updatedGoalStatus: DevelopmentGoal.Status?
        var items = [RecordTimelineItem]()
        var todos = [Todo]()
        var linkedTodos = [Todo]()
        var isLoading = false
        var isTodoLoading = false
        var isTransitioning = false
        var hasLoaded = false
        var hasLoadedTodos = false
        var hasLoadFailure = false
        var hasTodoLoadFailure = false
        // 개발 목표 화면이 나타난 자리, 창 폭이 바뀌면 새 자리에 나타난 뒤에 기록 상세를 다시 띄움
        var shownOnDesktop: Bool?
        // 창 폭이 바뀌어 빠지는 자리가 먼저 닫은 기록 상세, 같은 차례에 새 자리가 나타나면 되살림
        var dismissedRecordDetail: RecordDetailDestination?

        var goalTitle: String {
            goal?.title ?? ""
        }

        var goalStatus: DevelopmentGoal.Status? {
            updatedGoalStatus ?? goal?.status
        }

        var allowsRecordMutation: Bool {
            goalStatus == .inProgress
        }

        var allowsTodoLinkMutation: Bool {
            goalStatus == .inProgress
        }

        init(goalId: String) {
            self.goalId = goalId
        }
    }

    enum Action: BindableAction, Equatable {
        case alert(PresentationAction<Alert>)
        case recordEditor(PresentationAction<RecordEditorFeature.Action>)
        case recordDetail(PresentationAction<Never>)
        case recordDetailContent(RecordDetailFeature.Action)
        case todoDetail(PresentationAction<Never>)
        case todoLinkSheet(PresentationAction<GoalTodoLinkFeature.Action>)
        case binding(BindingAction<State>)
        case view(ViewAction)
        case store(StoreAction)

        enum Alert: Equatable {
            case confirmTransition(DevelopmentGoal.Status)
        }

        enum ViewAction: Equatable {
            case addRecord
            case appear(onDesktop: Bool)
            case continueRecord
            case fetch
            case manageTodos
            case refresh
            case retryTodos
            // 개발 목표 위에 쌓아 연 기록, Todo 상세를 닫고 개발 목표 첫 화면으로 돌아감
            case returnToGoal
            case selectRecord(RecordTimelineItem)
            case selectTodo(String)
            case selectStatus(DevelopmentGoal.Status)
        }

        enum StoreAction: Equatable {
            case loaded(goal: DevelopmentGoal, items: [RecordTimelineItem])
            case loadedTodos([Todo])
            case transitioned(DevelopmentGoal.Status)
            case failed
            case todosFailed
            case transitionFailed
            case recordDetailDismissed
        }
    }

    @Dependency(\.developmentFetchGoalUseCase) private var fetchGoalUseCase
    @Dependency(\.developmentFetchRecordsUseCase) private var fetchRecordsUseCase
    @Dependency(\.developmentFetchRecordVersionUseCase) private var fetchRecordVersionUseCase
    @Dependency(\.developmentFetchTodosUseCase) private var fetchTodosUseCase
    @Dependency(\.developmentUpdateGoalStatusUseCase) private var updateGoalStatusUseCase
    @Dependency(\.uuid) private var uuid

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .alert(.presented(.confirmTransition(let status))):
                guard !state.isTransitioning else { break }
                state.alert = nil
                state.isTransitioning = true
                return transitionEffect(goalId: state.goalId, status: status)
            case .alert:
                break
            case .recordEditor(.dismiss):
                state.recordEditor = nil
            case .recordEditor:
                break
            case .recordDetail(.dismiss):
                state.dismissedRecordDetail = state.recordDetail
                state.recordDetail = nil
                return .run { send in
                    await send(.store(.recordDetailDismissed))
                }
            case .recordDetail, .recordDetailContent:
                break
            case .todoDetail(.dismiss):
                state.todoDetail = nil
            case .todoDetail:
                break
            case .todoLinkSheet(.dismiss),
                 .todoLinkSheet(.presented(.delegate(.close))):
                state.todoLinkSheet = nil
            case .todoLinkSheet(.presented(.delegate(.saved(let todos)))):
                state.todos = todos
                state.linkedTodos = todos.filter { $0.goalId == state.goalId }
                state.todoLinkSheet = nil
            case .todoLinkSheet:
                break
            case .binding:
                break
            case .view(.addRecord):
                guard state.hasLoaded,
                      state.allowsRecordMutation,
                      !state.isLoading,
                      !state.isTransitioning,
                      state.recordEditor == nil else { break }
                state.recordEditor = RecordEditorFeature.State(
                    goalId: state.goalId,
                    goalTitle: state.goalTitle,
                    recordId: uuid().uuidString,
                    versionId: uuid().uuidString
                )
            case .view(.appear(let onDesktop)):
                if state.shownOnDesktop != onDesktop {
                    if state.recordDetail == nil {
                        state.recordDetail = state.dismissedRecordDetail
                    }
                    state.recordDetailContent?.restoreDismissedScreens()
                }
                state.shownOnDesktop = onDesktop
                state.recordDetailContent?.goalShownOnDesktop = onDesktop
            case .view(.continueRecord):
                guard state.hasLoaded,
                      state.allowsRecordMutation,
                      !state.isLoading,
                      !state.isTransitioning,
                      state.recordEditor == nil,
                      let record = state.items.first(where: \.hasDraft)?.record else { break }
                state.recordEditor = RecordEditorFeature.State(
                    goalId: state.goalId,
                    goalTitle: state.goalTitle,
                    record: record,
                    versionId: uuid().uuidString
                )
            case .view(.fetch):
                guard !state.hasLoaded, !state.isLoading else { break }
                state.isLoading = true
                state.hasLoadFailure = false
                state.isTodoLoading = true
                state.hasTodoLoadFailure = false
                return .concatenate(
                    fetchEffect(goalId: state.goalId),
                    fetchTodosEffect()
                )
            case .view(.manageTodos):
                guard state.hasLoadedTodos,
                      state.allowsTodoLinkMutation,
                      !state.isTodoLoading,
                      state.todoLinkSheet == nil else { break }
                state.todoLinkSheet = GoalTodoLinkFeature.State(
                    goalId: state.goalId,
                    todos: state.todos
                )
            case .view(.refresh):
                guard !state.isLoading else { break }
                state.isLoading = true
                state.hasLoadFailure = false
                state.isTodoLoading = true
                state.hasTodoLoadFailure = false
                return .concatenate(
                    fetchEffect(goalId: state.goalId),
                    fetchTodosEffect()
                )
            case .view(.retryTodos):
                guard !state.isTodoLoading else { break }
                state.isTodoLoading = true
                state.hasTodoLoadFailure = false
                return fetchTodosEffect()
            case .view(.selectRecord(let item)):
                guard state.recordEditor == nil,
                      state.recordDetail == nil else { break }
                if item.hasDraft, state.allowsRecordMutation {
                    state.recordEditor = RecordEditorFeature.State(
                        goalId: state.goalId,
                        goalTitle: state.goalTitle,
                        record: item.record,
                        versionId: uuid().uuidString
                    )
                } else {
                    state.recordDetail = RecordDetailDestination(record: item.record)
                    var content = RecordDetailFeature.State(
                        goalTitle: state.goalTitle,
                        record: item.record,
                        allowsMutation: state.allowsRecordMutation
                    )
                    content.goalShownOnDesktop = state.shownOnDesktop
                    state.recordDetailContent = content
                }
            case .view(.returnToGoal):
                state.recordDetail = nil
                state.todoDetail = nil
                // 내려가는 기록 상세 안 화면의 닫힘을 처리한 다음 차례에 상세 상태를 비움
                return .run { send in
                    await send(.store(.recordDetailDismissed))
                }
            case .view(.selectTodo(let todoId)):
                guard state.linkedTodos.contains(where: { $0.id == todoId }),
                      state.todoDetail == nil else { break }
                state.todoDetail = TodoDetailDestination(todoId: todoId)
            case .view(.selectStatus(let status)):
                guard let goalStatus = state.goalStatus,
                      !state.isLoading,
                      !state.isTransitioning,
                      Self.canTransition(from: goalStatus, to: status) else { break }
                if status == .completed,
                   let alert = Self.completionBlockingAlert(items: state.items) {
                    state.alert = alert
                } else {
                    state.alert = Self.transitionConfirmationAlert(status)
                }
            case .store(.loaded(let goal, let items)):
                state.goal = goal
                state.updatedGoalStatus = nil
                state.items = items
                state.isLoading = false
                state.hasLoaded = true
                state.hasLoadFailure = false
            case .store(.loadedTodos(let todos)):
                state.todos = todos
                state.linkedTodos = todos.filter { $0.goalId == state.goalId }
                state.isTodoLoading = false
                state.hasLoadedTodos = true
                state.hasTodoLoadFailure = false
            case .store(.transitioned(let status)):
                state.updatedGoalStatus = status
                state.isTransitioning = false
            case .store(.failed):
                state.isLoading = false
                state.hasLoadFailure = true
                state.alert = Self.errorAlert
            case .store(.todosFailed):
                state.isTodoLoading = false
                state.hasTodoLoadFailure = true
            case .store(.transitionFailed):
                state.isTransitioning = false
                state.alert = Self.transitionErrorAlert
            case .store(.recordDetailDismissed):
                state.dismissedRecordDetail = nil
                if state.recordDetail == nil {
                    state.recordDetailContent = nil
                }
            }

            return .none
        }
        .ifLet(\.$alert, action: \.alert)
        .ifLet(\.$recordEditor, action: \.recordEditor) {
            RecordEditorFeature()
        }
        .ifLet(\.recordDetailContent, action: \.recordDetailContent) {
            RecordDetailFeature()
        }
        .ifLet(\.$todoLinkSheet, action: \.todoLinkSheet) {
            GoalTodoLinkFeature()
        }
    }
}

extension GoalDetailFeature {
    func fetchEffect(goalId: String) -> Effect<Action> {
        .run { [fetchGoalUseCase, fetchRecordsUseCase, fetchRecordVersionUseCase] send in
            do {
                let goal = try await fetchGoalUseCase.execute(goalId)
                let records = try await fetchRecordsUseCase.execute(goalId: goalId)
                let sortedRecords = records.sorted(by: Self.precedes)
                var currentVersions = [DevelopmentRecord.Version?](
                    repeating: nil,
                    count: sortedRecords.count
                )

                try await withThrowingTaskGroup(
                    of: (Int, DevelopmentRecord.Version).self
                ) { group in
                    for (index, record) in sortedRecords.enumerated() {
                        guard let reference = record.currentVersion else { continue }
                        group.addTask {
                            let version = try await fetchRecordVersionUseCase.execute(
                                goalId: goalId,
                                recordId: record.id,
                                versionId: reference.id
                            )
                            return (index, version)
                        }
                    }

                    for try await (index, version) in group {
                        currentVersions[index] = version
                    }
                }

                let items = zip(sortedRecords, currentVersions).map { record, version in
                    RecordTimelineItem(
                        record: record,
                        currentVersion: version
                    )
                }

                await send(.store(.loaded(goal: goal, items: items)))
            } catch {
                await send(.store(.failed))
            }
        }
    }

    func transitionEffect(
        goalId: String,
        status: DevelopmentGoal.Status
    ) -> Effect<Action> {
        .run { [updateGoalStatusUseCase] send in
            do {
                try await updateGoalStatusUseCase.execute(goalId, to: status)
                await send(.store(.transitioned(status)))
            } catch {
                await send(.store(.transitionFailed))
            }
        }
    }

    func fetchTodosEffect() -> Effect<Action> {
        .run { [fetchTodosUseCase] send in
            do {
                let page = try await fetchTodosUseCase.execute(
                    TodoQuery(
                        sortTarget: .updatedAt,
                        sortOrder: .latest,
                        pageSize: 100,
                        fetchAllPages: true
                    ),
                    cursor: nil
                )
                await send(.store(.loadedTodos(page.items)))
            } catch {
                await send(.store(.todosFailed))
            }
        }
    }

}

@ObservableState
struct RecordDetailDestination: Equatable, Identifiable {
    var id: String { record.id }
    let record: DevelopmentRecord
}

@ObservableState
struct TodoDetailDestination: Equatable, Identifiable {
    var id: String { todoId }
    let todoId: String
}
