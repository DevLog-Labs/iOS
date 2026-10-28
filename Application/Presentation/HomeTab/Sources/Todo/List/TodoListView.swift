//
//  TodoListView.swift
//  HomeTab
//
//  Created by opfic on 5/30/25.
//

import SwiftUI
import Combine
import ComposableArchitecture
import Core
import PresentationShared

struct TodoListView: View {
    @Environment(\.isTabContentActive) private var isTabContentActive
    @State private var store: StoreOf<TodoListFeature>
    private let windowEvent: TodoEditorWindowEvent?
    private let onSelectTodo: (String) -> Void

    init(
        store: StoreOf<TodoListFeature>,
        windowEvent: TodoEditorWindowEvent? = nil,
        onSelectTodo: @escaping (String) -> Void = { _ in }
    ) {
        self.store = store
        self.windowEvent = windowEvent
        self.onSelectTodo = onSelectTodo
    }

    var body: some View {
        TodoListContent(store: store, onSelectTodo: onSelectTodo)
            .prominentAlert(store, state: \.alert, action: \.alert)
            .onReceive(windowSubmits) { submit in
                guard case .create(let value) = submit,
                      value.matchesCreate(category: store.category, source: .list) else { return }
                store.send(.view(.windowTodoCreated))
            }
            .fullScreenCover(
                item: $store.scope(state: \.fullScreenCover, action: \.fullScreenCover)
                    .activePresentation(when: isTabContentActive)
            ) { coverStore in
                fullScreenCoverContent(coverStore)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .task { store.send(.view(.onAppear)) }
    }

    private var windowSubmits: AnyPublisher<TodoEditorWindowSubmit, Never> {
        windowEvent?.submits ?? Empty().eraseToAnyPublisher()
    }

    @ViewBuilder
    private func fullScreenCoverContent(
        _ coverStore: Store<
        TodoListFeature.FullScreenCoverState,
        TodoListFeature.Action.FullScreenCover>
    ) -> some View {
        switch coverStore.destination {
        case .editor:
            if let todoEditorStore = coverStore.scope(state: \.todoEditor, action: \.todoEditor) {
                TodoEditorView(store: todoEditorStore)
            }
        }
    }
}

private struct TodoListContent: View {
    let store: StoreOf<TodoListFeature>
    let onSelectTodo: (String) -> Void

    var body: some View {
        let visibleTodos = store.state.todos.filter { !$0.isHidden }

        ZStack {
            ScrollView {
                if visibleTodos.isEmpty, !store.state.isLoading {
                    Text(String(localized: "todo_list_empty", bundle: PresentationResources.bundle))
                        .font(.callout)
                        .foregroundStyle(Color.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32)
                        .background(Color.surface, in: .rect(cornerRadius: 16))
                        .padding(.horizontal, 16)
                } else {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(
                            Array(zip(visibleTodos.indices, visibleTodos)),
                            id: \.1.id
                        ) { index, todo in
                            let isLast = index == visibleTodos.count - 1

                            TodoItemRow(todo)
                                .background(Color.surface)
                                .contentShape(.rect)
                                .todoDetailPreview(todoId: todo.id)
                                .onTapGesture {
                                    onSelectTodo(todo.id)
                                }
                                .itemActions {
                                    ItemActionButton(
                                        color: Color.orange,
                                        image: Image(systemName: "star\(todo.isPinned ? ".slash" : ".fill")")
                                    ) {
                                        store.send(.view(.tapTogglePinned(todo)))
                                    }

                                    ItemActionButton(
                                        color: Color.accent,
                                        image: Image(systemName: todo.isCompleted
                                            ? "arrow.uturn.backward" : "checkmark")
                                    ) {
                                        store.send(.view(.tapToggleCompleted(todo)))
                                    }

                                    ItemActionButton(
                                        color: Color.red,
                                        image: Image(systemName: "trash")
                                    ) {
                                        store.send(.view(.swipeTodo(todo)))
                                        presentDeleteTodoToast(todo.id)
                                    }
                                }
                                .overlay(alignment: .bottom) {
                                    if !isLast {
                                        Divider()
                                    }
                                }
                                .onAppear {
                                    if isLast, store.state.hasMore {
                                        store.send(.view(.loadNextPage))
                                    }
                                }
                        }
                    }
                    .background(Color.surface)
                    .clipShape(.rect(cornerRadius: 16))
                    .padding(.horizontal, 16)
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) { TodoListTopBar(store: store) }
            .refreshable { await store.send(.view(.refresh)).finish() }
            .scrollDisabled(visibleTodos.isEmpty || store.state.isLoading)
            .toolbarVisibility(.hidden, for: .navigationBar)

            if store.state.isLoading {
                LoadingView()
            }
        }
    }

    private func presentDeleteTodoToast(_ todoId: String) {
        ToastPresenter.present(
            duration: 5,
            action: {
                store.send(.view(.undoDelete))
            },
            onDismiss: {
                store.send(.view(.finishDeleteToast(todoId)))
            }
        ) {
            ToastLabel()
        }
    }
}

private struct TodoListTopBar: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openWindow) private var openWindow
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
    @Namespace private var searchTransition
    let store: StoreOf<TodoListFeature>

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Text(TodoCategoryItem(from: store.category).localizedName)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                HStack(spacing: 12) {
                    NavigationBackButton {
                        dismiss()
                    }

                    Spacer()

                    if !store.isSearching {
                        if #available(iOS 26.0, *) {
                            Button {
                                withAnimation(.smooth(duration: 0.3)) {
                                    store.send(.view(.setSearching(true)))
                                }
                            } label: {
                                Image(systemName: "magnifyingglass")
                            }
                            .topBarButtonStyle()
                            .matchedGeometryEffect(id: "todo-search", in: searchTransition)
                        } else {
                            Button {
                                withAnimation(.smooth(duration: 0.3)) {
                                    store.send(.view(.setSearching(true)))
                                }
                            } label: {
                                Image(systemName: "magnifyingglass")
                                    .font(.title3.weight(.semibold))
                                    .frame(width: 28, height: 28)
                            }
                            .adaptiveButtonStyle(
                                shape: .circle,
                                color: .surface,
                                glassEffect: .enabled
                            )
                            .matchedGeometryEffect(id: "todo-search", in: searchTransition)
                        }
                    }

                    if #available(iOS 26.0, *) {
                        Button {
                            openTodoEditor()
                        } label: {
                            Image(systemName: "plus")
                        }
                        .topBarButtonStyle()
                    } else {
                        Button {
                            openTodoEditor()
                        } label: {
                            Image(systemName: "plus")
                                .font(.title3.weight(.semibold))
                                .frame(width: 28, height: 28)
                        }
                        .adaptiveButtonStyle(
                            shape: .circle,
                            color: .surface,
                            glassEffect: .enabled
                        )
                    }
                }
            }
            .padding(.horizontal, 16)

            if store.isSearching {
                TodoListSearchBar(store: store, searchTransition: searchTransition)
                    .padding(.horizontal, 16)
            }

            TodoListFilterHeader(store: store)
        }
        .padding(.bottom, 12)
        .background(Color.appBackground, ignoresSafeAreaEdges: .top)
    }

    private func openTodoEditor() {
        if isiOSAppOnMac {
            openWindow(
                id: TodoEditorWindowValue.sceneId,
                value: TodoEditorWindowValue(todoCategory: store.category, source: .list)
            )
        } else {
            store.send(.store(.setFullScreenCover(.editor)))
        }
    }
}

private struct TodoListSearchBar: View {
    @FocusState private var isSearchFocused: Bool
    @Bindable var store: StoreOf<TodoListFeature>
    let searchTransition: Namespace.ID

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Color.textSecondary)
                TextField(
                    "",
                    text: $store.searchQuery,
                    prompt: Text(String(
                        localized: "search_prompt",
                        bundle: PresentationResources.bundle
                    ))
                    .foregroundStyle(Color.textSecondary)
                )
                .focused($isSearchFocused)
                .task {
                    await Task.yield()
                    isSearchFocused = true
                }
                if !store.searchQuery.isEmpty {
                    Button {
                        store.send(.binding(.set(\.searchQuery, "")))
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity)
            .adaptiveButtonStyle(
                shape: Capsule(),
                color: .surface,
                glassEffect: .enabled
            )
            .matchedGeometryEffect(id: "todo-search", in: searchTransition)

            Button {
                isSearchFocused = false
                withAnimation(.smooth(duration: 0.3)) {
                    store.send(.view(.setSearching(false)))
                }
            } label: {
                Text(String(localized: "common_cancel", bundle: PresentationResources.bundle))
                    .foregroundStyle(Color.accent)
            }
            .buttonStyle(.plain)
        }
    }
}

private struct TodoListFilterHeader: View {
    @Bindable var store: StoreOf<TodoListFeature>

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                if 0 < store.appliedFilterCount {
                    Menu {
                        Text(
                            String.localizedStringWithFormat(
                                String(
                                    localized: "todo_list_filters_applied_format",
                                    bundle: PresentationResources.bundle
                                ),
                                Int64(store.appliedFilterCount)
                            )
                        )
                        Button(role: .destructive) {
                            store.send(.view(.resetFilters))
                        } label: {
                            Text(String(localized: "todo_list_clear_filters", bundle: PresentationResources.bundle))
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text("\(store.appliedFilterCount)")
                            Image(systemName: "xmark")
                        }
                        .foregroundStyle(Color.onPrimaryContainer)
                        .adaptiveButtonStyle(color: .primaryContainer)
                    }
                }

                Menu {
                    Toggle(isOn: $store.query.isPinned) {
                        Text(String(localized: "todo_pinned", bundle: PresentationResources.bundle))
                    }

                    Picker(selection: $store.query.completionFilter) {
                        ForEach([TodoQuery.CompletionFilter.all, .incomplete, .completed], id: \.self) { option in
                            Text(option.title).tag(option)
                        }
                    } label: {
                        Text(String(localized: "todo_list_completion_status", bundle: PresentationResources.bundle))
                    }
                } label: {
                    let condition = store.state.query.isPinned || store.state.query.completionFilter != .all
                    HStack(spacing: 6) {
                        Image(systemName: "line.3.horizontal.decrease")
                        Text(String(localized: "todo_list_filter_options", bundle: PresentationResources.bundle))
                        Image(systemName: "chevron.down")
                    }
                    .foregroundStyle(condition ? Color.onPrimaryContainer : .onControlBackground)
                    .adaptiveButtonStyle(color: condition ? .primaryContainer : .controlBackground)
                }

                Menu {
                    Picker(selection: $store.query.sortTarget) {
                        ForEach([TodoQuery.SortTarget.createdAt, .updatedAt], id: \.self) { option in
                            Text(option.title).tag(option)
                        }
                    } label: {
                        Text(String(localized: "todo_list_sort_by", bundle: PresentationResources.bundle))
                    }
                    Picker(selection: $store.query.sortOrder) {
                        ForEach([TodoQuery.SortOrder.latest, .oldest], id: \.self) { option in
                            Text(option.title).tag(option)
                        }
                    } label: {
                        Text(String(localized: "todo_list_sort_order", bundle: PresentationResources.bundle))
                    }
                } label: {
                    let condition = store.state.query.sortTarget == .createdAt && store.state.query.sortOrder == .latest
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.arrow.down")
                        Text(String(localized: "todo_list_sort_by", bundle: PresentationResources.bundle))
                        Image(systemName: "chevron.down")
                    }
                    .foregroundStyle(condition ? Color.onControlBackground : .onPrimaryContainer)
                    .adaptiveButtonStyle(color: condition ? .controlBackground : .primaryContainer)
                }
            }
        }
        .scrollIndicators(.hidden)
        .fixedSize(horizontal: false, vertical: true)
        .contentMargins(.horizontal, 16, for: .scrollContent)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ToastLabel: View {
    var body: some View {
        Label {
            Text(String(localized: "todo_list_delete_toast_message", bundle: PresentationResources.bundle))
                .foregroundStyle(.primary)
        } icon: {
            Image(systemName: "arrow.uturn.backward.circle.fill")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color.accent)
            }
    }
}
