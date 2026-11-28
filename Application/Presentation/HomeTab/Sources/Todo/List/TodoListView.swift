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
    @Environment(\.usesDesktopLayout) private var usesDesktopLayout
    @Environment(\.usesPaneLayout) private var usesPaneLayout
    @State private var store: StoreOf<TodoListFeature>
    private let windowEvent: TodoEditorWindowEvent?

    init(store: StoreOf<TodoListFeature>, windowEvent: TodoEditorWindowEvent? = nil) {
        self.store = store
        self.windowEvent = windowEvent
    }

    var body: some View {
        // 사이드바가 있는 창은 목록을 창 전체 폭으로 두고 오른쪽 칸에서 연 Todo나 작성 화면이 있을 때만 두 칸으로 나눔
        PaneSplitView(splitsOnDesktop: store.showsDetailInPane && store.detail != nil || store.fullScreenCover != nil) {
            TodoListContent(store: store) { todoId in
                store.send(.view(.selectTodo(todoId)))
            }
        } detail: {
            // 칸으로 나눈 화면은 새 Todo를 덮는 화면 대신 상세 칸 자리에서 작성
            if usesPaneLayout,
               let editorStore = store.scope(
                state: \.fullScreenCover?.todoEditor,
                action: \.fullScreenCover.presented.todoEditor
               ) {
                TodoEditorView(store: editorStore, onClose: { store.send(.fullScreenCover(.dismiss)) })
            } else if store.showsDetailInPane,
                      let detailStore = store.scope(state: \.detail, action: \.detail.presented) {
                TodoDetailView(
                    store: detailStore,
                    windowEvent: windowEvent,
                    isPaneDetail: true,
                    onClose: usesDesktopLayout ? { store.send(.detail(.dismiss)) } : nil
                )
                .environment(\.showsPaneTitleBar, true)
                // 칸 안에서 다른 Todo로 바꾸면 그 Todo를 조회
                .id(detailStore.todoId)
            } else {
                PanePlaceholder()
            }
        }
        // 좁은 창은 목록 위에 쌓고, 사이드바가 있는 창은 상세 판이나 오른쪽 칸에 표시
        // 창 폭이 바뀌면 같은 상세 상태를 바뀐 자리에서 이어 그림
        .compositionDetail(
            item: $store.scope(state: \.detail, action: \.detail),
            inPane: store.showsDetailInPane,
            isActive: isTabContentActive
        ) { detailStore in
            TodoDetailView(store: detailStore, windowEvent: windowEvent)
        } panel: { detailStore in
            // 목록에서 빠진 Todo는 지울 경로가 없어 판 메뉴에서 삭제 생략
            let todo = store.todos.first { $0.id == detailStore.todoId }

            TodoDetailPanel(
                store: detailStore,
                location: Text(TodoCategoryItem(from: store.category).localizedName),
                windowEvent: windowEvent,
                onMoveToPane: {
                    store.send(.binding(.set(\.showsDetailInPane, true)))
                },
                onDelete: todo.map { todo in
                    {
                        store.send(.view(.swipeTodo(todo)))
                        presentDeleteTodoToast(todo.id, store: store)
                    }
                }
            )
        }
        // 옆 칸에 연 Todo의 속성은 세부 정보 사이드바에 표시
        .compositionRight(isActive: store.showsDetailInPane && store.detail != nil) {
            if let detailStore = store.scope(state: \.detail, action: \.detail.presented) {
                TodoDetailSideBarView(store: detailStore)
                    .id(detailStore.todoId)
            }
        }
        .prominentAlert(store, state: \.alert, action: \.alert)
        .onReceive(windowSubmits) { _ in
            // 상세 칸에서 편집한 Todo를 옆 목록에도 반영
            store.send(.view(.windowTodoUpdated))
        }
        .compositionEditor(
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
    @Environment(\.usesDesktopLayout) private var usesDesktopLayout
    @Environment(\.usesPaneLayout) private var usesPaneLayout
    @Environment(\.windowControlsInset) private var windowControlsInset
    @Environment(\.readableContentWidth) private var readableContentWidth
    @Environment(\.deviceType) private var deviceType
    let store: StoreOf<TodoListFeature>
    let onSelectTodo: (String) -> Void

    var body: some View {
        let visibleTodos = store.state.todos.filter { !$0.isHidden }

        ZStack {
            ScrollViewReader { proxy in
                ScrollView {
                    if visibleTodos.isEmpty, !store.state.isLoading {
                        EmptyStateView(
                            String(localized: "todo_list_empty", bundle: PresentationResources.bundle),
                            systemImage: "checklist"
                        )
                    } else {
                        // 칸으로 나누지 않은 화면은 상세 칸이 없어 선택 표시 생략
                        let highlightedTodoIds = (
                            [store.hoveredTodoId] + (usesPaneLayout ? [store.detail?.todoId] : [])
                        ).compactMap { $0 }

                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(
                                Array(zip(visibleTodos.indices, visibleTodos)),
                                id: \.1.id
                            ) { index, todo in
                                let isLast = index == visibleTodos.count - 1
                                let isHighlighted = highlightedTodoIds.contains(todo.id)
                                let isNextHighlighted = !isLast && highlightedTodoIds.contains(visibleTodos[index + 1].id)

                                // Mac은 둥근 선택·마우스 표시와 맞닿는 구분선 숨김
                                TodoItemRow(
                                    todo,
                                    showsSeparator: !(isiOSAppOnMac && (isHighlighted || isNextHighlighted))
                                )
                                    // 선택·마우스 표시는 같은 회색, Mac은 Orca 데스크톱처럼 둥근 사각형
                                    // 반투명 선택 색 아래로 행 동작 버튼이 비치지 않도록 불투명 바탕 위에 표시
                                    .background(
                                        isHighlighted ? Color.fill : .clear,
                                        in: .rect(cornerRadius: isiOSAppOnMac ? CornerRadius.control : 0)
                                    )
                                    .background(Color.background)
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
                                        // 사이드바가 있는 창의 우클릭과 길게 누른 메뉴는 상세 판과 오른쪽 칸으로 여는 항목을 맨 위에 표시
                                        if usesDesktopLayout {
                                            Button {
                                                store.send(.view(.openTodo(todo.id, inPane: false)))
                                            } label: {
                                                Label {
                                                    Text("detail_panel_open", bundle: PresentationResources.bundle)
                                                } icon: {
                                                    Image(systemName: "doc.text")
                                                }
                                            }
                                            Button {
                                                store.send(.view(.openTodo(todo.id, inPane: true)))
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
                                            color: Color.important,
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

                                        if usesDesktopLayout {
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
                                    .onAppear {
                                        if isLast, store.state.hasMore {
                                            store.send(.view(.loadNextPage))
                                        }
                                    }
                            }
                        }
                        .background(Color.background)
                        .clipShape(.rect)
                        // Mac은 둥근 선택·마우스 표시가 칸 가장자리에 붙지 않도록 좌우 여백 표시
                        .padding(.horizontal, isiOSAppOnMac ? 16 : 0)
                        .frame(maxWidth: readableContentWidth)
                        .frame(maxWidth: .infinity)
                    }
                }
                .safeAreaInset(edge: .top, spacing: 0) { TodoListTopBar(store: store) }
                .refreshable { await store.send(.view(.refresh)).finish() }
                .scrollDisabled(visibleTodos.isEmpty || store.state.isLoading)
                // 필터, 정렬, 검색어가 바뀌면 이전 스크롤 위치에 남지 않도록 새 목록을 맨 위부터 표시
                .onChange(of: store.query) {
                    if let id = visibleTodos.first?.id {
                        proxy.scrollTo(id, anchor: .top)
                    }
                }
                .duoToolbarVisibility(showsBackButton: true)
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
                        .sharedBackgroundHidden()
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
    @Environment(\.windowControlsInset) private var windowControlsInset
    @Environment(\.readableContentWidth) private var readableContentWidth
    @Environment(\.showsPaneTitleBar) private var showsPaneTitleBar
    @Environment(\.deviceType) private var deviceType
    @Environment(\.sideBarRequest) private var sideBarRequest
    @Namespace private var searchTransition
    let store: StoreOf<TodoListFeature>

    var body: some View {
        let title = Text(TodoCategoryItem(from: store.category).localizedName)

        VStack(spacing: 0) {
            if showsPaneTitleBar {
                PaneTitleBar(title, onBack: { dismiss() }) {
                    TodoListPaneMenus(store: store)
                    actions
                }
            }

            // 사이드바가 있는 창의 칸 제목 줄은 필터와 정렬을 버튼으로 옮겨 검색 중일 때만 아래 줄 표시
            if !showsPaneTitleBar || store.isSearching {
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

                    if !showsPaneTitleBar {
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
            store.send(.store(.setFullScreenCover(.editor)))
        }
    }

    @ViewBuilder
    private var actions: some View {
        if !store.isSearching {
            Button {
                withAnimation(.smooth(duration: 0.3)) {
                    store.send(.view(.setSearching(true)))
                }
            } label: {
                Image(systemName: "magnifyingglass")
            }
            .topBarButtonStyle()
            .matchedGeometryEffect(id: "todo-search", in: searchTransition)
        }

        Button {
            store.send(.store(.setFullScreenCover(.editor)))
        } label: {
            Image(systemName: "plus")
        }
        .topBarButtonStyle()
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
                color: .secondaryBackground
            )
            .matchedGeometryEffect(id: "todo-search", in: searchTransition)

            Button {
                isSearchFocused = false
                withAnimation(.smooth(duration: 0.3)) {
                    store.send(.view(.setSearching(false)))
                }
            } label: {
                Text(String(localized: "common_cancel", bundle: PresentationResources.bundle))
                    .foregroundStyle(Color.label)
            }
            .buttonStyle(.plain)
        }
    }
}

private struct TodoListFilterHeader: View {
    @Bindable var store: StoreOf<TodoListFeature>

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
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
                        HStack(spacing: 5) {
                            Text("\(store.appliedFilterCount)")
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .font(.adaptive(.footnote))
                        .foregroundStyle(Color.label)
                        .padding(.horizontal, 12)
                        .frame(height: 34)
                        .background(Color.tertiaryBackground, in: .rect(cornerRadius: CornerRadius.control))
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
                    TodoListFilterChip(
                        title: String(localized: "todo_list_filter_options", bundle: PresentationResources.bundle),
                        systemImage: "line.3.horizontal.decrease",
                        isActive: store.state.query.isPinned || store.state.query.completionFilter != .all
                    )
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
                    TodoListFilterChip(
                        title: String(localized: "todo_list_sort_by", bundle: PresentationResources.bundle),
                        systemImage: "arrow.up.arrow.down",
                        isActive: store.state.query.sortTarget != .createdAt || store.state.query.sortOrder != .latest
                    )
                }
            }
        }
        .scrollIndicators(.hidden)
        .fixedSize(horizontal: false, vertical: true)
        .contentMargins(.horizontal, 16, for: .scrollContent)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// 필터와 정렬 메뉴를 여는 칩, 기본값에서 바꾼 조건은 회색 바탕으로 표시
private struct TodoListFilterChip: View {
    let title: String
    let systemImage: String
    let isActive: Bool

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .medium))
            Text(title)
            Image(systemName: "chevron.down")
                .font(.system(size: 10, weight: .semibold))
        }
        .font(.adaptive(.footnote))
        .foregroundStyle(Color.label)
        .padding(.horizontal, 12)
        .frame(height: 34)
        .background(isActive ? Color.tertiaryBackground : .clear, in: .rect(cornerRadius: CornerRadius.control))
        .overlay {
            RoundedRectangle(cornerRadius: CornerRadius.control).strokeBorder(isActive ? Color.clear : .separator)
        }
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
