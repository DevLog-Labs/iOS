//
//  RecordDetailFeature.swift
//  Development
//
//  Created by opfic on 9/13/26.
//

import Domain
import PresentationShared

@Reducer
struct RecordDetailFeature {
    @ObservableState
    struct State: Equatable {
        @Presents var alert: AlertState<Action.Alert>?
        @Presents var editor: RecordEditorDestination?
        @Presents var history: RecordHistoryDestination?
        @Presents var versionDetail: RecordVersionDetailDestination?
        let goalTitle: String
        let allowsMutation: Bool
        var record: DevelopmentRecord
        var versions = [DevelopmentRecord.Version]()
        var contentState: ContentState
        var currentVersionID: String?
        var isRestoring = false
        var restoreRequest: RestoreRequest?
        var restoredSourceVersionID: String?
        // 좁은 창의 전체 화면과 넓은 창의 시트가 같은 정정 상태를 그려 창 폭이 바뀌어도 작성 중인 정정 유지
        // 창 폭이 바뀌어 표시가 잠깐 닫혀도 진행 중인 저장·확정을 잃지 않도록 표시 상태와 따로 보관
        var editorContent: RecordEditorFeature.State?
        // 개발 목표와 기록 상세, 버전 이력 화면이 나타난 자리
        // 창 폭이 바뀌면 새 자리에 나타난 뒤에 안에서 연 화면을 다시 띄우고, 개발 목표가 먼저 옮겨 가면 빠지는 자리의 닫힘을 거름
        var goalShownOnDesktop: Bool?
        var shownOnDesktop: Bool?
        var historyShownOnDesktop: Bool?
        // 창 폭이 바뀌어 빠지는 자리가 먼저 닫은 화면, 같은 차례에 새 자리가 나타나면 되살림
        var dismissedEditor: RecordEditorDestination?
        var dismissedHistory: RecordHistoryDestination?
        var dismissedVersionDetail: RecordVersionDetailDestination?

        var isLoading: Bool {
            contentState == .idle || contentState == .loading
        }

        var currentVersion: DevelopmentRecord.Version? {
            versions.first { $0.id == currentVersionID }
        }

        init(
            goalTitle: String,
            record: DevelopmentRecord,
            allowsMutation: Bool = true
        ) {
            self.goalTitle = goalTitle
            self.allowsMutation = allowsMutation
            self.record = record
            self.currentVersionID = record.currentVersion?.id
            if record.currentVersion == nil, let draft = record.draft {
                self.contentState = .draft(draft)
            } else {
                self.contentState = .idle
            }
        }

        mutating func restoreDismissedScreens() {
            editor = editor ?? dismissedEditor
            history = history ?? dismissedHistory
            versionDetail = versionDetail ?? dismissedVersionDetail
        }
    }

    enum ContentState: Equatable {
        case idle
        case loading
        case draft(DevelopmentRecord.Draft)
        case loaded
        case failed
    }

    struct RestoreRequest: Equatable {
        let versionID: String
        let sourceVersionID: String
    }

    enum Action: Equatable {
        case alert(PresentationAction<Alert>)
        case editor(PresentationAction<Never>)
        case editorContent(RecordEditorFeature.Action)
        case history(PresentationAction<Never>)
        case versionDetail(PresentationAction<Never>)
        case view(ViewAction)
        case store(StoreAction)

        enum Alert: Equatable {
            case confirmRestore(DevelopmentRecord.Version)
        }

        enum ViewAction: Equatable {
            case appear(onDesktop: Bool)
            case appearHistory(onDesktop: Bool)
            case fetch
            case finishEditing
            case restore(DevelopmentRecord.Version)
            case selectVersion(DevelopmentRecord.Version)
            case tapCorrection
            case tapHistory
        }

        enum StoreAction: Equatable {
            case loaded(DevelopmentRecord, [DevelopmentRecord.Version])
            case restored(DevelopmentRecord.Version)
            case loadFailed
            case restoreFailed
            case screensDismissed
        }
    }

    @Dependency(\.developmentFetchRecordsUseCase) private var fetchRecordsUseCase
    @Dependency(\.developmentFetchRecordHistoryUseCase) private var fetchRecordHistoryUseCase
    @Dependency(\.developmentRestoreRecordUseCase) private var restoreRecordUseCase
    @Dependency(\.uuid) private var uuid

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .alert(.presented(.confirmRestore(let version))):
                state.alert = nil
                guard !state.isRestoring,
                      state.allowsMutation,
                      state.record.draft == nil,
                      version.id != state.currentVersionID else { break }
                let request = state.restoreRequest?.sourceVersionID == version.id
                    ? state.restoreRequest
                    : RestoreRequest(
                        versionID: uuid().uuidString,
                        sourceVersionID: version.id
                    )
                guard let request else { break }
                state.isRestoring = true
                state.restoreRequest = request
                state.restoredSourceVersionID = nil
                return restoreEffect(
                    goalID: state.record.goalId,
                    recordID: state.record.id,
                    request: request
                )
            case .alert:
                break
            case .editor(.dismiss):
                state.dismissedEditor = state.editor
                state.editor = nil
                return .run { send in
                    await send(.store(.screensDismissed))
                }
            case .editor, .editorContent:
                break
            case .history(.dismiss):
                state.dismissedHistory = state.history
                state.dismissedVersionDetail = state.versionDetail ?? state.dismissedVersionDetail
                state.history = nil
                state.versionDetail = nil
                return .run { send in
                    await send(.store(.screensDismissed))
                }
            case .history:
                break
            case .versionDetail(.dismiss):
                state.dismissedVersionDetail = state.versionDetail
                state.versionDetail = nil
                return .run { send in
                    await send(.store(.screensDismissed))
                }
            case .versionDetail:
                break
            case .view(.appear(let onDesktop)):
                // 빠지는 자리의 화면이 닫히는 중에 다시 나타나며 보내는 동작은 거름
                guard onDesktop == state.goalShownOnDesktop else { break }
                if state.shownOnDesktop != onDesktop {
                    state.restoreDismissedScreens()
                }
                state.shownOnDesktop = onDesktop
                // 창 폭이 바뀌어 새 자리에 나타날 때는 다시 조회하지 않음
                guard state.contentState == .idle else { break }
                return .send(.view(.fetch))
            case .view(.appearHistory(let onDesktop)):
                guard onDesktop == state.goalShownOnDesktop else { break }
                state.historyShownOnDesktop = onDesktop
            case .view(.fetch):
                guard state.contentState != .loading,
                      !state.isRestoring,
                      state.record.currentVersion != nil else { break }
                state.alert = nil
                state.contentState = .loading
                state.restoredSourceVersionID = nil
                return fetchEffect(goalID: state.record.goalId, recordID: state.record.id)
            case .view(.finishEditing):
                state.editor = nil
                // 닫히는 정정 화면이 정정 상태를 그리는 동안은 남겨 두고 다음 차례에 비움
                return .merge(
                    .send(.view(.fetch)),
                    .run { send in
                        await send(.store(.screensDismissed))
                    }
                )
            case .view(.restore(let version)):
                guard !state.isRestoring,
                      state.allowsMutation,
                      state.record.draft == nil,
                      version.id != state.currentVersionID else { break }
                state.alert = Self.restoreConfirmationAlert(version)
            case .view(.selectVersion(let version)):
                guard version.id != state.currentVersionID,
                      state.versions.contains(where: { $0.id == version.id }) else { break }
                state.versionDetail = RecordVersionDetailDestination(version: version)
            case .view(.tapCorrection):
                guard state.allowsMutation,
                      state.contentState == .loaded,
                      state.currentVersion != nil else { break }
                let content = RecordEditorFeature.State(
                    goalId: state.record.goalId,
                    goalTitle: state.goalTitle,
                    record: state.record,
                    baseVersion: state.currentVersion,
                    versionId: uuid().uuidString
                )
                state.editorContent = content
                state.editor = RecordEditorDestination(versionID: content.versionId)
            case .view(.tapHistory):
                guard state.contentState == .loaded,
                      state.currentVersion != nil else { break }
                state.history = RecordHistoryDestination(recordID: state.record.id)
            case .store(.loaded(let record, let versions)):
                state.record = record
                state.versions = versions.sorted { $0.number < $1.number }
                state.currentVersionID = record.currentVersion?.id
                state.restoreRequest = nil
                state.contentState = .loaded
            case .store(.restored(let version)):
                if !state.versions.contains(where: { $0.id == version.id }) {
                    state.versions.append(version)
                    state.versions.sort { $0.number < $1.number }
                }
                state.currentVersionID = version.id
                state.restoredSourceVersionID = state.restoreRequest?.sourceVersionID
                state.restoreRequest = nil
                state.isRestoring = false
                state.contentState = .loaded
            case .store(.loadFailed):
                state.contentState = .failed
                state.alert = Self.errorAlert
            case .store(.restoreFailed):
                state.isRestoring = false
                state.alert = Self.restoreErrorAlert
            case .store(.screensDismissed):
                state.dismissedEditor = nil
                state.dismissedHistory = nil
                state.dismissedVersionDetail = nil
                if state.editor == nil {
                    state.editorContent = nil
                }
            }

            return .none
        }
        .ifLet(\.$alert, action: \.alert)
        .ifLet(\.editorContent, action: \.editorContent) {
            RecordEditorFeature()
        }
    }
}

@ObservableState
struct RecordEditorDestination: Equatable, Identifiable {
    let versionID: String
    var id: String { versionID }
}

@ObservableState
struct RecordHistoryDestination: Equatable, Identifiable {
    let recordID: String
    var id: String { recordID }
}

@ObservableState
struct RecordVersionDetailDestination: Equatable, Identifiable {
    let version: DevelopmentRecord.Version
    var id: String { version.id }
}

private extension RecordDetailFeature {
    func fetchEffect(goalID: String, recordID: String) -> Effect<Action> {
        .run { [fetchRecordsUseCase, fetchRecordHistoryUseCase] send in
            do {
                async let recordValues = fetchRecordsUseCase.execute(goalId: goalID)
                async let versionValues = fetchRecordHistoryUseCase.execute(
                    goalId: goalID,
                    recordId: recordID
                )
                let (records, versions) = try await (recordValues, versionValues)
                guard let record = records.first(where: { $0.id == recordID }),
                      let currentVersion = record.currentVersion,
                      versions.contains(where: { $0.id == currentVersion.id }) else {
                    throw DomainLayerError.developmentRecordVersionNotFound
                }
                await send(.store(.loaded(record, versions)))
            } catch {
                await send(.store(.loadFailed))
            }
        }
    }

    func restoreEffect(
        goalID: String,
        recordID: String,
        request: RestoreRequest
    ) -> Effect<Action> {
        .run { [restoreRecordUseCase] send in
            do {
                let version = try await restoreRecordUseCase.execute(
                    goalId: goalID,
                    recordId: recordID,
                    versionId: request.versionID,
                    sourceVersionId: request.sourceVersionID
                )
                await send(.store(.restored(version)))
            } catch {
                await send(.store(.restoreFailed))
            }
        }
    }

    static var errorAlert: AlertState<Action.Alert> {
        AlertState {
            TextState(String(localized: "common_error_title", bundle: PresentationResources.bundle))
        } actions: {
            ButtonState(role: .cancel) {
                TextState(String(localized: "common_close", bundle: PresentationResources.bundle))
            }
        } message: {
            TextState(String(
                localized: "development_record_detail_error_message",
                bundle: PresentationResources.bundle
            ))
        }
    }

    static var restoreErrorAlert: AlertState<Action.Alert> {
        AlertState {
            TextState(String(localized: "common_error_title", bundle: PresentationResources.bundle))
        } actions: {
            ButtonState(role: .cancel) {
                TextState(String(localized: "common_close", bundle: PresentationResources.bundle))
            }
        } message: {
            TextState(String(
                localized: "development_record_restore_error_message",
                bundle: PresentationResources.bundle
            ))
        }
    }
}

extension RecordDetailFeature {
    static func restoreConfirmationAlert(
        _ version: DevelopmentRecord.Version
    ) -> AlertState<Action.Alert> {
        AlertState {
            TextState(String(
                localized: "development_record_restore_alert_title",
                bundle: PresentationResources.bundle
            ))
        } actions: {
            ButtonState(role: .cancel) {
                TextState(String(localized: "common_cancel", bundle: PresentationResources.bundle))
            }
            ButtonState(action: .confirmRestore(version)) {
                TextState(String(
                    localized: "development_record_restore_alert_confirm",
                    bundle: PresentationResources.bundle
                ))
            }
        } message: {
            TextState(String.localizedStringWithFormat(
                String(
                    localized: "development_record_restore_alert_message_format",
                    bundle: PresentationResources.bundle
                ),
                RecordPresentation.versionLabel(version.number)
            ))
        }
    }
}
