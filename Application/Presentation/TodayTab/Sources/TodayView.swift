//
//  TodayView.swift
//  TodayTab
//
//  Created by opfic on 3/6/26.
//

import SwiftUI
import Core
import Domain
import PresentationShared

public struct TodayView: View {
    @Environment(\.scenePhase) private var scenePhase
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
            ScrollView {
                let sections = store.sections
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
                                onSelect: { router.push(.todo(TodoIdItem(id: $0.id))) },
                                onInspect: { store.send(.showTodoInspector($0)) }
                            )
                            .padding(.bottom, section.id == sections.last?.id ? 0 : 8)
                        }
                        .padding(.bottom, 12)
                    }
                }
                .padding(.horizontal)
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                VStack(alignment: .leading) {
                    topBar
                    TodayFilterBar(store: store)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.bottom, 8)
                .background(Color.appBackground)
                .toolbarBackground(Color.appBackground)
            }
            .background(Color.appBackground)
            .refreshable { await store.send(.refresh).finish() }
            .toolbarVisibility(.hidden, for: .navigationBar)
            .navigationDestination(
                for: TodayRoute.self,
                interactivePop: { _ in true },
                destination: destination
            )
            .sheet(isPresented: $store.isCategoryFilterPresented) {
                CategoryFilterSheet(store: store)
            }
        }
        .inspector(isPresented: $store.isTodoInspectorPresented) {
            TodayTodoInspector(store: store)
        }
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
        .prominentAlert(store, state: \.alert, action: \.alert)
        .overlay {
            if store.isLoading {
                LoadingView()
            }
        }
    }

    private var topBar: some View {
        Text(String(localized: "nav_today", bundle: PresentationResources.bundle))
            .font(.largeTitle.bold())
            .padding(.bottom, 8)
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
                    .foregroundStyle(Color.onPrimaryContainer)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.primaryContainer, in: .capsule)

                Spacer(minLength: 8)

                progressCount
            }

            ProgressView(value: store.todayAchievement?.progress ?? 0)
        }
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.surface)
        }
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
            .foregroundStyle(Color.textSecondary)
        } else {
            Text("-- / --")
                .font(.callout.weight(.semibold))
                .foregroundStyle(Color.textSecondary)
        }
    }

    private var achievementStatusTitle: String {
        store.todayAchievement?.status.title
            ?? String(localized: "today_achievement_status_loading", bundle: PresentationResources.bundle)
    }
}

private struct TodayFilterBar: View {
    let store: StoreOf<TodayFeature>

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
                        .foregroundStyle(isSelected ? Color.onPrimaryContainer : .onControlBackground)
                    }
                    .adaptiveButtonStyle(color: isSelected ? Color.primaryContainer : .controlBackground)
                }

                let category = store.selectedCategory
                let isSelected = category != nil
                Button {
                    store.send(.binding(.set(\.isCategoryFilterPresented, true)))
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: category?.symbolName ?? "tray.2")
                            .foregroundStyle(category?.color ?? Color.onControlBackground)
                        Text(
                            category?.localizedName
                                ?? String(
                                    localized: "todo_category",
                                    bundle: PresentationResources.bundle
                                )
                        )
                    }
                    .font(.callout)
                    .foregroundStyle(isSelected ? Color.onPrimaryContainer : .onControlBackground)
                }
                .adaptiveButtonStyle(color: isSelected ? Color.primaryContainer : .controlBackground)
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
        VStack(spacing: 8) {
            Text(emptyStateContent.title)
                .font(.headline)
            Text(emptyStateContent.message)
                .font(.callout)
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .padding(.horizontal, 20)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.surface)
        }
    }

    private var emptyStateContent: EmptyStateContent {
        if store.todos.isEmpty, store.completedTodayTodos.isEmpty {
            return EmptyStateContent(
                title: String(localized: "today_empty_all_title", bundle: PresentationResources.bundle),
                message: String(localized: "today_empty_all_message", bundle: PresentationResources.bundle)
            )
        }
        if store.hasActiveFilters {
            return EmptyStateContent(
                title: String(localized: "today_empty_filtered_title", bundle: PresentationResources.bundle),
                message: String(localized: "today_empty_filtered_message", bundle: PresentationResources.bundle)
            )
        }
        return EmptyStateContent(
            title: String(localized: "today_empty_all_title", bundle: PresentationResources.bundle),
            message: String(localized: "today_empty_all_message", bundle: PresentationResources.bundle)
        )
    }

    private struct EmptyStateContent {
        let title: String
        let message: String
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
