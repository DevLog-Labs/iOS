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
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
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
    }

    private var header: some View {
        HomeSectionHeader {
            Text(RecordPresentation.text("development_goal_linked_todos"))
            if !isLoading {
                Text(verbatim: "\(todos.count)")
                    .fontWeight(.medium)
                    .foregroundStyle(Color.secondaryLabel)
            }
        } trailing: {
            if allowsManagement {
                Button(
                    RecordPresentation.text("development_goal_todo_manage"),
                    action: onManage
                )
                .font(.adaptive(isiOSAppOnMac ? .subheadline : .footnote).weight(.semibold))
                .foregroundStyle(Color.label)
                .buttonStyle(.plain)
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
            EmptyStateView(
                RecordPresentation.text("common_error_title"),
                systemImage: "exclamationmark.triangle",
                message: RecordPresentation.text("development_goal_todo_load_error_message")
            ) {
                Button(
                    RecordPresentation.text("development_goal_todo_retry"),
                    action: onRetry
                )
                .buttonStyle(RecordButtonStyle())
            }
        } else if todos.isEmpty {
            EmptyStateView(
                RecordPresentation.text("development_goal_todo_empty_title"),
                systemImage: "checklist",
                message: RecordPresentation.text("development_goal_todo_empty_message")
            )
        } else {
            LazyVStack(spacing: 0) {
                ForEach(todos, id: \.id) { todo in
                    GoalLinkedTodoRow(todo: todo) {
                        onSelect(todo.id)
                    }
                }
            }
        }
    }
}

// 완료 원과 제목을 표시하는 연결된 Todo 행
private struct GoalLinkedTodoRow: View {
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
    let todo: Todo
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            RecordListRow {
                HStack(spacing: 10) {
                    Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.adaptive(isiOSAppOnMac ? .body : .callout))
                        .foregroundStyle(todo.isCompleted ? Color.accent : .secondaryLabel)
                    Text(todo.title)
                        .font(.adaptive(isiOSAppOnMac ? .body : .subheadline))
                        .foregroundStyle(Color.label)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
