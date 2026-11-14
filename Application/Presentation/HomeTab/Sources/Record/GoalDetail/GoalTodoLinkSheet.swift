//
//  GoalTodoLinkSheet.swift
//  Development
//
//  Created by opfic on 9/15/26.
//

import SwiftUI
import Domain
import PresentationShared

struct GoalTodoLinkSheet: View {
    @ScaledMetric(relativeTo: .title) private var iconSize = UIFont.preferredFont(
        forTextStyle: .title2,
        compatibleWith: UITraitCollection(preferredContentSizeCategory: .large)
    ).lineHeight
    @Bindable var store: StoreOf<GoalTodoLinkFeature>

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                searchField
                sheetContent
                Text(RecordPresentation.text("development_goal_todo_optional_footer"))
                    .font(.footnote)
                    .foregroundStyle(Color.tertiaryLabel)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .padding(16)
        }
        .safeAreaInset(edge: .top, spacing: 0) { topBar }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.background.ignoresSafeArea())
        .overlay {
            if store.isUpdating {
                LoadingView()
            }
        }
        .prominentAlert(store, state: \.alert, action: \.alert)
        .sheetDismissDisabled(store.isUpdating)
    }

    private var topBar: some View {
        ZStack {
            Text(RecordPresentation.text("development_goal_todo_link_title"))
                .font(.headline)
            HStack {
                Button {
                    store.send(.view(.close))
                } label: {
                    if #available(iOS 26.0, *) {
                        Image(systemName: "xmark")
                    } else {
                        Text(RecordPresentation.text("common_close"))
                    }
                }
                .topBarButtonStyle()
                .disabled(store.isUpdating)
                Spacer()
                HStack(spacing: 8) {
                    if #available(iOS 26.0, *) {
                        Image(systemName: "ellipsis")
                            .prominentMenu(
                                items: clearSelectionMenuItems,
                                isEnabled: store.canClearSelection
                            ) { _ in
                                store.send(.view(.clearSelection))
                            }
                            .topBarButtonStyle()
                    } else {
                        Image(systemName: "ellipsis")
                            .font(.title3.weight(.semibold))
                            .frame(width: iconSize, height: iconSize)
                            .prominentMenu(
                                items: clearSelectionMenuItems,
                                isEnabled: store.canClearSelection
                            ) { _ in
                                store.send(.view(.clearSelection))
                            }
                            .topBarButtonStyle()
                    }
                    Button {
                        store.send(.view(.save))
                    } label: {
                        if #available(iOS 26.0, *) {
                            Image(systemName: "checkmark")
                        } else {
                            Text(RecordPresentation.text("development_goal_todo_done"))
                                .foregroundStyle(Color.accent)
                        }
                    }
                    .topBarButtonStyle()
                    .disabled(!store.canSave)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.background, ignoresSafeAreaEdges: .top)
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.tertiaryLabel)
            TextField(
                RecordPresentation.text("development_goal_todo_search"),
                text: $store.searchText
            )
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
        }
        .font(.title3)
        .padding()
        .background {
            RoundedRectangle(cornerRadius: CornerRadius.control)
                .fill(Color.secondaryBackground)
                .strokeBorder(Color.separator, lineWidth: 1)
        }
    }

    private var clearSelectionMenuItems: [ProminentMenuItem<GoalTodoLinkMenuAction>] {
        [
            ProminentMenuItem(
                action: .clearSelection,
                title: RecordPresentation.text("development_goal_todo_clear_selection"),
                systemImage: "xmark.circle"
            )
        ]
    }

    @ViewBuilder
    private var sheetContent: some View {
        if store.isLoading, store.todos.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
        } else if store.hasLoadFailure, store.todos.isEmpty {
            ContentUnavailableView {
                Label(
                    RecordPresentation.text("common_error_title"),
                    systemImage: "exclamationmark.triangle"
                )
            } description: {
                Text(RecordPresentation.text("development_goal_todo_load_error_message"))
            } actions: {
                Button(RecordPresentation.text("development_goal_todo_retry")) {
                    store.send(.view(.retry))
                }
                .buttonStyle(.borderedProminent)
            }
        } else if store.todos.isEmpty {
            ContentUnavailableView(
                RecordPresentation.text("development_goal_todo_available_empty_title"),
                systemImage: "checklist",
                description: Text(
                    RecordPresentation.text("development_goal_todo_available_empty_message")
                )
            )
        } else if store.filteredTodos.isEmpty {
            ContentUnavailableView.search(text: store.searchText)
        } else {
            ForEach(store.sections) { section in
                GoalTodoSelectionSection(
                    section: section,
                    selectedTodoIDs: store.selectedTodoIDs,
                    onToggle: { store.send(.view(.toggleTodo($0))) }
                )
            }
        }
    }
}

private enum GoalTodoLinkMenuAction: Hashable {
    case clearSelection
}
