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
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
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
        PaneSplitView {
            TodoListContent(store: store) { todoId in
                if isiOSAppOnMac {
                    store.send(.binding(.set(\.selectedTodoId, todoId)))
                } else {
                    onSelectTodo(todoId)
                }
            }
        } detail: {
            TodoDetailPane(
                todoId: store.selectedTodoId,
                showEditButton: true,
                placeholder: Text("today_select_detail", bundle: PresentationResources.bundle),
                windowEvent: windowEvent
            )
            .id(store.detailRevision)
        }
        .prominentAlert(store, state: \.alert, action: \.alert)
        .onReceive(windowSubmits) { submit in
            switch submit {
            case .create(let value):
                guard value.matchesCreate(category: store.category, source: .list) else { return }
                store.send(.view(.windowTodoCreated))
            case .update:
                // 상세 칸에서 편집한 Todo를 옆 목록에도 반영
                store.send(.view(.windowTodoUpdated))
            }
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
    @Environment(\.windowControlsInset) private var windowControlsInset
    @Environment(\.readableContentWidth) private var readableContentWidth
    @Environment(\.deviceType) private var deviceType
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
                        .frame(maxWidth: readableContentWidth)
                        .frame(maxWidth: .infinity)
                } else {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(
                            Array(zip(visibleTodos.indices, visibleTodos)),
                            id: \.1.id
                        ) { index, todo in
                            let isLast = index == visibleTodos.count - 1

                            TodoItemRow(todo)
                                .background(todo.id == store.selectedTodoId ? Color.primaryContainer : .surface)
                                .contentShape(.rect)
                                .todoDetailPreview(todoId: todo.id)
                                .onTapGesture {
                                    onSelectTodo(todo.id)
                                }
                                .itemActions {
                                    ItemActionButton(
                                        title: todo.isPinned
                                            ? String(localized: "todo_action_unpin", bundle: PresentationResources.bundle) : String(localized: "todo_action_pin", bundle: PresentationResources.bundle),
                                        color: Color.orange,
                                        image: Image(systemName: "star\(todo.isPinned ? ".slash" : ".fill")")
                                    ) {
                                        store.send(.view(.tapTogglePinned(todo)))
                                    }

                                    ItemActionButton(
                                        title: todo.isCompleted
                                            ? String(localized: "todo_action_uncomplete", bundle: PresentationResources.bundle) : String(localized: "todo_action_complete", bundle: PresentationResources.bundle),
                                        color: Color.accent,
                                        image: Image(systemName: todo.isCompleted
                                            ? "arrow.uturn.backward" : "checkmark")
                                    ) {
                                        store.send(.view(.tapToggleCompleted(todo)))
                                    }

                                    ItemActionButton(
                                        title: String(localized: "common_delete", bundle: PresentationResources.bundle),
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
                    .frame(maxWidth: readableContentWidth)
                    .frame(maxWidth: .infinity)
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) { TodoListTopBar(store: store) }
            .refreshable { await store.send(.view(.refresh)).finish() }
            .scrollDisabled(visibleTodos.isEmpty || store.state.isLoading)
            .duoToolbarVisibility()
            .toolbar {
                if deviceType == .duo {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        // 접힌 뒤 펼칠 때 레일 아이콘이 사라지는 현상 방지
                        Group {
                            if !store.isSearching {
                                Button {
                                    withAnimation(.smooth(duration: 0.3)) {
                                        store.send(.view(.setSearching(true)))
                                    }
                                } label: {
                                    Image(systemName: "magnifyingglass")
                                }
                            }
                            Button {
                                store.send(.store(.setFullScreenCover(.editor)))
                            } label: {
                                Image(systemName: "plus")
                            }
                        }
                        .id(windowControlsInset)
                    }
                }
            }

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
    @Environment(\.windowControlsInset) private var windowControlsInset
    @Environment(\.readableContentWidth) private var readableContentWidth
    @Environment(\.showsPaneTitleBar) private var showsPaneTitleBar
    @Environment(\.deviceType) private var deviceType
    @Namespace private var searchTransition
    let store: StoreOf<TodoListFeature>

    var body: some View {
        let title = Text(TodoCategoryItem(from: store.category).localizedName)

        VStack(spacing: 0) {
            if showsPaneTitleBar {
                PaneTitleBar(title) { actions }
            }

            VStack(spacing: 8) {
                if !showsPaneTitleBar {
                    ZStack {
                        title
                            .font(.headline)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)

                        if deviceType != .duo {
                            HStack(spacing: 12) {
                                NavigationBackButton {
                                    dismiss()
                                }

                                Spacer()

                                actions
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }

                if store.isSearching {
                    TodoListSearchBar(store: store, searchTransition: searchTransition)
                        .padding(.horizontal, 16)
                }

                TodoListFilterHeader(store: store)
            }
            .frame(maxWidth: readableContentWidth)
            .frame(maxWidth: .infinity)
            .padding(.top, showsPaneTitleBar ? 12 : windowControlsInset)
            .padding(.bottom, 12)
        }
        .background(Color.appBackground, ignoresSafeAreaEdges: .top)
    }

    @ViewBuilder
    private var actions: some View {
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
                    DropdownMenu(sections: [
                        DropdownMenuSection(
                            String.localizedStringWithFormat(
                                String(
                                    localized: "todo_list_filters_applied_format",
                                    bundle: PresentationResources.bundle
                                ),
                                Int64(store.appliedFilterCount)
                            ),
                            items: [
                                DropdownMenuItem(
                                    String(localized: "todo_list_clear_filters", bundle: PresentationResources.bundle),
                                    systemImage: "xmark",
                                    role: .destructive
                                ) {
                                    store.send(.view(.resetFilters))
                                }
                            ]
                        )
                    ]) {
                        HStack(spacing: 6) {
                            Text("\(store.appliedFilterCount)")
                            Image(systemName: "xmark")
                        }
                        .foregroundStyle(Color.onPrimaryContainer)
                        .adaptiveButtonStyle(color: .primaryContainer)
                    }
                }

                DropdownMenu(sections: [
                    DropdownMenuSection(items: [
                        DropdownMenuItem(
                            String(localized: "todo_pinned", bundle: PresentationResources.bundle),
                            systemImage: "star",
                            isChecked: store.query.isPinned
                        ) {
                            store.send(.binding(.set(\.query.isPinned, !store.query.isPinned)))
                        }
                    ]),
                    DropdownMenuSection(
                        String(localized: "todo_list_completion_status", bundle: PresentationResources.bundle),
                        items: [TodoQuery.CompletionFilter.all, .incomplete, .completed].map { option in
                            DropdownMenuItem(option.title, isChecked: store.query.completionFilter == option) {
                                store.send(.binding(.set(\.query.completionFilter, option)))
                            }
                        }
                    )
                ]) {
                    let condition = store.state.query.isPinned || store.state.query.completionFilter != .all
                    HStack(spacing: 6) {
                        Image(systemName: "line.3.horizontal.decrease")
                        Text(String(localized: "todo_list_filter_options", bundle: PresentationResources.bundle))
                        Image(systemName: "chevron.down")
                    }
                    .foregroundStyle(condition ? Color.onPrimaryContainer : .onControlBackground)
                    .adaptiveButtonStyle(color: condition ? .primaryContainer : .controlBackground)
                }

                DropdownMenu(sections: [
                    DropdownMenuSection(
                        String(localized: "todo_list_sort_by", bundle: PresentationResources.bundle),
                        items: [TodoQuery.SortTarget.createdAt, .updatedAt].map { option in
                            DropdownMenuItem(option.title, isChecked: store.query.sortTarget == option) {
                                store.send(.binding(.set(\.query.sortTarget, option)))
                            }
                        }
                    ),
                    DropdownMenuSection(
                        String(localized: "todo_list_sort_order", bundle: PresentationResources.bundle),
                        items: [TodoQuery.SortOrder.latest, .oldest].map { option in
                            DropdownMenuItem(option.title, isChecked: store.query.sortOrder == option) {
                                store.send(.binding(.set(\.query.sortOrder, option)))
                            }
                        }
                    )
                ]) {
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
