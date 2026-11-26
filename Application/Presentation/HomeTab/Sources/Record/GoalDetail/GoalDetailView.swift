//
//  GoalDetailView.swift
//  Development
//
//  Created by opfic on 9/13/26.
//

import SwiftUI
import Domain
import PresentationShared

public struct GoalDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.deviceType) private var deviceType
    @Environment(\.usesDesktopLayout) private var usesDesktopLayout
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
    @Bindable var store: StoreOf<GoalDetailFeature>

    public var body: some View {
        // 좁은 창은 홈 내비게이션에 쌓고, 사이드바가 있으면 홈 내비게이션 안의 칸으로 표시
        presentedContent
            .overlay {
                if store.isTransitioning {
                    LoadingView()
                }
            }
    }

    private var mainContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                header
                GoalLinkedTodoCard(
                    todos: store.linkedTodos,
                    isLoading: store.isTodoLoading,
                    hasLoadFailure: store.hasTodoLoadFailure,
                    allowsManagement: store.hasLoaded && store.allowsTodoLinkMutation,
                    onManage: { store.send(.view(.manageTodos)) },
                    onRetry: { store.send(.view(.retryTodos)) },
                    onSelect: { store.send(.view(.selectTodo($0))) }
                )
                recordSection
                recordActionButton
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) { topBar }
        .background(Color.background.ignoresSafeArea())
        .duoToolbarVisibility(showsBackButton: true)
        .onAppear { store.send(.view(.fetch)) }
        .prominentAlert(store, state: \.alert, action: \.alert)
    }

    private var presentedContent: some View {
        // 창 폭이 바뀌면 개발 목표가 새 자리에 나타난 뒤에 기록 상세를 띄워 같은 갱신에서 겹쳐 쌓지 않음
        // 지금 값으로 다시 그리고, 새 자리가 먼저 나타난 뒤 빠지는 자리에서 늦게 들어온 닫힘은 읽을 때의 값으로 거름
        let isShown = store.shownOnDesktop == usesDesktopLayout
        let isHidden = { !isShown || store.shownOnDesktop != usesDesktopLayout }

        // 사이드바가 있으면 개발 목표 수정과 기록 작성을 개발 목표 오른쪽 칸에 표시
        return PaneSplitView(splitsOnDesktop: store.goalEdit != nil || store.recordEditor != nil) {
            mainContent
        } detail: {
            if let editStore = store.scope(state: \.goalEdit, action: \.goalEdit.presented) {
                GoalCreateView(store: editStore)
            } else if let editorStore = store.scope(state: \.recordEditor, action: \.recordEditor.presented) {
                RecordEditorView(
                    store: editorStore,
                    onCompletion: {
                        store.send(.view(.refresh))
                    },
                    onClose: {
                        store.send(.recordEditor(.dismiss))
                    }
                )
            }
        }
        // 좁은 창은 닫기·저장·확정 버튼으로만 닫는 전체 화면
        // 넓은 창으로 바뀌어 칸에 옮겨 그린 뒤 늦게 닫히는 전체 화면은 작성 중인 기록을 지우지 않음
        .fullScreenCover(
            item: $store.scope(state: \.recordEditor, action: \.recordEditor)
                .hiddenInPane { usesDesktopLayout || store.shownOnDesktop == true }
        ) { editorStore in
            RecordEditorView(
                store: editorStore,
                onCompletion: {
                    store.send(.view(.refresh))
                }
            )
        }
        .prominentSheet(item: $store.scope(state: \.todoLinkSheet, action: \.todoLinkSheet)) {
            GoalTodoLinkSheet(store: $0)
        }
        // 좁은 창은 새 개발 목표와 같은 시트로 수정하고 닫기, 저장 버튼으로만 닫음
        .prominentSheet(
            item: $store.scope(state: \.goalEdit, action: \.goalEdit)
                .hiddenInPane { usesDesktopLayout || store.shownOnDesktop == true }
        ) {
            GoalCreateView(store: $0)
        }
        .navigationDestination(
            item: $store.scope(state: \.recordDetail, action: \.recordDetail)
                .hiddenInPane { usesDesktopLayout || isHidden() },
            interactivePop: true
        ) { _ in
            if let detailStore = store.scope(state: \.recordDetailContent, action: \.recordDetailContent) {
                RecordDetailView(store: detailStore, onUpdate: { store.send(.view(.refresh)) })
            }
        }
        // 사이드바가 있는 창은 기록을 사이드바까지 덮는 상세 판으로 열고 버전 이력은 판 안에서 이동
        .detailPanel(
            item: $store.scope(state: \.recordDetail, action: \.recordDetail)
                .hiddenInPane { !usesDesktopLayout || isHidden() }
        ) { _ in
            NavigationStack {
                if let detailStore = store.scope(state: \.recordDetailContent, action: \.recordDetailContent) {
                    RecordDetailView(store: detailStore, onUpdate: { store.send(.view(.refresh)) })
                }
            }
            .desktopNavigationTransition()
        }
        .navigationDestination(
            item: $store.scope(state: \.todoDetail, action: \.todoDetail),
            interactivePop: true
        ) {
            // 사이드바가 있으면 Todo 목록 옆 칸의 상세와 같은 칸 모양으로 표시하고 뒤로 가면 개발 목표로 돌아감
            TodoDetailView(
                store: Store(
                    initialState: TodoDetailFeature.State(
                        todoId: $0.todoId,
                        showEditButton: false
                    )
                ) {
                    TodoDetailFeature()
                },
                showsBackOnDesktop: true
            )
            .environment(\.showsPaneTitleBar, usesDesktopLayout)
            .detailSideBarTarget(.todo(id: $0.todoId, isEditable: false))
        }
        .onAppear { store.send(.view(.appear(onDesktop: usesDesktopLayout))) }
    }

    @ViewBuilder
    private var topBar: some View {
        if usesDesktopLayout {
            PaneTitleBar(Text(RecordPresentation.text("development_goal_title"))) {
                statusMenu
            }
        } else {
            // Duo는 뒤로 버튼을 오른쪽 세로 막대에 표시
            // 상태 메뉴는 버튼 자리에 맞춰 직접 그리는 메뉴라 세로 막대에 넣지 않고 제목 줄에 표시
            RecordTopBar(RecordPresentation.text("development_goal_title")) {
                if deviceType != .duo {
                    NavigationBackButton(action: { dismiss() })
                        .disabled(store.isTransitioning)
                }
            } trailing: {
                statusMenu
            }
        }
    }

    // 상태 항목 아래 구분선 뒤에 수정
    // 제목 줄 오른쪽 끝 버튼이라 메뉴 오른쪽 끝을 버튼 오른쪽 끝에 맞춤
    @ViewBuilder
    private var statusMenu: some View {
        if let status = store.goalStatus {
            DropdownMenu(alignment: .trailing, sections: menuSections(status)) {
                Image(systemName: "ellipsis")
                    .topBarButtonStyle()
            }
            .disabled(store.isLoading || store.isTransitioning)
        }
    }

    // "개발 목표" 표시와 상태 배지, 큰 제목, 설명
    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text(RecordPresentation.text("development_goal_title"))
                    .font(.adaptive(.footnote))
                    .foregroundStyle(Color.secondaryLabel)
                if let status = store.goalStatus {
                    GoalStatusBadge(status: status)
                }
            }

            Text(store.goalTitle)
                .font(.system(size: isiOSAppOnMac ? 19 * AdaptiveSize.boardScale : 26, weight: .heavy))
                .foregroundStyle(Color.label)
                .padding(.top, 8)
                .padding(.bottom, 6)

            if !store.hasLoaded && store.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            } else if let description = store.goal?.description, !description.isEmpty {
                // 마크다운 없이 쓴 그대로 표시
                Text(description)
                    .font(.adaptive(isiOSAppOnMac ? .body : .subheadline))
                    .foregroundStyle(Color.secondaryLabel)
                    .lineSpacing(6 * AdaptiveSize.boardScale)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, isiOSAppOnMac ? 14 * AdaptiveSize.boardScale : 18)
        .padding(.horizontal, isiOSAppOnMac ? 14 * AdaptiveSize.boardScale : 16)
        .padding(.bottom, isiOSAppOnMac ? 8 * AdaptiveSize.boardScale : 12)
    }

    private var recordSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HomeSectionHeader {
                Text(RecordPresentation.text("development_record_list_title"))
                if store.hasLoaded {
                    Text(verbatim: "\(store.items.count)")
                        .fontWeight(.medium)
                        .foregroundStyle(Color.secondaryLabel)
                }
            } trailing: {
                EmptyView()
            }

            if !store.hasLoaded, store.hasLoadFailure {
                EmptyStateView(
                    RecordPresentation.text("common_error_title"),
                    systemImage: "exclamationmark.triangle",
                    message: RecordPresentation.text("development_record_timeline_error_message")
                ) {
                    Button {
                        store.send(.view(.refresh))
                    } label: {
                        Text(RecordPresentation.text("development_record_timeline_retry"))
                    }
                    .buttonStyle(RecordButtonStyle())
                }
            } else if !store.hasLoaded || store.isLoading, store.items.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
            } else if store.items.isEmpty {
                EmptyStateView(
                    RecordPresentation.text("development_record_empty_title"),
                    systemImage: "doc.badge.plus",
                    message: RecordPresentation.text("development_record_empty_message")
                )
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(store.items) { item in
                        RecordRow(item: item) {
                            store.send(.view(.selectRecord(item)))
                        }
                    }
                }
            }
        }
    }

    // 작성 중인 기록이 있으면 이어서 작성, 없으면 새 기록 추가
    // 좁은 창은 칸 폭을 채우고 넓은 창은 글자 폭
    @ViewBuilder
    private var recordActionButton: some View {
        if store.hasLoaded, store.allowsRecordMutation {
            let hasDraft = store.items.contains(where: \.hasDraft)

            Button {
                store.send(.view(hasDraft ? .continueRecord : .addRecord))
            } label: {
                RecordButtonLabel(RecordPresentation.text(hasDraft ? "development_record_continue" : "development_record_add"))
            }
            .buttonStyle(RecordButtonStyle(fillsWidth: !usesDesktopLayout))
            .disabled(store.isLoading || store.isTransitioning)
            .padding(.vertical, isiOSAppOnMac ? 12 * AdaptiveSize.boardScale : 16)
            .padding(.horizontal, isiOSAppOnMac ? 14 * AdaptiveSize.boardScale : 16)
        }
    }

    private func menuSections(_ status: DevelopmentGoal.Status) -> [DropdownMenuSection] {
        let statusItems = switch status {
        case .inProgress:
            [
                DropdownMenuItem(
                    RecordPresentation.text("development_goal_complete"),
                    systemImage: "checkmark.circle"
                ) {
                    store.send(.view(.selectStatus(.completed)))
                },
                DropdownMenuItem(
                    RecordPresentation.text("development_goal_archive"),
                    systemImage: "archivebox"
                ) {
                    store.send(.view(.selectStatus(.archived)))
                }
            ]
        case .completed, .archived:
            [
                DropdownMenuItem(
                    RecordPresentation.text("development_goal_resume"),
                    systemImage: "arrow.counterclockwise"
                ) {
                    store.send(.view(.selectStatus(.inProgress)))
                }
            ]
        }

        return [
            DropdownMenuSection(items: statusItems),
            DropdownMenuSection(items: [
                DropdownMenuItem(
                    RecordPresentation.text("development_goal_edit"),
                    systemImage: "pencil"
                ) {
                    store.send(.view(.editGoal))
                }
            ])
        ]
    }
}
