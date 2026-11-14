//
//  GoalLinkedTodoCard.swift
//  Development
//
//  Created by opfic on 9/15/26.
//

import SwiftUI
import Domain
import PresentationShared

struct GoalLinkedTodoCard: View {
    let todos: [Todo]
    let isLoading: Bool
    let hasLoadFailure: Bool
    let allowsManagement: Bool
    let onManage: () -> Void
    let onRetry: () -> Void
    let onSelect: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            content
        }
        .padding([.horizontal, .top])
        .background(Color.surface, in: .rect(cornerRadius: 24))
    }

    private var header: some View {
        HStack(spacing: 10) {
            Text(RecordPresentation.text("development_goal_linked_todos"))
                .font(.title3.bold())
            Spacer(minLength: 12)
            if allowsManagement {
                Button(
                    RecordPresentation.text("development_goal_todo_manage"),
                    action: onManage
                )
                .font(.callout.weight(.semibold))
                .foregroundStyle(Color.accent)
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .background(Color.primaryContainer, in: .capsule)
                .disabled(isLoading)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading, todos.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
        } else if hasLoadFailure, todos.isEmpty {
            ContentUnavailableView {
                Label(
                    RecordPresentation.text("common_error_title"),
                    systemImage: "exclamationmark.triangle"
                )
            } description: {
                Text(RecordPresentation.text("development_goal_todo_load_error_message"))
            } actions: {
                Button(
                    RecordPresentation.text("development_goal_todo_retry"),
                    action: onRetry
                )
                .buttonStyle(.borderedProminent)
            }
        } else if todos.isEmpty {
            ContentUnavailableView(
                RecordPresentation.text("development_goal_todo_empty_title"),
                systemImage: "checklist",
                description: Text(
                    RecordPresentation.text("development_goal_todo_empty_message")
                )
            )
        } else {
            LazyVStack(spacing: 0) {
                ForEach(todos, id: \.id) { todo in
                    GoalLinkedTodoRow(todo: todo) {
                        onSelect(todo.id)
                    }
                    if todo.id != todos.last?.id {
                        Divider()
                    }
                }
            }
        }
    }
}

private struct GoalLinkedTodoRow: View {
    let todo: Todo
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 14) {
                Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(todo.isCompleted ? Color.accent : Color.border)
                Text(todo.title)
                    .font(.body)
                    .foregroundStyle(Color.textPrimary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(Color.border)
            }
            .padding(.vertical, 12)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}
