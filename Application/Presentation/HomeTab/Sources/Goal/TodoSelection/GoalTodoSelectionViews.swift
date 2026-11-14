//
//  GoalTodoSelectionViews.swift
//  Development
//
//  Created by opfic on 9/20/26.
//

import SwiftUI
import Domain
import PresentationShared

struct GoalTodoSelectionSectionItem: Equatable, Identifiable {
    let category: TodoCategoryItem
    var todos: [Todo]

    var id: String { category.id }
}

func goalTodoSelectionSections(from todos: [Todo]) -> [GoalTodoSelectionSectionItem] {
    var sectionIndexByID = [String: Int]()
    var sections = [GoalTodoSelectionSectionItem]()
    for todo in todos {
        let category = TodoCategoryItem(from: todo.category)
        if let index = sectionIndexByID[category.id] {
            sections[index].todos.append(todo)
        } else {
            sectionIndexByID[category.id] = sections.count
            sections.append(GoalTodoSelectionSectionItem(category: category, todos: [todo]))
        }
    }
    return sections
}

struct GoalTodoSelectionSection: View {
    let section: GoalTodoSelectionSectionItem
    let selectedTodoIDs: Set<String>
    let onToggle: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: section.category.symbolName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.white)
                    .frame(width: 30, height: 30)
                    .background(section.category.color, in: .circle)
                Text(section.category.localizedName)
                    .font(.headline)
                Spacer()
            }

            LazyVStack(spacing: 0) {
                ForEach(section.todos, id: \.id) { todo in
                    GoalTodoSelectionRow(
                        todo: todo,
                        isSelected: selectedTodoIDs.contains(todo.id)
                    ) {
                        onToggle(todo.id)
                    }
                }
            }
            .background(Color.secondaryBackground)
            .compositingGroup()
            .clipShape(.rect(cornerRadius: 20))
        }
    }
}

struct GoalTodoSelectionRow: View {
    let todo: Todo
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 14) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? Color.accent : Color.separator)
                VStack(alignment: .leading, spacing: 4) {
                    Text(todo.title)
                        .font(.body.weight(isSelected ? .semibold : .regular))
                        .foregroundStyle(Color.label)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                    HStack(spacing: 8) {
                        Text("#\(todo.number)")
                        Text(todo.dueDate ?? todo.updatedAt, format: .dateTime.month().day())
                    }
                    .font(.caption)
                    .foregroundStyle(Color.tertiaryLabel)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if todo.isPinned {
                    Image(systemName: "star.fill")
                        .foregroundStyle(Color.warning)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(isSelected ? Color.tintFill : .clear)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}
