//
//  TodoEditorWindowValue.swift
//  PresentationShared
//
//  Created by opfic on 5/31/26.
//

import Foundation
import Domain

public enum TodoEditorWindowValue: Codable, Hashable {
    case edit(TodoEditorWindowTodo)

    init(todo: Todo) {
        self = .edit(TodoEditorWindowTodo(todo: todo))
    }
}

public struct TodoEditorWindowCategory: Codable, Hashable {
    private enum Kind: String, Codable {
        case system
        case user
    }

    private let kind: Kind
    private let id: String
    private let name: String
    private let colorHex: String

    init(todoCategory: TodoCategory) {
        switch todoCategory {
        case .system(let systemTodoCategory):
            self.kind = .system
            self.id = systemTodoCategory.rawValue
            self.name = ""
            self.colorHex = ""
        case .user(let userTodoCategory):
            self.kind = .user
            self.id = userTodoCategory.id
            self.name = userTodoCategory.name
            self.colorHex = userTodoCategory.colorHex
        }
    }

    public var todoCategory: TodoCategory {
        switch kind {
        case .system:
            let systemTodoCategory = SystemTodoCategory(rawValue: id) ?? .etc
            return .system(systemTodoCategory)
        case .user:
            return .user(UserTodoCategory(
                id: id,
                name: name,
                colorHex: colorHex
            ))
        }
    }
}

public struct TodoEditorWindowTodo: Codable, Hashable {
    private let id: String
    private let isPinned: Bool
    private let isCompleted: Bool
    private let isChecked: Bool
    private let number: Int
    private let title: String
    private let content: String
    private let createdAt: Date
    private let updatedAt: Date
    private let completedAt: Date?
    private let deletedAt: Date?
    private let dueDate: Date?
    private let tags: [String]
    private let category: TodoEditorWindowCategory

    init(todo: Todo) {
        self.id = todo.id
        self.isPinned = todo.isPinned
        self.isCompleted = todo.isCompleted
        self.isChecked = todo.isChecked
        self.number = todo.number
        self.title = todo.title
        self.content = todo.content
        self.createdAt = todo.createdAt
        self.updatedAt = todo.updatedAt
        self.completedAt = todo.completedAt
        self.deletedAt = todo.deletedAt
        self.dueDate = todo.dueDate
        self.tags = todo.tags
        self.category = TodoEditorWindowCategory(todoCategory: todo.category)
    }

    public static func == (
        lhs: TodoEditorWindowTodo,
        rhs: TodoEditorWindowTodo
    ) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public var todo: Todo {
        Todo(
            id: id,
            isPinned: isPinned,
            isCompleted: isCompleted,
            isChecked: isChecked,
            number: number,
            title: title,
            content: content,
            createdAt: createdAt,
            updatedAt: updatedAt,
            completedAt: completedAt,
            deletedAt: deletedAt,
            dueDate: dueDate,
            tags: tags,
            category: category.todoCategory
        )
    }
}

public enum TodoEditorWindowSubmit: Equatable {
    case update(TodoEditorWindowValue, Todo)
}

public extension TodoEditorWindowValue {
    func matchesEdit(todoId: String) -> Bool {
        guard case .edit(let windowTodo) = self else { return false }
        return windowTodo.todo.id == todoId
    }
}
