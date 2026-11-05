//
//  TodoEditorFeature.swift
//  PresentationShared
//
//  Created by opfic on 6/12/26.
//

import ComposableArchitecture
import Domain
import Foundation
import OrderedCollections

@Reducer
public struct TodoEditorFeature {
    @ObservableState
    public struct State: Equatable {
        @Presents public var alert: AlertState<Never>?
        public var isInspectorPresented = false
        public var inspectorContent = InspectorContent.options
        public var isCompleted: Bool = false
        public var completedAt: Date?
        public var isPinned: Bool = false
        public var title: String = ""
        public var content: String = ""
        public var referenceItems: [Int: TodoReferenceItem] = [:]
        public var dueDate: Date?
        public var selectedDueDate: Date {
            get { dueDate ?? Date() }
            set { dueDate = newValue }
        }
        public var loading = LoadingFeature.State()
        public var tags: OrderedSet<String> = []
        public var tagText: String = ""
        public var tabViewTag: EditorTab = .editor
        public var editorHeaderHeight = CGFloat.zero
        public var windowControlsInset = CGFloat.zero
        public var categories: [TodoCategoryItem] = []
        public var category = TodoCategoryItem(from: .system(.etc))
        public var selectedCategoryID: String {
            get { category.id }
            set {
                guard let category = categories.first(where: { $0.id == newValue }) else { return }
                self.category = category
            }
        }
        public var saveResult: SaveResult?
        let id: String
        let isChecked: Bool
        let number: Int?
        let createdAt: Date?
        let deletedAt: Date?
        let goalId: String?
        let originalDraft: TodoDraft?

        var isValidToSave: Bool {
            !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        public var isLoading: Bool {
            loading.isLoading
        }
        var navigationTitle: String {
            if originalDraft == nil {
                return String.localizedStringWithFormat(
                    String(localized: "todo_editor_new_format", bundle: PresentationResources.bundle),
                    category.localizedName
                )
            }

            return String(localized: "todo_edit", bundle: PresentationResources.bundle)
        }
        public var hasChanges: Bool {
            guard let originalDraft else { return true }
            var draft = makeTodoDraft(now: Date())
            if let originalDueDate = originalDraft.dueDate,
               let dueDate = draft.dueDate,
               Calendar.current.isDate(originalDueDate, inSameDayAs: dueDate) {
                draft.dueDate = originalDueDate
            }
            return originalDraft != draft
        }
        public var isReadyToSubmit: Bool {
            isValidToSave && hasChanges
        }

        public init(category: TodoCategory, id: String = UUID().uuidString) {
            self.id = id
            self.isChecked = false
            self.number = nil
            self.createdAt = nil
            self.deletedAt = nil
            self.goalId = nil
            self.originalDraft = nil
            self.category = TodoCategoryItem(from: category)
            self.categories = [TodoCategoryItem(from: category)]
        }

        public init(todo: Todo) {
            self.id = todo.id
            self.isChecked = todo.isChecked
            self.number = todo.number
            self.createdAt = todo.createdAt
            self.deletedAt = todo.deletedAt
            self.goalId = todo.goalId
            self.originalDraft = TodoDraft(todo: todo)
            self.isCompleted = todo.isCompleted
            self.completedAt = todo.completedAt
            self.isPinned = todo.isPinned
            self.title = todo.title
            self.content = todo.content
            self.dueDate = todo.dueDate
            self.tags = OrderedSet(todo.tags)
            self.category = TodoCategoryItem(from: todo.category)
        }
    }

    public enum InspectorContent: Equatable {
        case options
        case todo(TodoIdItem)
    }

    public enum EditorTab: Equatable {
        case editor
        case preview
    }

    public enum SaveResult: Equatable {
        case created
        case updated(Todo)
    }

    public enum Action: BindableAction, Equatable {
        case alert(PresentationAction<Never>)
        case binding(BindingAction<State>)
        case delegate(Delegate)
        case onAppear
        case addTag(String)
        case removeTag(String)
        case setCompleted(Bool)
        case showInspector(InspectorContent)
        case upsertTodo
        case createSucceeded
        case saveFailed
        case updateSucceeded(Todo)
        case loading(LoadingFeature.Action)

        public enum Delegate: Equatable {
            case created
            case updated(Todo)
        }
    }

    private enum CancelID: Hashable {
        case resolveMarkdown
    }

    @Dependency(\.date.now) var now
    @Dependency(\.fetchTodoCategoryPreferencesUseCase) var fetchPreferencesUseCase
    @Dependency(\.fetchReferenceItemsUseCase) var fetchReferenceItemsUseCase
    @Dependency(\.upsertTodoUseCase) var upsertTodoUseCase

    public init() { }

    public var body: some ReducerOf<Self> {
        Scope(state: \.loading, action: \.loading) {
            LoadingFeature()
        }
        BindingReducer()
            .onChange(of: \.isCompleted) { _, isCompleted in
                Reduce { state, _ in
                    state.completedAt = isCompleted ? now : nil
                    return .none
                }
            }
        Reduce { state, action in
            switch action {
            case .alert:
                break
            case .binding(\.content):
                if state.tabViewTag == .preview {
                    return resolveMarkdownEffect(content: state.content)
                }
            case .binding(\.dueDate), .binding(\.selectedDueDate):
                if let tomorrowDate = Calendar.current.date(byAdding: .day, value: 1, to: now),
                   let dueDate = state.dueDate {
                    state.dueDate = max(dueDate, tomorrowDate)
                } else {
                    state.dueDate = nil
                }
            case .binding(\.tabViewTag):
                if state.tabViewTag == .preview {
                    return resolveMarkdownEffect(content: state.content)
                }
            case .binding:
                break
            case .delegate:
                break
            case .onAppear:
                return fetchCategoriesEffect()
            case .addTag(let tag):
                if !tag.isEmpty {
                    state.tags.append(tag)
                }
            case .removeTag(let tagText):
                state.tags.removeAll { $0 == tagText }
            case .setCompleted(let isCompleted):
                if state.isCompleted != isCompleted {
                    state.completedAt = isCompleted ? now : nil
                }
                state.isCompleted = isCompleted
            case .showInspector(let content):
                if content == .options && state.inspectorContent == .options {
                    state.isInspectorPresented.toggle()
                } else {
                    state.isInspectorPresented = true
                }
                state.inspectorContent = content
            case .upsertTodo:
                state.saveResult = nil
                if state.originalDraft == nil {
                    return createTodoEffect(state.makeTodoDraft(now: now))
                } else if let todo = state.makeTodo(now: now) {
                    return updateTodoEffect(todo)
                }
            case .createSucceeded:
                state.saveResult = .created
            case .saveFailed:
                state.alert = Self.alertState()
            case .updateSucceeded(let todo):
                state.saveResult = .updated(todo)
            case .loading:
                break
            }

            return .none
        }
        .ifLet(\.$alert, action: \.alert)
    }
}

public extension DependencyValues {
    var fetchTodoCategoryPreferencesUseCase: FetchTodoCategoryPreferencesUseCase {
        get { self[FetchTodoCategoryPreferencesUseCaseKey.self] }
        set { self[FetchTodoCategoryPreferencesUseCaseKey.self] = newValue }
    }

    var upsertTodoUseCase: UpsertTodoUseCase {
        get { self[UpsertTodoUseCaseKey.self] }
        set { self[UpsertTodoUseCaseKey.self] = newValue }
    }

    var trackAnalyticsEventUseCase: TrackAnalyticsEventUseCase {
        get { self[TrackAnalyticsEventUseCaseKey.self] }
        set { self[TrackAnalyticsEventUseCaseKey.self] = newValue }
    }
}

private enum FetchTodoCategoryPreferencesUseCaseKey: DependencyKey {
    static var liveValue: FetchTodoCategoryPreferencesUseCase {
        preconditionFailure("FetchTodoCategoryPreferencesUseCase must be provided.")
    }

    static var testValue: FetchTodoCategoryPreferencesUseCase {
        liveValue
    }
}

private enum UpsertTodoUseCaseKey: DependencyKey {
    static var liveValue: UpsertTodoUseCase {
        preconditionFailure("UpsertTodoUseCase must be provided.")
    }

    static var testValue: UpsertTodoUseCase {
        liveValue
    }
}

private enum TrackAnalyticsEventUseCaseKey: DependencyKey {
    static var liveValue: TrackAnalyticsEventUseCase {
        preconditionFailure("TrackAnalyticsEventUseCase must be provided.")
    }

    static var testValue: TrackAnalyticsEventUseCase {
        NoOpTrackAnalyticsEventUseCase()
    }
}

private struct NoOpTrackAnalyticsEventUseCase: TrackAnalyticsEventUseCase {
    func execute(_ event: AnalyticsEvent) { }
}

private extension TodoEditorFeature {
    func fetchCategoriesEffect() -> Effect<Action> {
        .run { [fetchPreferencesUseCase] send in
            do {
                let preferences = try await fetchPreferencesUseCase.execute()
                await send(.binding(.set(\.categories, preferences.map(TodoCategoryItem.init(from:)))))
            } catch { }
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

            await send(.binding(.set(\.referenceItems, referenceItems)))
        }
        .cancellable(id: CancelID.resolveMarkdown, cancelInFlight: true)
    }

    func createTodoEffect(_ draft: TodoDraft) -> Effect<Action> {
        .run { [upsertTodoUseCase] send in
            await send(.loading(.begin(target: .default, mode: .immediate)))
            do {
                try await upsertTodoUseCase.execute(draft)
                await send(.createSucceeded)
                await send(.delegate(.created))
            } catch {
                await send(.saveFailed)
            }
            await send(.loading(.end(target: .default, mode: .immediate)))
        }
    }

    func updateTodoEffect(_ todo: Todo) -> Effect<Action> {
        .run { [upsertTodoUseCase] send in
            await send(.loading(.begin(target: .default, mode: .immediate)))
            do {
                try await upsertTodoUseCase.execute(todo)
                await send(.updateSucceeded(todo))
                await send(.delegate(.updated(todo)))
            } catch {
                await send(.saveFailed)
            }
            await send(.loading(.end(target: .default, mode: .immediate)))
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

private extension TodoEditorFeature.State {
    func makeTodoDraft(now: Date) -> TodoDraft {
        TodoDraft(
            id: id,
            isPinned: isPinned,
            isCompleted: isCompleted,
            isChecked: isChecked,
            title: title,
            content: content,
            createdAt: now,
            updatedAt: now,
            completedAt: completedAt,
            dueDate: dueDate,
            tags: Array(tags),
            category: category.category,
            goalId: goalId
        )
    }

    func makeTodo(now: Date) -> Todo? {
        guard let number, let createdAt else { return nil }
        return Todo(
            id: id,
            isPinned: isPinned,
            isCompleted: isCompleted,
            isChecked: isChecked,
            number: number,
            title: title,
            content: content,
            createdAt: createdAt,
            updatedAt: now,
            completedAt: completedAt,
            deletedAt: deletedAt,
            dueDate: dueDate,
            tags: Array(tags),
            category: category.category,
            goalId: goalId
        )
    }
}
