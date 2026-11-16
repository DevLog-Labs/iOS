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
    @Environment(\.usesPaneLayout) private var usesPaneLayout
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
        // Mac은 목록을 창 전체 폭으로 두고 오른쪽 칸에서 연 Todo가 있을 때만 두 칸으로 나눔
        PaneSplitView(splitsOnDesktop: !isiOSAppOnMac || store.selectedTodoId != nil) {
            TodoListContent(store: store) { todoId in
                // Mac은 오른쪽 칸을 열지 않았으면 상세 판으로 열고 열었으면 오른쪽 칸 내용을 바꿈
                if isiOSAppOnMac && store.selectedTodoId == nil {
                    store.send(.binding(.set(\.panelTodo, TodoIdItem(id: todoId))))
                    return
                }
                // 칸 화면으로 바뀌면 같은 Todo를 옆 칸에 표시하도록 칸으로 나누지 않은 화면에서도 선택 기억
                store.send(.binding(.set(\.selectedTodoId, todoId)))
                if !usesPaneLayout {
                    onSelectTodo(todoId)
                }
            }
        } detail: {
            TodoDetailPane(
                todoId: store.selectedTodoId,
                showEditButton: true,
                windowEvent: windowEvent,
                onClose: isiOSAppOnMac ? { store.send(.binding(.set(\.selectedTodoId, nil))) } : nil
            )
            .id(store.detailRevision)
        }
        .detailPanel(item: $store.panelTodo.activePresentation(when: isTabContentActive)) { item in
            // 목록에서 빠진 Todo는 지울 경로가 없어 판 메뉴에서 삭제 생략
            let todo = store.todos.first { $0.id == item.id }

            TodoDetailPanel(
                todoId: item.id,
                location: Text(TodoCategoryItem(from: store.category).localizedName),
                isEditable: true,
                windowEvent: windowEvent,
                onMoveToPane: {
                    store.send(.binding(.set(\.panelTodo, nil)))
                    store.send(.binding(.set(\.selectedTodoId, item.id)))
                },
                onDelete: todo.map { todo in
                    {
                        store.send(.binding(.set(\.panelTodo, nil)))
                        store.send(.view(.swipeTodo(todo)))
                        presentDeleteTodoToast(todo.id, store: store)
                    }
                }
            )
        }
        .detailSideBarTarget(
            store.selectedTodoId.map { .todo(id: $0, isEditable: true, revision: store.detailRevision) }
        )
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
        .background(Color.background.ignoresSafeArea())
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
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
    @Environment(\.usesPaneLayout) private var usesPaneLayout
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
                    EmptyStateView(
                        String(localized: "todo_list_empty", bundle: PresentationResources.bundle),
                        systemImage: "checklist"
                    )
                } else {
                    // 칸으로 나누지 않은 화면은 상세 칸이 없어 선택 표시 생략
                    let highlightedTodoIds = (
                        [store.hoveredTodoId] + (usesPaneLayout ? [store.selectedTodoId, store.panelTodo?.id] : [])
                    ).compactMap { $0 }

                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(
                            Array(zip(visibleTodos.indices, visibleTodos)),
                            id: \.1.id
                        ) { index, todo in
                            let isLast = index == visibleTodos.count - 1
                            let isHighlighted = highlightedTodoIds.contains(todo.id)
                            let isNextHighlighted = !isLast && highlightedTodoIds.contains(visibleTodos[index + 1].id)

                            TodoItemRow(todo)
                                // 선택·마우스 표시는 같은 회색, Mac은 Orca 데스크톱처럼 둥근 사각형
                                // 반투명 선택 색 아래로 행 동작 버튼이 비치지 않도록 불투명 바탕 위에 표시
                                .background(
                                    isHighlighted ? Color.fill : .clear,
                                    in: .rect(cornerRadius: isiOSAppOnMac ? CornerRadius.control : 0)
                                )
                                .background(Color.secondaryBackground)
                                .contentShape(.rect)
                                .onHover { isHovering in
                                    guard isiOSAppOnMac else { return }
                                    // 다른 행으로 옮겨 간 뒤에 온 벗어남은 무시
                                    if isHovering {
                                        store.send(.binding(.set(\.hoveredTodoId, todo.id)))
                                    } else if store.hoveredTodoId == todo.id {
                                        store.send(.binding(.set(\.hoveredTodoId, nil)))
                                    }
                                }
                                .todoDetailPreview(todoId: todo.id)
                                .onTapGesture {
                                    onSelectTodo(todo.id)
                                }
                                .itemActions {
                                    // Mac 우클릭 메뉴는 상세 판과 오른쪽 칸으로 여는 항목을 맨 위에 표시
                                    if isiOSAppOnMac {
                                        Button {
                                            store.send(.binding(.set(\.panelTodo, TodoIdItem(id: todo.id))))
                                        } label: {
                                            Label {
                                                Text("detail_panel_open", bundle: PresentationResources.bundle)
                                            } icon: {
                                                Image(systemName: "doc.text")
                                            }
                                        }
                                        Button {
                                            store.send(.binding(.set(\.selectedTodoId, todo.id)))
                                        } label: {
                                            Label {
                                                Text("detail_panel_open_in_pane", bundle: PresentationResources.bundle)
                                            } icon: {
                                                Image(systemName: "sidebar.left")
                                            }
                                        }
                                        Divider()
                                    }

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

                                    if isiOSAppOnMac {
                                        Divider()
                                    }

                                    ItemActionButton(
                                        title: String(localized: "common_delete", bundle: PresentationResources.bundle),
                                        color: Color.red,
                                        image: Image(systemName: "trash")
                                    ) {
                                        store.send(.view(.swipeTodo(todo)))
                                        presentDeleteTodoToast(todo.id, store: store)
                                    }
                                }
                                .overlay(alignment: .bottom) {
                                    // Mac은 둥근 선택·마우스 표시와 맞닿는 구분선 숨김
                                    if !isLast && !(isiOSAppOnMac && (isHighlighted || isNextHighlighted)) {
                                        Divider().overlay(Color.secondarySeparator)
                                    }
                                }
                                .onAppear {
                                    if isLast, store.state.hasMore {
                                        store.send(.view(.loadNextPage))
                                    }
                                }
                        }
                    }
                    .background(Color.secondaryBackground)
                    .clipShape(.rect)
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
}

// 목록 행과 상세 판에서 지운 Todo를 되돌리는 토스트
@MainActor
private func presentDeleteTodoToast(_ todoId: String, store: StoreOf<TodoListFeature>) {
    ToastPresenter.present(
        message: String(localized: "todo_list_delete_toast_message", bundle: PresentationResources.bundle),
        systemImage: "arrow.uturn.backward",
        duration: 5,
        action: {
            store.send(.view(.undoDelete))
        },
        onDismiss: {
            store.send(.view(.finishDeleteToast(todoId)))
        }
    )
}

private struct TodoListTopBar: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openWindow) private var openWindow
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
    @Environment(\.windowControlsInset) private var windowControlsInset
    @Environment(\.readableContentWidth) private var readableContentWidth
    @Environment(\.usesDesktopLayout) private var usesDesktopLayout
    @Environment(\.showsPaneTitleBar) private var showsPaneTitleBar
    @Environment(\.deviceType) private var deviceType
    @Environment(\.sideBarRequest) private var sideBarRequest
    @Namespace private var searchTransition
    let store: StoreOf<TodoListFeature>

    var body: some View {
        let title = Text(TodoCategoryItem(from: store.category).localizedName)
        // Duo 펼침 칸은 디자인대로 제목 줄 아래 필터 줄 유지
        let usesPaneMenus = showsPaneTitleBar && usesDesktopLayout

        VStack(spacing: 0) {
            if showsPaneTitleBar {
                PaneTitleBar(title, onBack: { dismiss() }) {
                    if usesPaneMenus {
                        TodoListPaneMenus(store: store)
                    }
                    actions
                }
            }

            // 사이드바가 있는 창의 칸 제목 줄은 필터와 정렬을 버튼으로 옮겨 검색 중일 때만 아래 줄 표시
            if !usesPaneMenus || store.isSearching {
                VStack(spacing: 8) {
                    if !showsPaneTitleBar {
                        ZStack {
                            title
                                .font(.adaptive(.headline))
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

                    if !usesPaneMenus {
                        TodoListFilterHeader(store: store)
                    }
                }
                .frame(maxWidth: readableContentWidth)
                .frame(maxWidth: .infinity)
                .padding(.top, showsPaneTitleBar ? 12 : windowControlsInset)
                .padding(.bottom, 12)
            }
        }
        .background(Color.background, ignoresSafeAreaEdges: .top)
        // 사이드바 Todo 메뉴의 작성은 이 목록의 작성 버튼과 같은 방식으로 작성
        .onChange(of: sideBarRequest) { _, request in
            guard request?.action == .createTodo else { return }
            openTodoEditor()
        }
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
                        .font(.adaptive(.title3).weight(.semibold))
                        .frame(width: 28, height: 28)
                }
                .adaptiveButtonStyle(
                    shape: .circle,
                    color: .secondaryBackground,
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
                    .font(.adaptive(.title3).weight(.semibold))
                    .frame(width: 28, height: 28)
            }
            .adaptiveButtonStyle(
                shape: .circle,
                color: .secondaryBackground,
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
                    .foregroundStyle(Color.secondaryLabel)
                TextField(
                    "",
                    text: $store.searchQuery,
                    prompt: Text(String(
                        localized: "search_prompt",
                        bundle: PresentationResources.bundle
                    ))
                    .foregroundStyle(Color.secondaryLabel)
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
                            .foregroundStyle(Color.secondaryLabel)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity)
            .adaptiveButtonStyle(
                shape: RoundedRectangle(cornerRadius: CornerRadius.control),
                color: .secondaryBackground,
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
                        .foregroundStyle(Color.tintLabel)
                        .adaptiveButtonStyle(color: .tintFill)
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
                    .foregroundStyle(condition ? Color.tintLabel : .fillLabel)
                    .adaptiveButtonStyle(color: condition ? .tintFill : .fill)
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
                    .foregroundStyle(condition ? Color.fillLabel : .tintLabel)
                    .adaptiveButtonStyle(color: condition ? .fill : .tintFill)
                }
            }
        }
        .scrollIndicators(.hidden)
        .fixedSize(horizontal: false, vertical: true)
        .contentMargins(.horizontal, 16, for: .scrollContent)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// 칸 제목 줄의 필터와 정렬 버튼
private struct TodoListPaneMenus: View {
    let store: StoreOf<TodoListFeature>

    var body: some View {
        let clear = DropdownMenuItem(
            String(localized: "todo_list_clear_filters", bundle: PresentationResources.bundle),
            systemImage: "xmark",
            role: .destructive
        ) {
            store.send(.view(.resetFilters))
        }

        PaneMenuButton(
            systemImage: "line.3.horizontal.decrease",
            badgeCount: store.appliedFilterCount,
            sections: [
                DropdownMenuSection(items: [
                    DropdownMenuItem(
                        String(localized: "todo_list_pinned_only", bundle: PresentationResources.bundle),
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
                ),
                // 걸린 필터가 있을 때만 마지막 항목으로 표시
                DropdownMenuSection(items: 0 < store.appliedFilterCount ? [clear] : [])
            ]
        )

        PaneMenuButton(
            systemImage: "arrow.up.arrow.down",
            sections: [
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
            ]
        )
    }
}
