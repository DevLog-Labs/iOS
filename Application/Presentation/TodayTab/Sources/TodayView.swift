//
//  TodayView.swift
//  TodayTab
//
//  Created by opfic on 3/6/26.
//

import SwiftUI
import Combine
import Core
import Domain
import PresentationShared

public struct TodayView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.usesDesktopLayout) private var usesDesktopLayout
    @Environment(\.usesPaneLayout) private var usesPaneLayout
    @Environment(\.windowControlsInset) private var windowControlsInset
    @Environment(\.readableContentWidth) private var readableContentWidth
    @Environment(\.setDetailSideBarPresented) private var setDetailSideBarPresented
    @State private var router = NavigationRouter<TodayRoute>()
    @State private var store: StoreOf<TodayFeature>
    private let isSelected: Bool
    private let windowEvent: TodoEditorWindowEvent

    public init(
        isSelected: Bool,
        windowEvent: TodoEditorWindowEvent
    ) {
        self._store = State(initialValue: Store(
            initialState: TodayFeature.State()
        ) {
            TodayFeature()
        })
        self.isSelected = isSelected
        self.windowEvent = windowEvent
    }

    public var body: some View {
        NavigationStack(path: $router.path) {
            let sections = store.sections
            PaneSplitView {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        TodayAchievementCard(store: store)
                            .padding(.bottom, 8)

                        if sections.isEmpty, !store.isLoading {
                            TodayEmptyContent(store: store)
                        } else {
                            ForEach(sections) { section in
                                TodoSection(
                                    section: section,
                                    isNavigationEnabled: !store.isTodoInspectorPresented,
                                    // 칸으로 나누지 않은 화면은 상세 칸이 없어 선택 표시 생략
                                    selectedTodoId: usesPaneLayout ? store.selectedTodoId : nil,
                                    onSelect: { item in
                                        if usesPaneLayout {
                                            store.send(.binding(.set(\.selectedTodoId, item.id)))
                                        } else {
                                            router.push(.todo(TodoIdItem(id: item.id)))
                                        }
                                    },
                                    onInspect: { item in
                                        // 사이드바가 있으면 고른 Todo를 창 오른쪽 세부 정보 사이드바에 표시
                                        if usesDesktopLayout {
                                            store.send(.binding(.set(\.selectedTodoId, item.id)))
                                            setDetailSideBarPresented?(true)
                                        } else {
                                            store.send(.showTodoInspector(item))
                                        }
                                    }
                                )
                                .padding(.bottom, section.id == sections.last?.id ? 0 : 8)
                            }
                            .padding(.bottom, 12)
                        }
                    }
                    .padding(.horizontal)
                    // 사이드바가 있으면 필터 줄 없이 제목 줄 바로 아래에서 시작
                    .padding(.top, usesDesktopLayout ? 4 * AdaptiveSize.boardScale : 0)
                    .frame(maxWidth: readableContentWidth)
                    .frame(maxWidth: .infinity)
                }
                .safeAreaInset(edge: .top, spacing: 0) {
                    let title = Text(String(localized: "nav_today", bundle: PresentationResources.bundle))

                    VStack(spacing: 0) {
                        if usesDesktopLayout {
                            PaneTitleBar(title) {
                                TodayFilterMenu(store: store)
                            }
                        } else {
                            if usesPaneLayout {
                                PaneTitleBar(title)
                            }
                            VStack(alignment: .leading) {
                                if !usesPaneLayout {
                                    title
                                        .font(.adaptive(.largeTitle).bold())
                                        .padding(.bottom, 8)
                                }
                                TodayFilterBar(store: store)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                            .frame(maxWidth: readableContentWidth)
                            .padding(.top, usesPaneLayout ? 12 : windowControlsInset)
                            .padding(.bottom, 8)
                        }
                    }
                    .background(Color.background)
                    .toolbarBackground(Color.background)
                }
                .background(Color.background)
                .refreshable { await store.send(.refresh).finish() }
                .duoToolbarVisibility()
            } detail: {
                let item = sections.flatMap(\.items).first { $0.id == store.selectedTodoId }
                // 목록에서 빠진 Todo는 선택 안내로 대체
                TodoDetailPane(
                    todoId: item?.id,
                    showEditButton: true,
                    windowEvent: windowEvent
                )
                // 인스펙터 등에서 목록 행이 바뀌면 상세 칸도 다시 조회
                .id(item?.updatedAt)
            }
            .detailSideBarTarget(
                sections.flatMap(\.items)
                    .first { $0.id == store.selectedTodoId }
                    .map { .todo(id: $0.id, isEditable: true) }
            )
            .navigationDestination(
                for: TodayRoute.self,
                interactivePop: { _ in true },
                destination: { destination($0).environment(\.showsPaneTitleBar, usesPaneLayout) }
            )
        }
        // 사이드바 구조로 바뀌면 쌓아 연 상세 화면은 내리고 같은 Todo를 옆 칸에 표시
        .closesPushedDetail {
            guard case .todo(let item)? = router.path.last else { return }
            store.send(.binding(.set(\.selectedTodoId, item.id)))
            router.path = []
        }
        // 사이드바가 있으면 창 오른쪽 세부 정보 사이드바, 좁은 화면과 Duo 펼침은 직접 그린 시트로 표시
        .prominentSheet(
            isPresented: usesDesktopLayout ? .constant(false) : $store.isTodoInspectorPresented
        ) {
            TodayTodoInspector(store: store, showsCloseButton: true)
        }
        // 사이드바 구조로 바뀌면 가려진 세부 정보 시트는 고친 값을 저장하고 닫아 같은 Todo를 세부 정보 사이드바에 표시
        .onChange(of: usesDesktopLayout) { _, usesDesktopLayout in
            if usesDesktopLayout && store.isTodoInspectorPresented {
                store.send(.moveTodoInspectorToSideBar)
                setDetailSideBarPresented?(true)
            }
        }
        // 상단 safe area 배경
        .background(Color.background)
        .onChange(of: isSelected, initial: true) { _, isSelected in
            if isSelected {
                store.send(.fetchData)
            }
        }
        .onChange(of: scenePhase) { _, scenePhase in
            if scenePhase == .active, isSelected {
                store.send(.checkCurrentDate(Date()))
            }
        }
        .task(id: isSelected) {
            guard isSelected else { return }
            await monitorDateChanges()
        }
        .onReceive(windowEvent.submits) { submit in
            // 상세 칸에서 편집한 Todo를 옆 목록 행에도 반영
            guard case .update(_, let todo) = submit,
                  let item = TodayTodoItem(from: todo) else { return }
            store.send(.store(.updateTodo(item)))
        }
        .prominentAlert(store, state: \.alert, action: \.alert)
        .overlay {
            if store.isLoading {
                LoadingView()
            }
        }
    }

    private func destination(_ route: TodayRoute) -> some View {
        switch route {
        case .todo(let item):
            TodoDetailView(
                store: Store(
                    initialState: TodoDetailFeature.State(todoId: item.id, showEditButton: true)
                ) {
                    TodoDetailFeature()
                },
                windowEvent: windowEvent
            )
            .id(item.id)
        }
    }

    private func monitorDateChanges() async {
        while !Task.isCancelled {
            let date = Date()
            store.send(.checkCurrentDate(date))
            let interval = TodayFeature.dayInterval(containing: date)
            let seconds = min(max(interval.end.timeIntervalSince(date), 1), 60)
            do {
                try await Task.sleep(for: .seconds(seconds))
            } catch {
                return
            }
        }
    }
}

private struct TodayAchievementCard: View {
    let store: StoreOf<TodayFeature>

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 좁은 칸에서 한 줄에 들어가지 않으면 작은 상태 칩으로 줄바꿈 없이 표시
            ViewThatFits(in: .horizontal) {
                header(isCompact: false)
                header(isCompact: true)
            }

            ProgressView(value: store.todayAchievement?.progress ?? 0)
        }
        .padding(20)
        .groupBackground(in: .rect(cornerRadius: CornerRadius.group))
    }

    private func header(isCompact: Bool) -> some View {
        HStack(spacing: isCompact ? 8 : 10) {
            Text(String(
                localized: "today_achievement_title",
                bundle: PresentationResources.bundle)
            )
            .font(.adaptive(.title3).bold())
            .lineLimit(1)

            Text(achievementStatusTitle)
                .font(.adaptive(isCompact ? .caption : .callout).weight(.semibold))
                .foregroundStyle(Color.tintLabel)
                .lineLimit(1)
                .padding(.horizontal, isCompact ? 6 : 12)
                .padding(.vertical, isCompact ? 3 : 6)
                .background(Color.tintFill, in: .rect(cornerRadius: CornerRadius.badge))

            Spacer(minLength: isCompact ? 4 : 8)

            progressCount
        }
    }

    @ViewBuilder
    private var progressCount: some View {
        if let achievement = store.todayAchievement {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text("\(achievement.completedCount)")
                    .font(.adaptive(.title2).bold())
                    .foregroundStyle(Color.accent)
                Text("/")
                Text("\(achievement.totalCount)")
            }
            .font(.adaptive(.callout).weight(.semibold))
            .foregroundStyle(Color.secondaryLabel)
        } else {
            Text("-- / --")
                .font(.adaptive(.callout).weight(.semibold))
                .foregroundStyle(Color.secondaryLabel)
        }
    }

    private var achievementStatusTitle: String {
        store.todayAchievement?.status.title
            ?? String(localized: "today_achievement_status_loading", bundle: PresentationResources.bundle)
    }
}

private struct TodayFilterBar: View {
    @Bindable var store: StoreOf<TodayFeature>

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 8) {
                ForEach(TodayFeature.TodoScope.allCases, id: \.self) { scope in
                    let isSelected = store.selectedTodoScope == scope
                    Button {
                        withAnimation(.easeInOut) {
                            _ = store.send(.setTodoScope(scope))
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(scope.title)
                            Text("\(store.summaryCounts[scope, default: 0])")
                                .fontWeight(.bold)
                        }
                        .font(.adaptive(.callout))
                        .foregroundStyle(isSelected ? Color.tintLabel : .fillLabel)
                    }
                    .adaptiveButtonStyle(color: isSelected ? Color.tintFill : .fill)
                }

                let category = store.selectedCategory
                let isSelected = category != nil
                DropdownMenu(
                    isPresented: $store.isCategoryFilterPresented,
                    sections: [
                        DropdownMenuSection(items: [
                            DropdownMenuItem(
                                String(localized: "today_filter_all_categories", bundle: PresentationResources.bundle),
                                systemImage: "tray.2",
                                isChecked: store.selectedCategoryID == nil
                            ) {
                                store.send(.setCategory(nil))
                            }
                        ]),
                        DropdownMenuSection(items: store.visibleCategories.map { category in
                            DropdownMenuItem(
                                category.localizedName,
                                systemImage: category.symbolName,
                                imageColor: category.color,
                                isChecked: store.selectedCategoryID == category.id
                            ) {
                                store.send(.setCategory(category.id))
                            }
                        })
                    ]
                ) {
                    HStack(spacing: 6) {
                        Image(systemName: category?.symbolName ?? "tray.2")
                            .foregroundStyle(category?.color ?? Color.fillLabel)
                        Text(
                            category?.localizedName
                                ?? String(
                                    localized: "todo_category",
                                    bundle: PresentationResources.bundle
                                )
                        )
                    }
                    .font(.adaptive(.callout))
                    .foregroundStyle(isSelected ? Color.tintLabel : .fillLabel)
                    .adaptiveButtonStyle(color: isSelected ? Color.tintFill : .fill)
                }
            }
        }
        .scrollIndicators(.hidden)
        .padding(.horizontal, -16)
        .contentMargins(.horizontal, 16, for: .scrollContent)
    }
}

// 칸 제목 줄의 필터 버튼
private struct TodayFilterMenu: View {
    let store: StoreOf<TodayFeature>

    var body: some View {
        let category = store.selectedCategory
        let clear = DropdownMenuItem(
            String(localized: "todo_list_clear_filters", bundle: PresentationResources.bundle),
            systemImage: "xmark",
            role: .destructive
        ) {
            withAnimation(.easeInOut) {
                _ = store.send(.setTodoScope(.remaining))
                _ = store.send(.setCategory(nil))
            }
        }

        PaneMenuButton(
            systemImage: "line.3.horizontal.decrease",
            badgeCount: store.appliedFilterCount,
            sections: [
                DropdownMenuSection(
                    String(localized: "today_filter_view", bundle: PresentationResources.bundle),
                    items: TodayFeature.TodoScope.allCases.map { scope in
                        DropdownMenuItem(scope.title, isChecked: store.selectedTodoScope == scope) {
                            withAnimation(.easeInOut) {
                                _ = store.send(.setTodoScope(scope))
                            }
                        }
                    }
                ),
                DropdownMenuSection(items: [
                    DropdownMenuItem(
                        String(localized: "todo_category", bundle: PresentationResources.bundle),
                        systemImage: category?.symbolName ?? "tray",
                        imageColor: category?.color,
                        submenu: [
                            DropdownMenuSection(items: [
                                DropdownMenuItem(
                                    String(localized: "today_filter_all_categories", bundle: PresentationResources.bundle),
                                    systemImage: "tray.2",
                                    isChecked: store.selectedCategoryID == nil
                                ) {
                                    store.send(.setCategory(nil))
                                }
                            ]),
                            DropdownMenuSection(items: store.visibleCategories.map { category in
                                DropdownMenuItem(
                                    category.localizedName,
                                    systemImage: category.symbolName,
                                    imageColor: category.color,
                                    isChecked: store.selectedCategoryID == category.id
                                ) {
                                    store.send(.setCategory(category.id))
                                }
                            })
                        ]
                    )
                ]),
                // 걸린 필터가 있을 때만 마지막 항목으로 표시
                DropdownMenuSection(items: 0 < store.appliedFilterCount ? [clear] : [])
            ]
        )
    }
}

private struct TodayEmptyContent: View {
    let store: StoreOf<TodayFeature>

    var body: some View {
        let content = emptyStateContent

        EmptyStateView(content.title, systemImage: content.systemImage, message: content.message)
    }

    private var emptyStateContent: EmptyStateContent {
        if store.todos.isEmpty, store.completedTodayTodos.isEmpty {
            return EmptyStateContent(
                title: String(localized: "today_empty_all_title", bundle: PresentationResources.bundle),
                message: String(localized: "today_empty_all_message", bundle: PresentationResources.bundle),
                systemImage: "checklist"
            )
        }
        if store.hasActiveFilters {
            return EmptyStateContent(
                title: String(localized: "today_empty_filtered_title", bundle: PresentationResources.bundle),
                message: String(localized: "today_empty_filtered_message", bundle: PresentationResources.bundle),
                systemImage: "line.3.horizontal.decrease"
            )
        }
        return EmptyStateContent(
            title: String(localized: "today_empty_all_title", bundle: PresentationResources.bundle),
            message: String(localized: "today_empty_all_message", bundle: PresentationResources.bundle),
            systemImage: "checklist"
        )
    }

    private struct EmptyStateContent {
        let title: String
        let message: String
        let systemImage: String
    }
}

private struct TodayTodoInspector: View {
    let store: StoreOf<TodayFeature>
    var showsCloseButton = false

    @ViewBuilder
    var body: some View {
        if let editorStore = store.scope(state: \.todoEditor, action: \.todoEditor) {
            TodoPropertiesView(
                store: editorStore,
                showsEditorActions: true,
                showsCloseButton: showsCloseButton,
                onSubmit: { editorStore.send(.upsertTodo) },
                onClose: { store.send(.dismissTodoInspector) }
            )
            .onAppear { editorStore.send(.onAppear) }
            .prominentAlert(editorStore, state: \.alert, action: \.alert)
        }
    }
}

private extension TodayFeature.TodayAchievement.Status {
    var title: String {
        let key = switch self {
        case .empty: "today_achievement_status_empty"
        case .inProgress: "today_achievement_status_in_progress"
        case .completed: "today_achievement_status_completed"
        }
        return String(localized: String.LocalizationValue(key), bundle: PresentationResources.bundle)
    }
}

extension TodayFeature.TodoScope {
    var title: String {
        switch self {
        case .remaining:
            return String(localized: "today_filter_remaining", bundle: PresentationResources.bundle)
        case .important:
            return String(localized: "today_filter_important", bundle: PresentationResources.bundle)
        }
    }
}
