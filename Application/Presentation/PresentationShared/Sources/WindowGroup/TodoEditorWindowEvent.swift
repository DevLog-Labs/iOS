//
//  TodoEditorWindowEvent.swift
//  PresentationShared
//
//  Created by opfic on 5/31/26.
//

import Combine
import Domain

public final class TodoEditorWindowEvent {
    private let subject = PassthroughSubject<TodoEditorWindowSubmit, Never>()

    public var submits: AnyPublisher<TodoEditorWindowSubmit, Never> {
        subject.eraseToAnyPublisher()
    }

    public init() { }

    public func submitUpdate(
        value: TodoEditorWindowValue,
        todo: Todo
    ) {
        subject.send(.update(value, todo))
    }
}
