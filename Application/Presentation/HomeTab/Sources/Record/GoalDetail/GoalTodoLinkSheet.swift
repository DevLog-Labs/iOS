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
    @Bindable var store: StoreOf<GoalTodoLinkFeature>

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                searchField
                sheetContent
                Text(RecordPresentation.text("development_goal_todo_optional_footer"))
                    .font(.adaptive(.footnote))
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
                .font(.adaptive(.headline))
            HStack {
                Button {
                    store.send(.view(.close))
                } label: {
                    Image(systemName: "xmark")
                }
                .topBarButtonStyle()
                .disabled(store.isUpdating)
                Spacer()
                HStack(spacing: 8) {
                    // 제목 줄 오른쪽 버튼이라 메뉴 오른쪽 끝을 버튼 오른쪽 끝에 맞춤
                    DropdownMenu(alignment: .trailing, sections: [
                        DropdownMenuSection(items: [
                            DropdownMenuItem(
                                RecordPresentation.text("development_goal_todo_clear_selection"),
                                systemImage: "xmark.circle"
                            ) {
                                store.send(.view(.clearSelection))
                            }
                        ])
                    ]) {
                        Image(systemName: "ellipsis")
                            .topBarButtonStyle()
                    }
                    .disabled(!store.canClearSelection)
                    Button {
                        store.send(.view(.save))
                    } label: {
                        Image(systemName: "checkmark")
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
        .font(.adaptive(.title3))
        .padding()
        .background {
            RoundedRectangle(cornerRadius: CornerRadius.control)
                .fill(Color.secondaryBackground)
                .strokeBorder(Color.separator, lineWidth: 1)
        }
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
