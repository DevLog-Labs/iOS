//
//  TodoDetailSideBarFeatureTests.swift
//  PresentationSharedTests
//
//  Created by opfic on 11/16/26.
//

import Testing
import Foundation
import Domain
@testable import PresentationShared

@MainActor
struct TodoDetailSideBarFeatureTests {
    @Test("편집할 수 있는 사이드바는 값을 바꾸면 바로 저장한다")
    func 편집할_수_있는_사이드바는_값을_바꾸면_바로_저장한다() async {
        let upsertSpy = TodoEditorUpsertTodoUseCaseSpy()
        let store = makeTodoDetailSideBarStore(isEditable: true, upsertTodoUseCase: upsertSpy)

        await store.send(.onAppear)
        await store.skipReceivedActions(strict: false)
        await store.send(.editor(.binding(.set(\.isPinned, true))))
        await store.skipReceivedActions(strict: false)

        #expect(upsertSpy.todos.map(\.isPinned) == [true])
        #expect(store.state.editor?.saveResult == upsertSpy.todos.first.map { .updated($0) })
    }

    @Test("저장에 실패하면 바꾼 값을 되돌려 다음 저장에 싣지 않는다")
    func 저장에_실패하면_바꾼_값을_되돌려_다음_저장에_싣지_않는다() async {
        let upsertSpy = TodoEditorUpsertTodoUseCaseSpy()
        let store = makeTodoDetailSideBarStore(isEditable: true, upsertTodoUseCase: upsertSpy)

        await store.send(.onAppear)
        await store.skipReceivedActions(strict: false)
        upsertSpy.error = TodoEditorTestError.failure
        await store.send(.editor(.binding(.set(\.isPinned, true))))
        await store.skipReceivedActions(strict: false)

        #expect(store.state.editor?.isPinned == false)
        #expect(store.state.editor?.alert != nil)

        upsertSpy.error = nil
        await store.send(.editor(.binding(.set(\.isCompleted, true))))
        await store.skipReceivedActions(strict: false)

        #expect(upsertSpy.todos.last?.isPinned == false)
        #expect(upsertSpy.todos.last?.isCompleted == true)
    }

    @Test("읽기 전용 사이드바는 값을 바꿔도 저장하지 않는다")
    func 읽기_전용_사이드바는_값을_바꿔도_저장하지_않는다() async {
        let upsertSpy = TodoEditorUpsertTodoUseCaseSpy()
        let store = makeTodoDetailSideBarStore(isEditable: false, upsertTodoUseCase: upsertSpy)

        await store.send(.onAppear)
        await store.skipReceivedActions(strict: false)
        await store.send(.editor(.binding(.set(\.isPinned, true))))
        await store.skipReceivedActions(strict: false)

        #expect(upsertSpy.todos.isEmpty)
    }

    @Test("다른 곳에서 바꾼 Todo를 다시 받으면 값을 바꾸고 불러온 카테고리는 유지한다")
    func 다른_곳에서_바꾼_Todo를_다시_받으면_값을_바꾸고_불러온_카테고리는_유지한다() async {
        let category = UserTodoCategory(id: "custom", name: "Custom", colorHex: "#111111")
        let preferencesSpy = TodoEditorFetchPreferencesUseCaseSpy(preferences: [
            TodoCategoryPreference(category: .user(category), isVisible: true)
        ])
        let store = makeTodoDetailSideBarStore(isEditable: true, fetchPreferencesUseCase: preferencesSpy)

        await store.send(.onAppear)
        await store.skipReceivedActions(strict: false)
        let categories = store.state.editor?.categories
        await store.send(.setTodo(makeTodoEditorTodo(isCompleted: true)))
        await store.skipReceivedActions(strict: false)

        #expect(categories?.contains(TodoCategoryItem(from: .user(category))) == true)
        #expect(store.state.editor?.categories == categories)
        #expect(store.state.editor?.isCompleted == true)
        #expect(preferencesSpy.executeCallCount == 1)
    }
}

@MainActor
private func makeTodoDetailSideBarStore(
    isEditable: Bool,
    fetchPreferencesUseCase: FetchTodoCategoryPreferencesUseCase = TodoEditorFetchPreferencesUseCaseSpy(),
    upsertTodoUseCase: UpsertTodoUseCase = TodoEditorUpsertTodoUseCaseSpy()
) -> TestStoreOf<TodoDetailSideBarFeature> {
    let store = TestStore(
        initialState: TodoDetailSideBarFeature.State(todoId: "todo-1", isEditable: isEditable)
    ) {
        TodoDetailSideBarFeature()
    } withDependencies: {
        $0.date.now = todoEditorNow
        $0.fetchTodoByIdUseCase = TodoDetailSideBarFetchTodoUseCaseStub()
        $0.fetchTodoCategoryPreferencesUseCase = fetchPreferencesUseCase
        $0.fetchReferenceItemsUseCase = TodoEditorFetchReferenceItemsUseCaseSpy()
        $0.upsertTodoUseCase = upsertTodoUseCase
    }
    store.exhaustivity = .off(showSkippedAssertions: false)
    return store
}

private final class TodoDetailSideBarFetchTodoUseCaseStub: FetchTodoByIdUseCase {
    func execute(_ todoId: String) async throws -> Todo {
        makeTodoEditorTodo(id: todoId)
    }
}
