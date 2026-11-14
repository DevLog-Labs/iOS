//
//  GoalCreateTodoSelectionSheet.swift
//  Development
//
//  Created by opfic on 9/20/26.
//

import SwiftUI
import PresentationShared

struct GoalCreateTodoSelectionSheet: View {
    @Bindable var store: StoreOf<GoalCreateTodoSelectionFeature>

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
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

                Text(RecordPresentation.text("development_goal_todo_optional_footer"))
                    .font(.footnote)
                    .foregroundStyle(Color.tertiaryLabel)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .padding(16)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
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
                    Spacer()
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
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.background, ignoresSafeAreaEdges: .top)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.background.ignoresSafeArea())
        .onAppear { store.send(.view(.fetch)) }
    }
}
