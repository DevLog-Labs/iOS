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
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
    @Environment(\.usesDesktopLayout) private var usesDesktopLayout
    @Environment(\.usesPaneLayout) private var usesPaneLayout
    @Environment(\.windowControlsInset) private var windowControlsInset
    @Environment(\.readableContentWidth) private var readableContentWidth
    @Environment(\.setDetailSideBarPresented) private var setDetailSideBarPresented
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
        NavigationStack {
            let sections = store.sections
            // 사이드바가 있는 창은 목록을 창 전체 폭으로 두고 오른쪽 칸을 열었고 그 Todo가 목록에 있을 때만 두 칸으로 나눔
            let showsPane = store.showsDetailInPane
                && sections.flatMap(\.items).contains { $0.id == store.detail?.todoId }

            PaneSplitView(splitsOnDesktop: showsPane) {
                ScrollView {
                    // 칸으로 나누지 않은 화면은 상세 칸이 없어 선택 표시 생략
                    let highlightedTodoIds = (
                        [store.hoveredTodoId] + (usesPaneLayout ? [store.selectedTodoId, store.detail?.todoId] : [])
                    ).compactMap { $0 }

                    LazyVStack(alignment: .leading, spacing: 0) {
                        // 필터에 맞는 Todo가 없으면 요약 카드 없이 빈 화면만 표시
                        if !sections.isEmpty || !store.hasActiveFilters {
                            TodayAchievementCard(store: store)
                                .padding(.horizontal, isiOSAppOnMac ? 14 * AdaptiveSize.boardScale : 16)
                                .padding(.bottom, isiOSAppOnMac ? 8 * AdaptiveSize.boardScale : 12)
                        }

                        if sections.isEmpty, !store.isLoading {
                            TodayEmptyContent(store: store)
                                .padding(.horizontal)
                        } else {
                            ForEach(sections) { section in
                                TodoSection(
                                    section: section,
                                    isNavigationEnabled: !store.isTodoInspectorPresented,
                                    highlightedTodoIds: highlightedTodoIds,
                                    onSelect: { item in
                                        store.send(.selectTodo(item.id))
                                    },
                                    onInspect: { item in
                                        // 사이드바가 있으면 고른 Todo를 창 오른쪽 세부 정보 사이드바에 표시
                                        if usesDesktopLayout {
                                            store.send(.inspectTodo(item.id))
                                            setDetailSideBarPresented?(true)
                                        } else {
                                            store.send(.showTodoInspector(item))
                                        }
                                    },
                                    onHover: { item, isHovering in
                                        guard isiOSAppOnMac else { return }
                                        // 다른 행으로 옮겨 간 뒤에 온 벗어남은 무시
                                        if isHovering {
                                            store.send(.binding(.set(\.hoveredTodoId, item.id)))
                                        } else if store.hoveredTodoId == item.id {
                                            store.send(.binding(.set(\.hoveredTodoId, nil)))
                                        }
                                    }
                                )
                            }
                            .padding(.bottom, 12)
                        }
                    }
                    .padding(.top, 4 * AdaptiveSize.boardScale)
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
                            VStack(alignment: .leading) {
                                title
                                    .font(.adaptive(.largeTitle).bold())
                                    .padding(.bottom, 8)
                                TodayFilterBar(store: store)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                            .frame(maxWidth: readableContentWidth)
                            .padding(.top, windowControlsInset)
                            .padding(.bottom, 12)
                        }
                    }
                    .background(Color.background)
                    .toolbarBackground(Color.background)
                }
                .background(Color.background)
                .refreshable { await store.send(.refresh).finish() }
                .duoToolbarVisibility()
            } detail: {
                // 목록에서 빠진 Todo는 선택 안내로 대체
                if showsPane, let detailStore = store.scope(state: \.detail, action: \.detail.presented) {
                    TodoDetailView(
                        store: detailStore,
                        windowEvent: windowEvent,
                        isPaneDetail: true,
                        onClose: { store.send(.detail(.dismiss)) }
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
                inPane: showsPane,
                isActive: isSelected
            ) { detailStore in
                TodoDetailView(store: detailStore, windowEvent: windowEvent)
            } panel: { detailStore in
                // 목록에서 빠진 Todo는 오른쪽 칸에 그릴 수 없어 판 메뉴에서 오른쪽 칸으로 옮기기 생략
                let isListed = sections.flatMap(\.items).contains { $0.id == detailStore.todoId }

                TodoDetailPanel(
                    store: detailStore,
                    location: Text("nav_today", bundle: PresentationResources.bundle),
                    windowEvent: windowEvent,
                    onMoveToPane: isListed ? { store.send(.moveDetailToPane) } : nil
                )
            }
            .compositionRight(isActive: sections.flatMap(\.items).contains { $0.id == store.selectedTodoId }) {
                if let todoId = store.selectedTodoId {
                    TodoDetailSideBarView(todoId: todoId, isEditable: true, windowEvent: windowEvent)
                        .id(todoId)
                }
            }
        }
        .desktopNavigationTransition()
        // 오른쪽 칸에 연 Todo가 목록에서 빠지면 닫기 버튼 없는 선택 안내 대신 오른쪽 칸을 닫음
        // 좁은 창은 쌓아 연 상세를 그대로 두고, 넓어지면 오른쪽 칸 대신 상세 판으로 표시
        .onChange(of: store.sections.flatMap(\.items).contains { $0.id == store.detail?.todoId }) { _, isListed in
            guard store.showsDetailInPane && !isListed else { return }
            store.send(usesDesktopLayout ? .detail(.dismiss) : .binding(.set(\.showsDetailInPane, false)))
        }
        // 사이드바가 있으면 창 오른쪽 세부 정보 사이드바, 좁은 화면과 Duo 펼침은 직접 그린 시트로 표시
        .prominentSheet(
            isPresented: usesDesktopLayout ? .constant(false) : $store.isTodoInspectorPresented
        ) {
            // 넓은 창의 세부 정보 사이드바와 같은 속성 칸, 고친 값은 바로 저장
            if let infoStore = store.scope(state: \.todoInfo, action: \.todoInfo) {
                InfoSheetView(store: infoStore, onClose: { store.send(.dismissTodoInspector) })
            }
        }
        // 사이드바 구조로 바뀌면 가려진 세부 정보 시트는 닫고 같은 Todo를 세부 정보 사이드바에 표시
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
            store.send(.detailTodoUpdated(item))
        }
        .prominentAlert(store, state: \.alert, action: \.alert)
        .overlay {
            if store.isLoading {
                LoadingView()
            }
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

// 카드 바탕 없이 페이지 여백에 맞추고 아래 구분선으로 목록과 나눔
private struct TodayAchievementCard: View {
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
    let store: StoreOf<TodayFeature>

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 좁은 칸에서 한 줄에 들어가지 않으면 간격을 줄여 줄바꿈 없이 표시
            ViewThatFits(in: .horizontal) {
                header(isCompact: false)
                header(isCompact: true)
            }

            // 채운 막대 오른쪽 끝은 각지게 두고 바깥 막대만 둥글게 자름
            Rectangle()
                .fill(Color.separator)
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(Color.accent)
                        .scaleEffect(x: store.todayAchievement?.progress ?? 0, anchor: .leading)
                }
                .frame(height: 6)
                .clipShape(.capsule)
        }
        .padding(.top, isiOSAppOnMac ? 4 * AdaptiveSize.boardScale : 8)
        .padding(.bottom, isiOSAppOnMac ? 14 * AdaptiveSize.boardScale : 16)
        .overlay(alignment: .bottom) {
            Divider().overlay(Color.secondarySeparator)
        }
    }

    private func header(isCompact: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: isCompact ? 6 : 8) {
            Text(String(
                localized: "today_achievement_title",
                bundle: PresentationResources.bundle)
            )
            .font(.adaptive(.callout).bold())
            .lineLimit(1)

            Text(achievementStatusTitle)
                .font(.adaptive(.caption).weight(.semibold))
                .foregroundStyle(Color.tintLabel)
                .lineLimit(1)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.tintFill, in: .rect(cornerRadius: CornerRadius.badge))

            Spacer(minLength: isCompact ? 4 : 8)

            if let achievement = store.todayAchievement {
                Text(verbatim: "\(achievement.completedCount)")
                    .font(.adaptive(.title2).weight(.heavy))
                    .foregroundStyle(Color.tintLabel)
                Text(verbatim: "/ \(achievement.totalCount)")
                    .font(.adaptive(.footnote))
                    .foregroundStyle(Color.secondaryLabel)
            } else {
                Text(verbatim: "-- / --")
                    .font(.adaptive(.footnote))
                    .foregroundStyle(Color.secondaryLabel)
            }
        }
    }

    private var achievementStatusTitle: String {
        guard let achievement = store.todayAchievement else {
            return String(localized: "today_achievement_status_loading", bundle: PresentationResources.bundle)
        }
        switch achievement.status {
        case .empty:
            return String(localized: "today_achievement_status_empty", bundle: PresentationResources.bundle)
        case .inProgress:
            return String.localizedStringWithFormat(
                String(localized: "today_achievement_remaining_format", bundle: PresentationResources.bundle),
                Int64(achievement.totalCount - achievement.completedCount)
            )
        case .completed:
            return String(localized: "today_achievement_status_completed", bundle: PresentationResources.bundle)
        }
    }
}

private struct TodayFilterBar: View {
    @Bindable var store: StoreOf<TodayFeature>

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 6) {
                ForEach(TodayFeature.TodoScope.allCases, id: \.self) { scope in
                    Button {
                        withAnimation(.easeInOut) {
                            _ = store.send(.setTodoScope(scope))
                        }
                    } label: {
                        TodayFilterChip(isSelected: store.selectedTodoScope == scope) {
                            Text(scope.title)
                            Text("\(store.summaryCounts[scope, default: 0])")
                                .fontWeight(.bold)
                        }
                    }
                    .buttonStyle(.plain)
                }

                let category = store.selectedCategory
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
                    TodayFilterChip(isSelected: category != nil) {
                        // 아이콘도 칩 글자색을 따름
                        Image(systemName: category?.symbolName ?? "tray")
                        Text(
                            category?.localizedName
                                ?? String(
                                    localized: "todo_category",
                                    bundle: PresentationResources.bundle
                                )
                        )
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
        .padding(.horizontal, -16)
        .contentMargins(.horizontal, 16, for: .scrollContent)
    }
}

// 고른 조건은 테두리 없는 회색 바탕, 나머지는 테두리만 있는 칩
private struct TodayFilterChip<Content: View>: View {
    let isSelected: Bool
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 5) {
            content
        }
        .font(.adaptive(.footnote))
        .foregroundStyle(Color.label)
        .padding(.horizontal, 12)
        .frame(height: 34)
        .background(isSelected ? Color.tertiaryBackground : .clear, in: .rect(cornerRadius: CornerRadius.control))
        .overlay {
            RoundedRectangle(cornerRadius: CornerRadius.control)
                .strokeBorder(isSelected ? Color.clear : .separator)
        }
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
