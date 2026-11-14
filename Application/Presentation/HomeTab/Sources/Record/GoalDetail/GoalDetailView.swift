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
    @State private var store: StoreOf<GoalDetailFeature>

    public init(goalId: String) {
        self._store = State(initialValue: Store(
            initialState: GoalDetailFeature.State(goalId: goalId)
        ) {
            GoalDetailFeature()
        })
    }

    public var body: some View {
        NavigationStack {
            presentedContent
                .overlay {
                    if store.isTransitioning {
                        LoadingView()
                    }
                }
        }
    }

    private var mainContent: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                titleBar
                GoalDescriptionCard(
                    description: store.goal?.description ?? "",
                    isLoading: !store.hasLoaded && store.isLoading
                )
                timelineCard
                GoalLinkedTodoCard(
                    todos: store.linkedTodos,
                    isLoading: store.isTodoLoading,
                    hasLoadFailure: store.hasTodoLoadFailure,
                    allowsManagement: store.hasLoaded && store.allowsTodoLinkMutation,
                    onManage: { store.send(.view(.manageTodos)) },
                    onRetry: { store.send(.view(.retryTodos)) },
                    onSelect: { store.send(.view(.selectTodo($0))) }
                )
            }
            .padding(.horizontal)
        }
        .safeAreaInset(edge: .top, spacing: 0) { topBar }
        .safeAreaInset(edge: .bottom, spacing: 0) { recordActionBar }
        .background(Color.background.ignoresSafeArea())
        .toolbarVisibility(.hidden, for: .navigationBar)
        .onAppear { store.send(.view(.fetch)) }
        .prominentAlert(store, state: \.alert, action: \.alert)
    }

    private var presentedContent: some View {
        mainContent
            .sheet(item: $store.scope(state: \.recordEditor, action: \.recordEditor)) { destination in
                RecordEditorView(
                    goalId: store.goalId,
                    goalTitle: store.goalTitle,
                    record: destination.record,
                    onCompletion: {
                        store.send(.view(.refresh))
                    }
                )
            }
            .sheet(item: $store.scope(state: \.todoLinkSheet, action: \.todoLinkSheet)) {
                GoalTodoLinkSheet(store: $0)
            }
            .navigationDestination(
                item: $store.scope(state: \.recordDetail, action: \.recordDetail),
                interactivePop: true
            ) { destination in
                RecordDetailView(
                    goalTitle: store.goalTitle,
                    record: destination.record,
                    allowsMutation: store.allowsRecordMutation,
                    onUpdate: { store.send(.view(.refresh)) }
                )
            }
            .navigationDestination(
                item: $store.scope(state: \.todoDetail, action: \.todoDetail),
                interactivePop: true
            ) {
                TodoDetailView(
                    store: Store(
                        initialState: TodoDetailFeature.State(
                            todoId: $0.todoId,
                            showEditButton: false
                        )
                    ) {
                        TodoDetailFeature()
                    }
                )
            }
    }

    private var topBar: some View {
        HStack {
            if #available(iOS 26.0, *) {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                }
                .topBarButtonStyle(tint: Color.accent)
                .disabled(store.isTransitioning)
            } else {
                Button(action: { dismiss() }) {
                    Text(RecordPresentation.text("common_close"))
                }
                .topBarButtonStyle(tint: Color.accent)
                .disabled(store.isTransitioning)
            }
            Spacer()
            if let status = store.goalStatus {
                if #available(iOS 26.0, *) {
                    Image(systemName: "ellipsis")
                        .prominentMenu(
                            items: statusMenuItems(status),
                            isEnabled: !store.isLoading && !store.isTransitioning
                        ) { status in
                            store.send(.view(.selectStatus(status)))
                        }
                        .topBarButtonStyle()
                } else {
                    Image(systemName: "ellipsis")
                        .font(.title3.weight(.semibold))
                        .frame(width: 28, height: 28)
                        .prominentMenu(
                            items: statusMenuItems(status),
                            isEnabled: !store.isLoading && !store.isTransitioning
                        ) { status in
                            store.send(.view(.selectStatus(status)))
                        }
                        .adaptiveButtonStyle(
                            shape: .circle,
                            color: .secondaryBackground,
                            glassEffect: .enabled
                        )
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color.background, ignoresSafeAreaEdges: .top)
    }

    private var titleBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(RecordPresentation.text("development_goal_title"))
                .font(.largeTitle.bold())

            if !store.goalTitle.isEmpty {
                ScrollView(.horizontal) {
                    Text(store.goalTitle)
                        .font(.headline)
                        .foregroundStyle(Color.secondaryLabel)
                        .lineLimit(1)
                }
                .scrollIndicators(.hidden)
                .contentMargins(.horizontal, 16, for: .scrollContent)
                .padding(.horizontal, -16)
            }

            if let status = store.goalStatus {
                GoalStatusBadge(status: status)
            }
        }
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.background)
    }

    @ViewBuilder
    private var timelineCard: some View {
        VStack(spacing: 18) {
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
                    ForEach(Array(store.items.enumerated()), id: \.element.id) { index, item in
                        TimelineRow(
                            item: item,
                            isFirst: index == 0,
                            isLast: index == store.items.count - 1,
                            onSelect: { store.send(.view(.selectRecord(item))) }
                        )
                    }
                }
            }
        }
        .padding([.horizontal, .top])   // TimelineView 자체의 하단 패딩과 겹치기 때문에 .bottom은 제외
        .background {
            Rectangle()
                .fill(Color.secondaryBackground)
        }
    }

    private var draftRecord: DevelopmentRecord? {
        store.items.first(where: \.hasDraft)?.record
    }

    @ViewBuilder
    private var recordActionBar: some View {
        if store.hasLoaded, store.allowsRecordMutation {
            GoalDetailRecordActionBar(
                hasDraft: draftRecord != nil,
                isDisabled: store.isLoading || store.isTransitioning,
                onAddRecord: {
                    store.send(.view(.addRecord))
                },
                onContinueRecord: {
                    store.send(.view(.continueRecord))
                }
            )
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
