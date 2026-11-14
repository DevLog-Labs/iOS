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
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
    @Environment(\.windowControlsInset) private var windowControlsInset
    @Environment(\.readableContentWidth) private var readableContentWidth
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
                                    selectedTodoId: store.selectedTodoId,
                                    onSelect: { item in
                                        if isiOSAppOnMac {
                                            store.send(.binding(.set(\.selectedTodoId, item.id)))
                                        } else {
                                            router.push(.todo(TodoIdItem(id: item.id)))
                                        }
                                    },
                                    onInspect: { store.send(.showTodoInspector($0)) }
                                )
                                .padding(.bottom, section.id == sections.last?.id ? 0 : 8)
                            }
                            .padding(.bottom, 12)
                        }
                    }
                    .padding(.horizontal)
                    .frame(maxWidth: readableContentWidth)
                    .frame(maxWidth: .infinity)
                }
                .safeAreaInset(edge: .top, spacing: 0) {
                    let title = Text(String(localized: "nav_today", bundle: PresentationResources.bundle))

                    VStack(spacing: 0) {
                        if isiOSAppOnMac {
                            PaneTitleBar(title)
                        }
                        VStack(alignment: .leading) {
                            if !isiOSAppOnMac {
                                title
                                    .font(.largeTitle.bold())
                                    .padding(.bottom, 8)
                            }
                            TodayFilterBar(store: store)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .frame(maxWidth: readableContentWidth)
                        .padding(.top, isiOSAppOnMac ? 12 : windowControlsInset)
                        .padding(.bottom, 8)
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
                    placeholder: Text("today_select_detail", bundle: PresentationResources.bundle),
                    windowEvent: windowEvent
                )
                // 인스펙터 등에서 목록 행이 바뀌면 상세 칸도 다시 조회
                .id(item?.updatedAt)
            }
            .navigationDestination(
                for: TodayRoute.self,
                interactivePop: { _ in true },
                destination: { destination($0).environment(\.showsPaneTitleBar, isiOSAppOnMac) }
            )
        }
        .navigationHistory(router)
        .inspector(
            isPresented: isiOSAppOnMac || horizontalSizeClass == .regular
                ? $store.isTodoInspectorPresented : .constant(false)
        ) {
            TodayTodoInspector(store: store)
        }
        // 좁은 화면의 세부 정보는 시스템 시트 대신 직접 그린 시트로 표시
        .prominentSheet(
            isPresented: isiOSAppOnMac || horizontalSizeClass == .regular
                ? .constant(false) : $store.isTodoInspectorPresented
        ) {
            TodayTodoInspector(store: store)
        }
        // inspector 컨테이너의 상단 safe area 배경
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
            HStack(spacing: 10) {
                Text(String(
                    localized: "today_achievement_title",
                    bundle: PresentationResources.bundle)
                )
                .font(.title3.bold())

                Text(achievementStatusTitle)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(Color.tintLabel)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.tintFill, in: .rect(cornerRadius: CornerRadius.badge))

                Spacer(minLength: 8)

                progressCount
            }

            ProgressView(value: store.todayAchievement?.progress ?? 0)
        }
        .padding(20)
        .groupBackground(in: .rect(cornerRadius: CornerRadius.group))
    }

    @ViewBuilder
    private var progressCount: some View {
        if let achievement = store.todayAchievement {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text("\(achievement.completedCount)")
                    .font(.title2.bold())
                    .foregroundStyle(Color.accent)
                Text("/")
                Text("\(achievement.totalCount)")
            }
            .font(.callout.weight(.semibold))
            .foregroundStyle(Color.secondaryLabel)
        } else {
            Text("-- / --")
                .font(.callout.weight(.semibold))
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
                        .font(.callout)
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
                    .font(.callout)
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

    @ViewBuilder
    var body: some View {
        if let editorStore = store.scope(state: \.todoEditor, action: \.todoEditor) {
            TodoPropertiesView(
                store: editorStore,
                showsEditorActions: true,
                onSubmit: { editorStore.send(.upsertTodo) },
                onClose: { store.send(.dismissTodoInspector) }
            )
            .inspectorColumnWidth(min: 320, ideal: 420, max: 520)
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
