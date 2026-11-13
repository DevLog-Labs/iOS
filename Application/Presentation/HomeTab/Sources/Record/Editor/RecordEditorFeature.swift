//
//  RecordEditorFeature.swift
//  Development
//
//  Created by opfic on 9/13/26.
//

import Domain
import Foundation
import PresentationShared

@Reducer
struct RecordEditorFeature {
    @ObservableState
    struct State: Equatable {
        @Presents var alert: AlertState<Never>?
        let goalId: String
        let goalTitle: String
        let recordId: String
        let versionId: String
        let baseVersion: DevelopmentRecord.Version?
        var record: DevelopmentRecord?
        var title: String
        var markdownContent: String
        var selectedTab = EditorTab.write
        var isLoading = false
        var result: Result?
        var confirmationPreparation: ConfirmationPreparation?

        var versionNumber: Int {
            (baseVersion?.number ?? record?.currentVersion?.number ?? 0) + 1
        }

        var baseVersionID: String? {
            record?.draft?.baseVersionId ?? baseVersion?.id ?? record?.currentVersion?.id
        }

        var isCorrection: Bool {
            baseVersionID != nil
        }

        var isReadyToSave: Bool {
            !isLoading
                && !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        var canConfirmVersion: Bool {
            isReadyToSave
        }

        init(
            goalId: String,
            goalTitle: String,
            record: DevelopmentRecord? = nil,
            baseVersion: DevelopmentRecord.Version? = nil,
            recordId: String = UUID().uuidString,
            versionId: String = UUID().uuidString
        ) {
            self.goalId = goalId
            self.goalTitle = goalTitle
            self.recordId = record?.id ?? recordId
            self.versionId = versionId
            self.baseVersion = baseVersion
            self.record = record
            self.title = record?.draft?.title ?? baseVersion?.title ?? ""
            self.markdownContent = record?.draft?.markdownContent ?? baseVersion?.markdownContent ?? ""
        }
    }

    enum EditorTab: Equatable {
        case write
        case preview
    }

    enum Result: Equatable {
        case saved(DevelopmentRecord)
        case confirmed(DevelopmentRecord.Version)
    }

    struct ConfirmationPreparation: Equatable {
        let record: DevelopmentRecord
        let title: String
        let markdownContent: String
    }

    enum Action: BindableAction, Equatable {
        case alert(PresentationAction<Never>)
        case binding(BindingAction<State>)
        case view(ViewAction)
        case store(StoreAction)
        case delegate(Delegate)

        enum ViewAction: Equatable {
            case save
            case confirm
        }

        enum StoreAction: Equatable {
            case saved(DevelopmentRecord)
            case preparedForConfirmation(DevelopmentRecord)
            case confirmed(DevelopmentRecord.Version)
            case failed
        }

        enum Delegate: Equatable {
            case saved(DevelopmentRecord)
            case confirmed(DevelopmentRecord.Version)
        }
    }

    @Dependency(\.developmentCreateRecordUseCase) private var createRecordUseCase
    @Dependency(\.developmentSaveRecordDraftUseCase) private var saveRecordDraftUseCase
    @Dependency(\.developmentConfirmRecordUseCase) private var confirmRecordUseCase

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .alert, .binding, .delegate:
                break
            case .view(.save):
                guard state.isReadyToSave else { break }
                state.isLoading = true
                state.result = nil
                state.confirmationPreparation = nil
                return saveEffect(state: state)
            case .view(.confirm):
                guard state.canConfirmVersion else { break }
                state.isLoading = true
                state.result = nil
                if let preparation = state.confirmationPreparation,
                   preparation.title == state.title,
                   preparation.markdownContent == state.markdownContent {
                    return confirmPreparedRecordEffect(
                        goalId: state.goalId,
                        recordId: preparation.record.id,
                        versionId: state.versionId,
                        baseVersionId: state.baseVersionID,
                        draftRevisionId: preparation.record.draft?.revisionId
                    )
                }
                state.confirmationPreparation = nil
                return prepareConfirmationEffect(state: state)
            case .store(.saved(let record)):
                state.record = record
                state.isLoading = false
                state.result = .saved(record)
                state.confirmationPreparation = nil
                return .send(.delegate(.saved(record)))
            case .store(.preparedForConfirmation(let record)):
                state.record = record
                state.confirmationPreparation = ConfirmationPreparation(
                    record: record,
                    title: state.title,
                    markdownContent: state.markdownContent
                )
                return confirmPreparedRecordEffect(
                    goalId: state.goalId,
                    recordId: record.id,
                    versionId: state.versionId,
                    baseVersionId: state.baseVersionID,
                    draftRevisionId: record.draft?.revisionId
                )
            case .store(.confirmed(let version)):
                state.isLoading = false
                state.result = .confirmed(version)
                state.confirmationPreparation = nil
                return .send(.delegate(.confirmed(version)))
            case .store(.failed):
                state.isLoading = false
                state.result = nil
                state.alert = Self.errorAlert
            }

            return .none
        }
        .ifLet(\.$alert, action: \.alert)
    }
}

private extension RecordEditorFeature {
    func saveEffect(state: State) -> Effect<Action> {
        .run { [createRecordUseCase, saveRecordDraftUseCase] send in
            do {
                let record: DevelopmentRecord
                if let recordId = state.record?.id {
                    record = try await saveRecordDraftUseCase.execute(
                        goalId: state.goalId,
                        recordId: recordId,
                        baseVersionId: state.baseVersionID,
                        draftRevisionId: state.record?.draft?.revisionId,
                        content: .init(title: state.title, markdownContent: state.markdownContent)
                    )
                } else {
                    record = try await createRecordUseCase.execute(
                        goalId: state.goalId,
                        recordId: state.recordId,
                        title: state.title,
                        markdownContent: state.markdownContent
                    )
                }
                await send(.store(.saved(record)))
            } catch {
                await send(.store(.failed))
            }
        }
    }

    func prepareConfirmationEffect(state: State) -> Effect<Action> {
        .run { [createRecordUseCase, saveRecordDraftUseCase] send in
            do {
                let record: DevelopmentRecord
                if let recordId = state.record?.id {
                    record = try await saveRecordDraftUseCase.execute(
                        goalId: state.goalId,
                        recordId: recordId,
                        baseVersionId: state.baseVersionID,
                        draftRevisionId: state.record?.draft?.revisionId,
                        content: .init(title: state.title, markdownContent: state.markdownContent)
                    )
                } else {
                    record = try await createRecordUseCase.execute(
                        goalId: state.goalId,
                        recordId: state.recordId,
                        title: state.title,
                        markdownContent: state.markdownContent
                    )
                }
                await send(.store(.preparedForConfirmation(record)))
            } catch {
                await send(.store(.failed))
            }
        }
    }

    func confirmPreparedRecordEffect(
        goalId: String,
        recordId: String,
        versionId: String,
        baseVersionId: String?,
        draftRevisionId: String?
    ) -> Effect<Action> {
        .run { [confirmRecordUseCase] send in
            do {
                let version = try await confirmRecordUseCase.execute(
                    goalId: goalId,
                    recordId: recordId,
                    versionId: versionId,
                    baseVersionId: baseVersionId,
                    draftRevisionId: draftRevisionId
                )
                await send(.store(.confirmed(version)))
            } catch {
                await send(.store(.failed))
            }
        }
    }

    static var errorAlert: AlertState<Never> {
        AlertState {
            TextState(String(localized: "common_error_title", bundle: PresentationResources.bundle))
        } actions: {
            ButtonState(role: .cancel) {
                TextState(String(localized: "common_close", bundle: PresentationResources.bundle))
            }
        } message: {
            TextState(String(
                localized: "development_record_editor_error_message",
                bundle: PresentationResources.bundle
            ))
        }
    }
}
