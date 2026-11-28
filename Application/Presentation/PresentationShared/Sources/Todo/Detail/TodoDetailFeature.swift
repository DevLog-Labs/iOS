//
//  TodoDetailFeature.swift
//  PresentationShared
//
//  Created by opfic on 6/11/26.
//

import ComposableArchitecture
import Domain
import Foundation

@Reducer
public struct TodoDetailFeature {
    @ObservableState
    public struct State: Equatable, Identifiable {
        @Presents public var alert: AlertState<Never>?
        @Presents public var sheet: SheetState?
        @Presents public var fullScreenCover: FullScreenCoverState?
        public var todoId: String
        public var showEditButton: Bool
        public var todo: Todo?
        // 편집 화면이나 세부 정보 시트에서 저장한 Todo
        public var savedTodo: Todo?
        public var referenceItems: [Int: TodoReferenceItem] = [:]
        public var loading = LoadingFeature.State()
        // 좁은 창 세부 정보 시트의 속성
        // 시트를 닫아도 저장 결과를 받도록 시트 밖에서 소유
        var info: TodoDetailSideBarFeature.State
        // 상세 판 안 오른쪽 세부 정보 열을 연 동안
        var isDetailColumnPresented = false

        public init(todoId: String, showEditButton: Bool) {
            self.todoId = todoId
            self.showEditButton = showEditButton
            self.info = TodoDetailSideBarFeature.State(todoId: todoId, isEditable: showEditButton)
        }

        // 다른 Todo로 바꾸면 띄운 화면을 새로 만들어 그 Todo를 조회
        public var id: String {
            todoId
        }

        public var isLoading: Bool {
            loading.isLoading
        }
    }

    @ObservableState
    @CasePathable
    public enum SheetState: Equatable {
        case info
        case todo(TodoDetailFeature.State)

        public var todoDetail: TodoDetailFeature.State? {
            get {
                guard case .todo(let state) = self else { return nil }
                return state
            }
            set {
                guard let newValue else { return }
                self = .todo(newValue)
            }
        }

        public static func todo(_ todoId: TodoIdItem) -> Self {
            .todo(
                TodoDetailFeature.State(
                    todoId: todoId.id,
                    showEditButton: false
                )
            )
        }
    }

    @ObservableState
    public struct FullScreenCoverState: Equatable {
        public var destination: Destination
        var todoEditor: TodoEditorFeature.State?

        public enum Destination: Equatable {
            case editor
        }

        public static let editor = Self(destination: .editor)

        static func editor(_ todo: Todo) -> Self {
            Self(
                destination: .editor,
                todoEditor: TodoEditorFeature.State(todo: todo)
            )
        }
    }

    public enum Action: Equatable {
        case alert(PresentationAction<Never>)
        case sheet(PresentationAction<Sheet>)
        case fullScreenCover(PresentationAction<FullScreenCover>)
        case onAppear
        // 화면을 다시 그려도 불러온 Todo를 유지하고, 다른 곳에서 바꾼 Todo는 여는 화면이 다시 조회
        case fetch
        case fetchFailed
        case setSheet(SheetState?)
        case setFullScreenCover(FullScreenCoverState?)
        case setTodo(Todo)
        case setReferenceItems([Int: TodoReferenceItem])
        case loading(LoadingFeature.Action)
        case info(TodoDetailSideBarFeature.Action)
        case setDetailColumnPresented(Bool)

        @CasePathable
        public enum Sheet: Equatable {
            case tapCloseButton
            case todo(TodoDetailFeature.Action)
        }

        @CasePathable
        public enum FullScreenCover: Equatable {
            case todoEditor(TodoEditorFeature.Action)
        }
    }

    @Dependency(\.fetchTodoByIdUseCase) var fetchTodoUseCase
    @Dependency(\.fetchReferenceItemsUseCase) var fetchReferenceItemsUseCase

    public init() { }

    public var body: some ReducerOf<Self> {
        Scope(state: \.loading, action: \.loading) {
            LoadingFeature()
        }
        Scope(state: \.info, action: \.info) {
            TodoDetailSideBarFeature()
        }
        Reduce { state, action in
            switch action {
            case .sheet(.dismiss):
                state.sheet = nil
            case .alert:
                break
            case .sheet(.presented(.tapCloseButton)):
                state.sheet = nil
            case .sheet:
                break
            case .fullScreenCover(.presented(.todoEditor(.delegate(.updated(let todo))))):
                state.fullScreenCover = nil
                state.todo = todo
                state.savedTodo = todo
                state.referenceItems = [:]
                // 창 이벤트가 없는 상세도 불러온 세부 정보 시트 속성을 편집 화면에서 저장한 Todo로 갱신
                return .merge(
                    resolveMarkdownEffect(content: todo.content),
                    state.info.editor == nil ? .none : .send(.info(.setTodo(todo)))
                )
            case .fullScreenCover(.dismiss):
                state.fullScreenCover = nil
            case .fullScreenCover:
                break
            case .onAppear:
                // 좁은 창과 넓은 창의 화면을 오가도 같은 상태를 이어 그리므로 처음 한 번만 조회
                guard state.todo == nil else { break }
                return fetchTodoEffect(todoId: state.todoId)
            case .fetch:
                return fetchTodoEffect(todoId: state.todoId)
            case .fetchFailed:
                state.alert = Self.alertState()
            case .setSheet(let sheet):
                state.sheet = sheet
            case .setFullScreenCover(let cover):
                if cover?.destination == .editor,
                   let todo = state.todo {
                    state.fullScreenCover = .editor(todo)
                } else {
                    state.fullScreenCover = nil
                }
            case .setTodo(let todo):
                state.todo = todo
                state.referenceItems = [:]
                // 세부 정보 시트가 저장한 Todo는 입력 중인 값을 덮지 않도록 다시 넣지 않음
                guard let editor = state.info.editor,
                      editor.saveResult != .updated(todo) else {
                    return resolveMarkdownEffect(content: todo.content)
                }
                return .merge(
                    resolveMarkdownEffect(content: todo.content),
                    .send(.info(.setTodo(todo)))
                )
            case .setReferenceItems(let items):
                state.referenceItems = items
            case .loading:
                break
            case .info(.editor(.updateSucceeded(let todo))):
                // 시트를 닫은 뒤 끝난 저장도 상세와 목록에 반영
                state.todo = todo
                state.savedTodo = todo
                state.referenceItems = [:]
                return resolveMarkdownEffect(content: todo.content)
            case .info(.editor(.saveFailed)):
                // 시트를 닫은 뒤 실패한 저장은 상세 화면에서 알림, 상세 판 세부 정보 열에서 실패한 저장은 열에서 알림
                if state.sheet != .info && !state.isDetailColumnPresented {
                    state.info.editor?.alert = nil
                    state.alert = Self.alertState()
                }
            case .info:
                break
            case .setDetailColumnPresented(let isPresented):
                state.isDetailColumnPresented = isPresented
            }

            return .none
        }
        .ifLet(\.$alert, action: \.alert)
        .ifLet(\.$sheet, action: \.sheet) {
            SheetFeature()
        }
        .ifLet(\.$fullScreenCover, action: \.fullScreenCover) {
            FullScreenCoverFeature()
        }
    }
}

private struct FullScreenCoverFeature: Reducer {
    typealias State = TodoDetailFeature.FullScreenCoverState
    typealias Action = TodoDetailFeature.Action.FullScreenCover

    var body: some ReducerOf<Self> {
        EmptyReducer()
            .ifLet(\.todoEditor, action: \.todoEditor) {
                TodoEditorFeature()
            }
    }
}

private struct SheetFeature: Reducer {
    typealias State = TodoDetailFeature.SheetState
    typealias Action = TodoDetailFeature.Action.Sheet

    var body: some ReducerOf<Self> {
        EmptyReducer()
        .ifCaseLet(\.todo, action: \.todo) {
            TodoDetailFeature()
        }
    }
}

public extension DependencyValues {
    var fetchTodoByIdUseCase: FetchTodoByIdUseCase {
        get { self[FetchTodoByIdUseCaseKey.self] }
        set { self[FetchTodoByIdUseCaseKey.self] = newValue }
    }

    var fetchReferenceItemsUseCase: FetchReferenceItemsUseCase {
        get { self[FetchReferenceItemsUseCaseKey.self] }
        set { self[FetchReferenceItemsUseCaseKey.self] = newValue }
    }
}

private enum FetchTodoByIdUseCaseKey: DependencyKey {
    static var liveValue: FetchTodoByIdUseCase {
        preconditionFailure("FetchTodoByIdUseCase must be provided.")
    }

    static var testValue: FetchTodoByIdUseCase {
        liveValue
    }
}

private enum FetchReferenceItemsUseCaseKey: DependencyKey {
    static var liveValue: FetchReferenceItemsUseCase {
        preconditionFailure("FetchReferenceItemsUseCase must be provided.")
    }

    static var testValue: FetchReferenceItemsUseCase {
        liveValue
    }
}

private extension TodoDetailFeature {
    func fetchTodoEffect(todoId: String) -> Effect<Action> {
        .run { [fetchTodoUseCase] send in
            await send(.loading(.begin(target: .default, mode: .delayed)))
            do {
                let todo = try await fetchTodoUseCase.execute(todoId)
                await send(.loading(.end(target: .default, mode: .delayed)))
                await send(.setTodo(todo))
            } catch {
                await send(.loading(.end(target: .default, mode: .delayed)))
                await send(.fetchFailed)
            }
        }
    }

    func resolveMarkdownEffect(content: String) -> Effect<Action> {
        .run { [fetchReferenceItemsUseCase] send in
            let numbers = content.todoReferenceNumbers
            var referenceItems = [Int: TodoReferenceItem]()

            if !numbers.isEmpty {
                do {
                    referenceItems = try await fetchReferenceItemsUseCase.execute(numbers)
                        .mapValues(TodoReferenceItem.init(from:))
                } catch {
                    referenceItems = [:]
                }
            }

            await send(.setReferenceItems(referenceItems))
        }
    }

    static func alertState() -> AlertState<Never> {
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
}
