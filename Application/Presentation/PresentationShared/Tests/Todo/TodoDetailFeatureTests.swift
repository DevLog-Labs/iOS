//
//  TodoDetailFeatureTests.swift
//  PresentationSharedTests
//
//  Created by opfic on 6/11/26.
//

import Testing
import Foundation
import Domain
@testable import PresentationShared

@MainActor
struct TodoDetailFeatureTests {
    @Test("화면이 나타나면 todoId로 Todo를 가져와 상태에 반영한다")
    func 화면이_나타나면_todoId로_Todo를_가져와_상태에_반영한다() async {
        let todo = makeTodo(id: "todo-1", content: "content")
        let fetchSpy = FetchTodoByIdUseCaseSpy(todo: todo)
        let referenceSpy = FetchReferenceItemsUseCaseSpy()
        let adapter = DetailStoreTestAdapter(
            fetchUseCase: fetchSpy,
            referenceUseCase: referenceSpy,
            todoId: "todo-1"
        )

        adapter.onAppear()

        await waitUntil {
            adapter.todo == todo
        }

        #expect(fetchSpy.todoIds == ["todo-1"])
        #expect(adapter.todo == todo)
        #expect(referenceSpy.numbers.isEmpty)
    }

    @Test("Todo 본문에 참조 번호가 있으면 참조 항목을 가져와 상태에 반영한다")
    func Todo_본문에_참조_번호가_있으면_참조_항목을_가져와_상태에_반영한다() async {
        let todo = makeTodo(
            content: """
            body
            - refs #3
            - refs #5
            - refs #3
            """
        )
        let reference3 = makeTodoReference(id: "todo-3", title: "Reference 3")
        let reference5 = makeTodoReference(id: "todo-5", title: "Reference 5")
        let fetchSpy = FetchTodoByIdUseCaseSpy(todo: todo)
        let referenceSpy = FetchReferenceItemsUseCaseSpy(references: [
            3: reference3,
            5: reference5
        ])
        let adapter = DetailStoreTestAdapter(
            fetchUseCase: fetchSpy,
            referenceUseCase: referenceSpy,
            todoId: todo.id
        )

        adapter.onAppear()

        await waitUntil {
            adapter.referenceItems.count == 2
        }

        #expect(referenceSpy.numbers == [[3, 5]])
        #expect(adapter.referenceItems[3] == TodoReferenceItem(from: reference3))
        #expect(adapter.referenceItems[5] == TodoReferenceItem(from: reference5))
    }

    @Test("Todo를 새로 설정하면 기존 참조 항목을 비우고 새 본문 기준으로 다시 해석한다")
    func Todo를_새로_설정하면_기존_참조_항목을_비우고_새_본문_기준으로_다시_해석한다() async {
        let reference7 = makeTodoReference(id: "todo-7", title: "Reference 7")
        let fetchSpy = FetchTodoByIdUseCaseSpy(todo: makeTodo())
        let referenceSpy = FetchReferenceItemsUseCaseSpy(references: [7: reference7])
        let adapter = DetailStoreTestAdapter(
            fetchUseCase: fetchSpy,
            referenceUseCase: referenceSpy,
            todoId: "todo-1"
        )

        adapter.setReferenceItems([99: TodoReferenceItem(from: makeTodoReference(id: "todo-99"))])
        adapter.setTodo(makeTodo(content: "- refs #7"))

        #expect(adapter.referenceItems.isEmpty)

        await waitUntil {
            adapter.referenceItems[7] == TodoReferenceItem(from: reference7)
        }

        #expect(referenceSpy.numbers == [[7]])
    }

    @Test("Todo 조회가 지연되면 로딩 상태를 표시하고 완료되면 해제한다")
    func Todo_조회가_지연되면_로딩_상태를_표시하고_완료되면_해제한다() async {
        let clock = TestClock()
        let fetchSpy = FetchTodoByIdUseCaseSpy(todo: makeTodo())
        fetchSpy.shouldSuspend = true
        let adapter = DetailStoreTestAdapter(
            fetchUseCase: fetchSpy,
            referenceUseCase: FetchReferenceItemsUseCaseSpy(),
            todoId: "todo-1",
            configureDependencies: {
                $0.continuousClock = clock
            }
        )

        adapter.onAppear()

        await waitUntil {
            fetchSpy.todoIds == ["todo-1"]
        }

        #expect(!adapter.isLoading)

        await clock.advance(by: .milliseconds(300))

        await waitUntil {
            adapter.isLoading
        }

        #expect(adapter.isLoading)

        fetchSpy.resume()

        await waitUntil {
            !adapter.isLoading && adapter.todo != nil
        }

        #expect(!adapter.isLoading)
    }

    @Test("Todo 조회 실패 시 공통 에러 알림 상태를 설정한다")
    func Todo_조회_실패_시_공통_에러_알림_상태를_설정한다() async {
        let fetchSpy = FetchTodoByIdUseCaseSpy(todo: makeTodo())
        fetchSpy.error = DetailTestError.failure
        let adapter = DetailStoreTestAdapter(
            fetchUseCase: fetchSpy,
            referenceUseCase: FetchReferenceItemsUseCaseSpy(),
            todoId: "todo-1"
        )

        adapter.onAppear()

        await waitUntil {
            adapter.alert != nil
        }

        #expect(adapter.alert == expectedErrorAlert())
        #expect(!adapter.isLoading)
    }

    @Test("시트와 편집 화면 상태를 액션에 맞게 변경한다")
    func 시트와_편집_화면_상태를_액션에_맞게_변경한다() async {
        let reference = makeTodoReference(id: "todo-7", title: "Reference 7")
        let fetchSpy = FetchTodoByIdUseCaseSpy(
            todo: makeTodo(id: "todo-2", content: "- refs #7")
        )
        let referenceSpy = FetchReferenceItemsUseCaseSpy(references: [7: reference])
        let adapter = DetailStoreTestAdapter(
            fetchUseCase: fetchSpy,
            referenceUseCase: referenceSpy,
            todoId: "todo-1",
            showEditButton: false
        )

        adapter.setTodo(makeTodo(id: "todo-edit"))
        adapter.setSheet(.info)
        adapter.setFullScreenCover(.editor)

        #expect(adapter.sheet == .info)
        #expect(adapter.fullScreenCoverDestination == .editor)
        #expect(!adapter.showEditButton)

        adapter.setSheet(.todo(TodoIdItem(id: "todo-2")))

        #expect(todoDetailState(in: adapter.sheet)?.todoId == "todo-2")
        #expect(todoDetailState(in: adapter.sheet)?.showEditButton == false)

        adapter.onSheetTodoAppear()

        await waitUntil {
            todoDetailState(in: adapter.sheet)?.referenceItems[7] == TodoReferenceItem(from: reference)
        }

        #expect(fetchSpy.todoIds == ["todo-2"])
        #expect(referenceSpy.numbers == [[7]])
        #expect(adapter.referenceItems.isEmpty)

        adapter.dismissSheet()
        adapter.dismissFullScreenCover()

        #expect(adapter.sheet == nil)
        #expect(adapter.fullScreenCover == nil)
    }

    @Test("TodoEditor 수정 delegate는 editor를 닫고 Todo 상세 상태를 갱신한다")
    func TodoEditor_수정_delegate는_editor를_닫고_Todo_상세_상태를_갱신한다() async {
        let reference = makeTodoReference(id: "todo-7", title: "Reference 7")
        let referenceSpy = FetchReferenceItemsUseCaseSpy(references: [7: reference])
        let adapter = DetailStoreTestAdapter(
            fetchUseCase: FetchTodoByIdUseCaseSpy(todo: makeTodo()),
            referenceUseCase: referenceSpy,
            todoId: "todo-1"
        )
        let updatedTodo = makeTodo(
            id: "todo-1",
            title: "Updated",
            content: "- refs #7"
        )

        adapter.setTodo(makeTodo(id: "todo-1"))
        adapter.setFullScreenCover(.editor)
        adapter.todoEditorUpdated(updatedTodo)

        #expect(adapter.fullScreenCover == nil)
        #expect(adapter.todo == updatedTodo)
        #expect(adapter.savedTodo == updatedTodo)
        #expect(adapter.referenceItems.isEmpty)

        await waitUntil {
            adapter.referenceItems[7] == TodoReferenceItem(from: reference)
        }

        #expect(referenceSpy.numbers == [[7]])
    }

    @Test("세부 정보 시트를 닫은 뒤 끝난 저장도 상세 Todo에 반영한다")
    func 세부_정보_시트를_닫은_뒤_끝난_저장도_상세_Todo에_반영한다() async {
        let upsertSpy = TodoEditorUpsertTodoUseCaseSpy()
        upsertSpy.shouldSuspend = true
        let adapter = makeInfoAdapter(upsertSpy: upsertSpy)

        await adapter.openInfoAndTogglePinned()
        adapter.dismissSheet()
        upsertSpy.resume()

        await waitUntil {
            adapter.todo?.isPinned == true
        }

        #expect(upsertSpy.todos.map(\.isPinned) == [true])
        #expect(adapter.savedTodo == upsertSpy.todos.first)
        #expect(adapter.alert == nil)
    }

    @Test("세부 정보 시트를 닫은 뒤 저장에 실패하면 상세 화면에 공통 에러 알림을 표시한다")
    func 세부_정보_시트를_닫은_뒤_저장에_실패하면_상세_화면에_공통_에러_알림을_표시한다() async {
        let upsertSpy = TodoEditorUpsertTodoUseCaseSpy()
        upsertSpy.shouldSuspend = true
        upsertSpy.error = DetailTestError.failure
        let adapter = makeInfoAdapter(upsertSpy: upsertSpy)

        await adapter.openInfoAndTogglePinned()
        adapter.dismissSheet()
        upsertSpy.resume()

        await waitUntil {
            adapter.alert != nil
        }

        #expect(adapter.alert == expectedErrorAlert())
        #expect(adapter.infoEditor?.alert == nil)
        #expect(adapter.savedTodo == nil)
    }

    @Test("세부 정보를 불러온 뒤 편집 화면에서 저장하면 세부 정보 속성도 저장한 Todo를 따른다")
    func 세부_정보를_불러온_뒤_편집_화면에서_저장하면_세부_정보_속성도_저장한_Todo를_따른다() async {
        let adapter = makeInfoAdapter(upsertSpy: TodoEditorUpsertTodoUseCaseSpy())
        var updatedTodo = makeTodo(title: "Updated")
        updatedTodo.tags = ["tag"]

        await adapter.openInfo()
        adapter.dismissSheet()
        adapter.setTodo(makeTodo())
        adapter.setFullScreenCover(.editor)
        adapter.todoEditorUpdated(updatedTodo)

        await waitUntil {
            adapter.infoEditor?.title == "Updated"
        }

        #expect(adapter.infoEditor?.title == "Updated")
        #expect(adapter.infoEditor?.tags == ["tag"])
    }

    private func makeInfoAdapter(upsertSpy: TodoEditorUpsertTodoUseCaseSpy) -> DetailStoreTestAdapter {
        DetailStoreTestAdapter(
            fetchUseCase: FetchTodoByIdUseCaseSpy(todo: makeTodo()),
            referenceUseCase: FetchReferenceItemsUseCaseSpy(),
            todoId: "todo-1",
            configureDependencies: {
                $0.date.now = todoEditorNow
                $0.fetchTodoCategoryPreferencesUseCase = TodoEditorFetchPreferencesUseCaseSpy()
                $0.upsertTodoUseCase = upsertSpy
            }
        )
    }
}

@MainActor
private protocol DetailTestAdapter {
    var todoId: String { get }
    var showEditButton: Bool { get }
    var todo: Todo? { get }
    var savedTodo: Todo? { get }
    var referenceItems: [Int: TodoReferenceItem] { get }
    var isLoading: Bool { get }
    var alert: AlertState<Never>? { get }
    var sheet: TodoDetailFeature.SheetState? { get }
    var fullScreenCover: TodoDetailFeature.FullScreenCoverState? { get }
    var fullScreenCoverDestination: TodoDetailFeature.FullScreenCoverState.Destination? { get }
    var infoEditor: TodoEditorFeature.State? { get }

    func onAppear()
    func onSheetTodoAppear()
    func setSheet(_ sheet: TodoDetailFeature.SheetState?)
    func dismissSheet()
    func setFullScreenCover(_ cover: TodoDetailFeature.FullScreenCoverState?)
    func dismissFullScreenCover()
    func todoEditorUpdated(_ todo: Todo)
    func setTodo(_ todo: Todo)
    func setReferenceItems(_ items: [Int: TodoReferenceItem])
    func openInfo() async
    func openInfoAndTogglePinned() async
}

@MainActor
private struct DetailStoreTestAdapter: DetailTestAdapter {
    private let store: StoreOf<TodoDetailFeature>

    var todoId: String { store.todoId }
    var showEditButton: Bool { store.showEditButton }
    var todo: Todo? { store.todo }
    var savedTodo: Todo? { store.savedTodo }
    var referenceItems: [Int: TodoReferenceItem] { store.referenceItems }
    var isLoading: Bool { store.isLoading }
    var alert: AlertState<Never>? { store.alert }
    var sheet: TodoDetailFeature.SheetState? { store.sheet }
    var fullScreenCover: TodoDetailFeature.FullScreenCoverState? { store.fullScreenCover }
    var fullScreenCoverDestination: TodoDetailFeature.FullScreenCoverState.Destination? {
        store.fullScreenCover?.destination
    }
    var infoEditor: TodoEditorFeature.State? { store.info.editor }

    init(
        fetchUseCase: FetchTodoByIdUseCase,
        referenceUseCase: FetchReferenceItemsUseCase,
        todoId: String,
        showEditButton: Bool = true,
        configureDependencies: ((inout DependencyValues) -> Void)? = nil
    ) {
        store = Store(
            initialState: TodoDetailFeature.State(
                todoId: todoId,
                showEditButton: showEditButton
            )
        ) {
            TodoDetailFeature()
        } withDependencies: {
            $0.fetchTodoByIdUseCase = fetchUseCase
            $0.fetchReferenceItemsUseCase = referenceUseCase
            $0.continuousClock = ContinuousClock()
            configureDependencies?(&$0)
        }
    }

    func onAppear() {
        store.send(.onAppear)
    }

    func onSheetTodoAppear() { store.send(.sheet(.presented(.todo(.onAppear)))) }

    func setSheet(_ sheet: TodoDetailFeature.SheetState?) {
        store.send(.setSheet(sheet))
    }

    func dismissSheet() {
        store.send(.sheet(.dismiss))
    }

    func setFullScreenCover(_ cover: TodoDetailFeature.FullScreenCoverState?) {
        store.send(.setFullScreenCover(cover))
    }

    func dismissFullScreenCover() {
        store.send(.fullScreenCover(.dismiss))
    }

    func todoEditorUpdated(_ todo: Todo) {
        store.send(.fullScreenCover(.presented(.todoEditor(.delegate(.updated(todo))))))
    }

    func setTodo(_ todo: Todo) {
        store.send(.setTodo(todo))
    }

    func setReferenceItems(_ items: [Int: TodoReferenceItem]) {
        store.send(.setReferenceItems(items))
    }

    func openInfo() async {
        store.send(.setSheet(.info))
        store.send(.info(.onAppear))

        await waitUntil {
            store.info.editor != nil
        }
    }

    func openInfoAndTogglePinned() async {
        await openInfo()
        store.send(.info(.editor(.binding(.set(\.isPinned, true)))))
    }
}

private func todoDetailState(
    in sheet: TodoDetailFeature.SheetState?
) -> TodoDetailFeature.State? {
    guard case .todo(let state) = sheet else { return nil }
    return state
}

private func expectedErrorAlert() -> AlertState<Never> {
    AlertState {
        TextState(String(localized: "common_error_title", bundle: PresentationResources.bundle))
    } actions: {
        ButtonState(role: .cancel) {
            TextState(String(localized: "common_close", bundle: PresentationResources.bundle))
        }
    } message: {
        TextState(String(localized: "common_error_message", bundle: PresentationResources.bundle))
    }
}

private final class FetchTodoByIdUseCaseSpy: FetchTodoByIdUseCase {
    var todo: Todo
    var error: Error?
    var shouldSuspend = false
    private(set) var todoIds: [String] = []
    private var continuation: CheckedContinuation<Void, Never>?
    private var shouldResume = false

    init(todo: Todo) {
        self.todo = todo
    }

    func execute(_ todoId: String) async throws -> Todo {
        todoIds.append(todoId)

        if shouldSuspend {
            await withCheckedContinuation { continuation in
                if shouldResume {
                    shouldResume = false
                    continuation.resume()
                } else {
                    self.continuation = continuation
                }
            }
        }

        if let error {
            throw error
        }

        return todo
    }

    func resume() {
        guard let continuation else {
            shouldResume = true
            return
        }

        self.continuation = nil
        continuation.resume()
    }
}

private final class FetchReferenceItemsUseCaseSpy: FetchReferenceItemsUseCase {
    var references: [Int: TodoReference]
    var error: Error?
    private(set) var numbers: [[Int]] = []

    init(references: [Int: TodoReference] = [:]) {
        self.references = references
    }

    func execute(_ numbers: [Int]) async throws -> [Int: TodoReference] {
        self.numbers.append(numbers)

        if let error {
            throw error
        }

        return references
    }
}

private enum DetailTestError: Error {
    case failure
}

private func makeTodo(
    id: String = "todo-1",
    number: Int = 1,
    title: String = "Todo",
    content: String = "content"
) -> Todo {
    Todo(
        id: id,
        isPinned: false,
        isCompleted: false,
        isChecked: false,
        number: number,
        title: title,
        content: content,
        createdAt: Date(timeIntervalSince1970: 0),
        updatedAt: Date(timeIntervalSince1970: 0),
        completedAt: nil,
        deletedAt: nil,
        dueDate: nil,
        tags: [],
        category: .system(.issue)
    )
}

private func makeTodoReference(
    id: String,
    title: String = "Reference"
) -> TodoReference {
    TodoReference(
        id: id,
        title: title,
        category: .system(.issue)
    )
}
