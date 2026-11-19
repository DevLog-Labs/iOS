//
//  PushNotificationListView.swift
//  NotificationTab
//
//  Created by opfic on 5/14/25.
//

import SwiftUI
import Core
import PresentationShared

public struct PushNotificationListView: View {
    @Environment(\.usesDesktopLayout) private var usesDesktopLayout
    @State private var store: StoreOf<PushNotificationListFeature>
    private let isSelected: Bool

    public init(isSelected: Bool) {
        @Dependency(\.fetchPushNotificationQueryUseCase) var fetchQueryUseCase
        self._store = State(initialValue: Store(
            initialState: PushNotificationListFeature.State(
                query: fetchQueryUseCase.execute()
            )
        ) {
            PushNotificationListFeature()
        })
        self.isSelected = isSelected
    }

    public var body: some View {
        // 사이드바가 있는 창에서 오른쪽 칸을 열었을 때만 목록 | 상세 두 칸으로 나눔
        let showsPane = usesDesktopLayout && store.isDetailPanePresented

        NavigationStack {
            PaneSplitView(splitsOnDesktop: showsPane) {
                // 사이드바가 있는 창은 상세 판이나 오른쪽 칸에 연 알림을 목록에 선택 표시
                PushNotificationListContent(store: store, showsSelection: usesDesktopLayout)
                    .background(Color.background)
                    .refreshable(isEnabled: PullToRefreshAvailability.isEnabled) {
                        let task = store.send(.view(.refresh))
                        await task.finish()
                        store.send(.view(.startObserving))
                    }
                    .duoToolbarVisibility()
            } detail: {
                TodoDetailPane(
                    todoId: store.selectedTodoId?.id,
                    showEditButton: false,
                    onClose: usesDesktopLayout ? closeDetailPane : nil
                )
            }
            // 오른쪽 칸은 칸 제목 줄 정보 버튼 대신 창 오른쪽 세부 정보 사이드바에 속성 표시
            .detailSideBarTarget(
                showsPane ? store.selectedTodoId.map { .todo(id: $0.id, isEditable: false) } : nil
            )
        }
        .prominentAlert(store, state: \.alert, action: \.alert)
        .prominentSheet(item: sheetStore.activePresentation(when: isSelected && !usesDesktopLayout)) { store in
            sheetContent(store)
        }
        .detailPanel(item: sheetStore.activePresentation(when: isSelected && usesDesktopLayout)) { sheetStore in
            TodoDetailPanel(
                todoId: sheetStore.todoId,
                location: Text("nav_push_notifications", bundle: PresentationResources.bundle),
                isEditable: false,
                onMoveToPane: {
                    store.send(.binding(.set(\.isDetailPanePresented, true)))
                }
            )
        }
        .onChange(of: isSelected, initial: true) { _, isSelected in
            if isSelected {
                store.send(.view(.fetchNotifications))
            }
        }
        .onChange(of: store.selectedTodoId?.id, initial: true) {
            if !showsPane {
                store.send(.view(.syncSheetPresentation))
            }
        }
        // 오른쪽 칸을 열면 상세 판만 닫고, 오른쪽 칸을 닫으면 고른 Todo를 상세 판이나 시트로 표시
        .onChange(of: showsPane) { _, showsPane in
            store.send(.view(showsPane ? .hideSheet : .syncSheetPresentation))
        }
        .overlay {
            if store.isLoading {
                LoadingView()
            }
        }
    }

    // 선택을 먼저 비워 오른쪽 칸을 닫을 때 같은 Todo를 상세 판으로 다시 열지 않음
    private func closeDetailPane() {
        store.send(.view(.selectNotification(nil)))
        store.send(.binding(.set(\.isDetailPanePresented, false)))
    }

    @ViewBuilder
    private func sheetContent(
        _ sheetStore: Store<PushNotificationListFeature.SheetState, PushNotificationListFeature.Action.Sheet>
    ) -> some View {
        NavigationStack {
            TodoDetailView(store: Store(
                initialState: TodoDetailFeature.State(
                    todoId: sheetStore.todoId,
                    showEditButton: false
                )
            ) {
                TodoDetailFeature()
            })
            .id(sheetStore.todoId)
        }
        .environment(\.windowControlsInset, 0)
        .environment(\.deviceType, .bar)
        .background(Color.background)
    }

    private var sheetStore: Binding<
        Store<PushNotificationListFeature.SheetState,
              PushNotificationListFeature.Action.Sheet>?> {
        $store.scope(state: \.sheet, action: \.sheet)
    }
}

private struct PushNotificationListContent: View {
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
    @Environment(\.usesDesktopLayout) private var usesDesktopLayout
    @Environment(\.windowControlsInset) private var windowControlsInset
    @ScaledMetric(relativeTo: .body) private var iconSize = 32
    let store: StoreOf<PushNotificationListFeature>
    // 고른 알림을 상세 판이나 옆 칸에 표시하는 동안 목록 행에 선택 표시
    let showsSelection: Bool

    @ViewBuilder
    var body: some View {
        let notifications = store.notifications.filter { !$0.isHidden }
        let recent = notifications.filter { Calendar.autoupdatingCurrent.isDateInToday($0.receivedAt) }
        let previous = notifications.filter { !Calendar.autoupdatingCurrent.isDateInToday($0.receivedAt) }
        let sections = store.query.sortOrder == .latest ? [recent, previous] : [previous, recent]

        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if notifications.isEmpty {
                    EmptyStateView(
                        String(localized: "push_notifications_empty", bundle: PresentationResources.bundle),
                        systemImage: "bell"
                    )
                    .padding(.horizontal)
                } else {
                    ForEach(sections.indices, id: \.self) { index in
                        let items = sections[index]
                        let isRecent = (index == 0) == (store.query.sortOrder == .latest)
                        if !items.isEmpty {
                            HStack(spacing: 6) {
                                Text(String(
                                    localized: isRecent ? "push_notifications_new" : "push_notifications_previous",
                                    bundle: PresentationResources.bundle
                                ))
                                .font(.system(size: isiOSAppOnMac ? 12.5 * AdaptiveSize.boardScale : 14, weight: .bold))
                                Text("\(items.count)")
                                    .font(.system(size: isiOSAppOnMac ? 12.5 * AdaptiveSize.boardScale : 14, weight: .medium))
                                    .foregroundStyle(Color.secondaryLabel)
                                Spacer()
                            }
                            .padding(.horizontal, isiOSAppOnMac ? 14 * AdaptiveSize.boardScale : 16)
                            .padding(.top, isiOSAppOnMac ? 16 * AdaptiveSize.boardScale : 20)
                            .padding(.bottom, isiOSAppOnMac ? 6 * AdaptiveSize.boardScale : 10)

                            LazyVStack(spacing: 0) {
                                ForEach(items) { item in
                                    let category = TodoCategoryItem(from: item.todoCategory)
                                    let isSelected = showsSelection && item.id == store.selectedNotificationId

                                    HStack(alignment: .top, spacing: 10) {
                                        // 테두리 있는 회색 사각형에 카테고리 색 기호
                                        Image(systemName: category.symbolName)
                                            .font(.adaptive(.body))
                                            .foregroundStyle(category.color)
                                            .frame(
                                                width: isiOSAppOnMac ? 29 * AdaptiveSize.boardScale : iconSize,
                                                height: isiOSAppOnMac ? 29 * AdaptiveSize.boardScale : iconSize
                                            )
                                            .background(Color.tertiaryBackground, in: .rect(cornerRadius: CornerRadius.control))
                                            .overlay {
                                                RoundedRectangle(cornerRadius: CornerRadius.control)
                                                    .strokeBorder(Color.secondarySeparator)
                                            }

                                        VStack(alignment: .leading, spacing: 3) {
                                            HStack(spacing: 6) {
                                                Text(item.title)
                                                    .font(.adaptive(isiOSAppOnMac ? .body : .callout).weight(item.isRead ? .medium : .bold))
                                                    .foregroundStyle(item.isRead ? Color.secondaryLabel : .label)
                                                    .lineLimit(2)
                                                    .frame(maxWidth: .infinity, alignment: .leading)

                                                TimelineView(.periodic(from: .now, by: 1.0)) { context in
                                                    Text(timeAgoText(from: item.receivedAt, now: context.date))
                                                        .font(.system(size: isiOSAppOnMac ? 11 * AdaptiveSize.boardScale : 12.5))
                                                        .foregroundStyle(Color.secondaryLabel)
                                                        .lineLimit(1)
                                                }

                                                if !item.isRead {
                                                    Circle()
                                                        .fill(Color.accent)
                                                        .frame(width: 8, height: 8)
                                                }
                                            }

                                            Text(item.body)
                                                .font(.adaptive(.footnote))
                                                .foregroundStyle(Color.secondaryLabel)
                                                .lineLimit(1)
                                        }
                                    }
                                    .padding(.vertical, isiOSAppOnMac ? 8 * AdaptiveSize.boardScale : 12)
                                    .padding(.trailing, isiOSAppOnMac ? 14 * AdaptiveSize.boardScale : 16)
                                    // 구분선은 아이콘 시작부터 행 오른쪽 끝까지 표시
                                    .overlay(alignment: .bottom) {
                                        Divider().overlay(Color.secondarySeparator)
                                    }
                                    .padding(.leading, isiOSAppOnMac ? 14 * AdaptiveSize.boardScale : 16)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    // 선택 표시는 마우스 표시와 같은 회색으로 행 전체를 채움
                                    .hoverHighlight(isEnabled: !isSelected)
                                    // 반투명 선택 색 아래로 행 동작 버튼이 비치지 않도록 불투명 바탕 위에 표시
                                    .background(isSelected ? Color.fill : .clear)
                                    .background(Color.background)
                                    .contentShape(.rect)
                                    .onTapGesture {
                                        store.send(.view(.selectNotification(item.id)))
                                    }
                                    .itemActions {
                                        // 우클릭과 길게 누른 메뉴는 상세 판과 오른쪽 칸으로 여는 항목을 맨 위에 표시
                                        if usesDesktopLayout {
                                            Button {
                                                store.send(.binding(.set(\.isDetailPanePresented, false)))
                                                store.send(.view(.selectNotification(item.id)))
                                            } label: {
                                                Label {
                                                    Text("detail_panel_open", bundle: PresentationResources.bundle)
                                                } icon: {
                                                    Image(systemName: "doc.text")
                                                }
                                            }
                                            Button {
                                                store.send(.binding(.set(\.isDetailPanePresented, true)))
                                                store.send(.view(.selectNotification(item.id)))
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
                                            title: item.isRead
                                                ? String(localized: "push_mark_unread", bundle: PresentationResources.bundle) : String(localized: "push_mark_read", bundle: PresentationResources.bundle),
                                            color: Color.accent,
                                            image: Image(systemName: item.isRead
                                                ? "circle.badge.xmark" : "checkmark.circle")
                                        ) {
                                            store.send(.view(.toggleRead(item)))
                                        }

                                        if usesDesktopLayout {
                                            Divider()
                                        }

                                        ItemActionButton(
                                            title: String(localized: "common_delete", bundle: PresentationResources.bundle),
                                            color: Color.red,
                                            image: Image(systemName: "trash"),
                                            role: .destructive
                                        ) {
                                            store.send(.view(.deleteNotification(item)))
                                            presentDeleteNotificationToast(item.id)
                                        }
                                    }
                                    .clipShape(.rect)
                                    .onAppear {
                                        if item.id == notifications.last?.id, store.nextCursor != nil {
                                            store.send(.view(.loadNextPage))
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            let title = Text(String(localized: "nav_push_notifications", bundle: PresentationResources.bundle))

            VStack(spacing: 0) {
                if usesDesktopLayout {
                    PaneTitleBar(title) {
                        PushNotificationPaneMenus(store: store)
                    }
                } else {
                    VStack(alignment: .leading) {
                        title
                            .font(.adaptive(.largeTitle).bold())
                            .padding(.bottom, 8)

                        ScrollView(.horizontal) {
                            PushNotificationFilterBar(store: store)
                        }
                        .scrollIndicators(.hidden)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, -16)
                        .contentMargins(.horizontal, 16, for: .scrollContent)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, windowControlsInset)
                    .padding(.bottom, 12)

                    // 칩 줄 아래 구분선으로 목록과 나눔
                    Divider().overlay(Color.secondarySeparator)
                }
            }
            .background(Color.background)
            .toolbarBackground(Color.background)
        }
        .scrollDisabled(notifications.isEmpty || store.isLoading)
    }

    private func presentDeleteNotificationToast(_ notificationId: String) {
        ToastPresenter.present(
            message: String(localized: "push_notifications_delete_toast_message", bundle: PresentationResources.bundle),
            systemImage: "arrow.uturn.backward",
            duration: 5,
            action: {
                store.send(.view(.undoDelete))
            },
            onDismiss: {
                store.send(.view(.finishDeleteToast(notificationId)))
            }
        )
    }

    private func timeAgoText(from date: Date, now: Date) -> String {
        let seconds = Int(now.timeIntervalSince(date))

        if seconds < 60 {
            return String.localizedStringWithFormat(
                String(localized: "push_time_seconds_ago_format", bundle: PresentationResources.bundle),
                Int64(max(0, seconds))
            )
        } else if seconds < 3600 {
            let minutes = seconds / 60
            return String.localizedStringWithFormat(
                String(localized: "push_time_minutes_ago_format", bundle: PresentationResources.bundle),
                Int64(minutes)
            )
        } else if seconds < 86400 {
            let hours = seconds / 3600
            return String.localizedStringWithFormat(
                String(localized: "push_time_hours_ago_format", bundle: PresentationResources.bundle),
                Int64(hours)
            )
        } else {
            let days = seconds / 86400
            return String.localizedStringWithFormat(
                String(localized: "push_time_days_ago_format", bundle: PresentationResources.bundle),
                Int64(days)
            )
        }
    }
}

private struct PushNotificationFilterBar: View {
    @Bindable var store: StoreOf<PushNotificationListFeature>

    var body: some View {
        LazyHStack(spacing: 6) {
            Button {
                if 0 < store.appliedFilterCount {
                    store.send(.view(.resetFilters))
                }
            } label: {
                // 전체 칩은 다른 조건을 골라도 강조한 채 표시
                PushNotificationFilterChip(isSelected: true) {
                    Text(String(localized: "push_timefilter_all", bundle: PresentationResources.bundle))
                }
            }
            .buttonStyle(.plain)

            Button {
                DispatchQueue.main.async {
                    store.send(.view(.toggleSortOption))
                }
            } label: {
                PushNotificationFilterChip(isSelected: store.query.sortOrder == .oldest) {
                    Text(
                        String.localizedStringWithFormat(
                            String(localized: "push_sort_format", bundle: PresentationResources.bundle),
                            store.query.sortOrder.title
                        )
                    )
                    Image(systemName: "chevron.down")
                }
            }
            .buttonStyle(.plain)

            DropdownMenu(sections: [
                DropdownMenuSection(
                    String(localized: "push_period", bundle: PresentationResources.bundle),
                    items: PushNotificationQuery.TimeFilter.availableOptions.map { option in
                        DropdownMenuItem(option.title, isChecked: store.query.timeFilter == option) {
                            store.send(.binding(.set(\.query.timeFilter, option)))
                        }
                    }
                )
            ]) {
                let timeFilter = store.query.timeFilter
                // 고른 기간은 칩 제목 뒤에 함께 표시
                PushNotificationFilterChip(isSelected: timeFilter != .none) {
                    Text(
                        timeFilter == .none
                            ? String(localized: "push_period", bundle: PresentationResources.bundle) : String.localizedStringWithFormat(
                                String(localized: "push_period_format", bundle: PresentationResources.bundle),
                                timeFilter.title
                            )
                    )
                    Image(systemName: "chevron.down")
                }
            }

            Button {
                DispatchQueue.main.async {
                    store.send(.view(.toggleUnreadOnly))
                }
            } label: {
                PushNotificationFilterChip(isSelected: store.query.unreadOnly) {
                    Text(String(localized: "push_unread", bundle: PresentationResources.bundle))
                }
            }
            .buttonStyle(.plain)
        }
    }
}

// 고른 조건은 강조색 바탕과 테두리, 나머지는 테두리만 있는 칩
private struct PushNotificationFilterChip<Content: View>: View {
    let isSelected: Bool
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 5) {
            content
        }
        .font(.adaptive(.footnote))
        .imageScale(.small)
        .foregroundStyle(isSelected ? Color.tintLabel : .label)
        .padding(.horizontal, 12)
        .frame(height: 34)
        .background(isSelected ? Color.tintFill : .clear, in: .rect(cornerRadius: CornerRadius.control))
        .overlay {
            RoundedRectangle(cornerRadius: CornerRadius.control)
                .strokeBorder(isSelected ? Color.accent.opacity(0.6) : .separator)
        }
    }
}

// 칸 제목 줄의 필터와 정렬 버튼
private struct PushNotificationPaneMenus: View {
    let store: StoreOf<PushNotificationListFeature>

    var body: some View {
        let clear = DropdownMenuItem(
            String(localized: "push_clear_all_filters", bundle: PresentationResources.bundle),
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
                        String(localized: "push_unread_only", bundle: PresentationResources.bundle),
                        systemImage: "bell",
                        isChecked: store.query.unreadOnly
                    ) {
                        store.send(.view(.toggleUnreadOnly))
                    }
                ]),
                DropdownMenuSection(
                    String(localized: "push_period", bundle: PresentationResources.bundle),
                    items: PushNotificationQuery.TimeFilter.availableOptions.map { option in
                        DropdownMenuItem(option.title, isChecked: store.query.timeFilter == option) {
                            store.send(.binding(.set(\.query.timeFilter, option)))
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
                    String(localized: "todo_list_sort_order", bundle: PresentationResources.bundle),
                    items: [PushNotificationQuery.SortOrder.latest, .oldest].map { option in
                        DropdownMenuItem(option.title, isChecked: store.query.sortOrder == option) {
                            // 정렬 순서는 둘 중 하나라 다른 순서를 고를 때만 전환
                            if store.query.sortOrder != option {
                                store.send(.view(.toggleSortOption))
                            }
                        }
                    }
                )
            ]
        )
    }
}
