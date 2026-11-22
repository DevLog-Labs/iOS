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

        // 사이드바가 있으면 기록 작성을 개발 목표 오른쪽 칸에 표시
        return PaneSplitView(splitsOnDesktop: store.recordEditor != nil) {
            mainContent
        } detail: {
            if let editorStore = store.scope(state: \.recordEditor, action: \.recordEditor.presented) {
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
            // 상태 메뉴는 직접 그린 팝오버라 세로 막대에 넣지 않고 제목 줄에 표시
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

    @ViewBuilder
    private var statusMenu: some View {
        if let status = store.goalStatus {
            Image(systemName: "ellipsis")
                .prominentMenu(
                    items: statusMenuItems(status),
                    isEnabled: !store.isLoading && !store.isTransitioning
                ) { status in
                    store.send(.view(.selectStatus(status)))
                }
                .topBarButtonStyle()
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
                MarkdownContentView(content: description, isScrollEnabled: false)
                    // MarkdownRenderer 내부의 좌우 여백을 상쇄해 제목과 정렬
                    .padding(.horizontal, -16)
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
                ContentUnavailableView {
                    Label(
                        RecordPresentation.text("common_error_title"),
                        systemImage: "exclamationmark.triangle"
                    )
                } description: {
                    Text(RecordPresentation.text("development_record_timeline_error_message"))
                } actions: {
                    Button {
                        store.send(.view(.refresh))
                    } label: {
                        Text(RecordPresentation.text("development_record_timeline_retry"))
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else if !store.hasLoaded || store.isLoading, store.items.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
            } else if store.items.isEmpty {
                ContentUnavailableView(
                    RecordPresentation.text("development_record_empty_title"),
                    systemImage: "doc.badge.plus",
                    description: Text(RecordPresentation.text("development_record_empty_message"))
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

    private func statusMenuItems(_ status: DevelopmentGoal.Status) -> [ProminentMenuItem<DevelopmentGoal.Status>] {
        switch status {
        case .inProgress:
            [
                ProminentMenuItem(
                    action: .completed,
                    title: RecordPresentation.text("development_goal_complete"),
                    systemImage: "checkmark.circle"
                ),
                ProminentMenuItem(
                    action: .archived,
                    title: RecordPresentation.text("development_goal_archive"),
                    systemImage: "archivebox"
                )
            ]
        case .completed, .archived:
            [
                ProminentMenuItem(
                    action: .inProgress,
                    title: RecordPresentation.text("development_goal_resume"),
                    systemImage: "arrow.counterclockwise"
                )
            ]
        }
    }
}
