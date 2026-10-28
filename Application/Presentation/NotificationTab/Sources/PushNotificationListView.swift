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
        NavigationStack {
            PushNotificationListContent(store: store)
                .background(Color.appBackground)
                .refreshable(isEnabled: PullToRefreshAvailability.isEnabled) {
                    let task = store.send(.view(.refresh))
                    await task.finish()
                    store.send(.view(.startObserving))
                }
                .toolbarVisibility(.hidden, for: .navigationBar)
        }
        .prominentAlert(store, state: \.alert, action: \.alert)
        .sheet(item: sheetStore.activePresentation(when: isSelected)) { store in
            sheetContent(store)
        }
        .onChange(of: isSelected, initial: true) { _, isSelected in
            if isSelected {
                store.send(.view(.fetchNotifications))
            }
        }
        .onChange(of: store.selectedTodoId?.id, initial: true) {
            store.send(.view(.syncSheetPresentation))
        }
        .overlay {
            if store.isLoading {
                LoadingView()
            }
        }
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
        .background(Color.appBackground)
        .presentationDragIndicator(.visible)
    }

    private var sheetStore: Binding<
        Store<PushNotificationListFeature.SheetState,
              PushNotificationListFeature.Action.Sheet>?> {
        $store.scope(state: \.sheet, action: \.sheet)
    }
}

private struct PushNotificationListContent: View {
    @ScaledMetric(relativeTo: .headline) private var iconSize = 36
    let store: StoreOf<PushNotificationListFeature>

    @ViewBuilder
    var body: some View {
        let notifications = store.notifications.filter { !$0.isHidden }
        let recent = notifications.filter { Calendar.autoupdatingCurrent.isDateInToday($0.receivedAt) }
        let previous = notifications.filter { !Calendar.autoupdatingCurrent.isDateInToday($0.receivedAt) }
        let sections = store.query.sortOrder == .latest ? [recent, previous] : [previous, recent]

        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                if notifications.isEmpty {
                    Text(String(localized: "push_notifications_empty", bundle: PresentationResources.bundle))
                        .font(.callout)
                        .foregroundStyle(Color.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32)
                        .background(Color.surface, in: .rect(cornerRadius: 16))
                } else {
                    ForEach(sections.indices, id: \.self) { index in
                        let items = sections[index]
                        let isRecent = (index == 0) == (store.query.sortOrder == .latest)
                        if !items.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                    HStack(spacing: 8) {
                                        Text(String(
                                            localized: isRecent ? "push_notifications_new" : "push_notifications_previous",
                                            bundle: PresentationResources.bundle
                                        ))
                                        .font(.title3.bold())
                                        Text("\(items.count)")
                                            .font(.callout.bold())
                                            .foregroundStyle(Color.accent)
                                        Spacer()
                                    }

                                    LazyVStack(spacing: 12) {
                                        ForEach(items) { item in
                                            let category = TodoCategoryItem(from: item.todoCategory)

                                            HStack(alignment: .top, spacing: 12) {
                                                Image(systemName: category.symbolName)
                                                    .font(.headline)
                                                    .foregroundStyle(Color.white)
                                                    .frame(width: iconSize, height: iconSize)
                                                    .background(category.color, in: .rect(cornerRadius: 10))

                                                VStack(alignment: .leading, spacing: 6) {
                                                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                                                        Text(item.title)
                                                            .font(.headline)
                                                            .foregroundStyle(
                                                                item.isRead ? Color.textSecondary : .primary
                                                            )
                                                            .lineLimit(2)

                                                        Spacer(minLength: 4)

                                                        TimelineView(.periodic(from: .now, by: 1.0)) { context in
                                                            Text(timeAgoText(from: item.receivedAt, now: context.date))
                                                                .font(.caption)
                                                                .foregroundStyle(Color.textTertiary)
                                                                .lineLimit(1)
                                                        }

                                                        if !item.isRead {
                                                            Circle()
                                                                .fill(Color.accent)
                                                                .frame(width: 7, height: 7)
                                                        }
                                                    }

                                                    Text(item.body)
                                                        .font(.subheadline)
                                                        .foregroundStyle(Color.textSecondary)
                                                        .multilineTextAlignment(.leading)
                                                        .lineLimit(3)
                                                }
                                            }
                                            .padding(16)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .background(Color.surface, in: .rect(cornerRadius: 16))
                                            .contentShape(.rect(cornerRadius: 16))
                                            .onTapGesture {
                                                store.send(.view(.selectNotification(item.id)))
                                            }
                                            .itemActions {
                                                ItemActionButton(
                                                    color: Color.accent,
                                                    image: Image(systemName: item.isRead
                                                        ? "circle.badge.xmark" : "checkmark.circle")
                                                ) {
                                                    store.send(.view(.toggleRead(item)))
                                                }

                                                ItemActionButton(
                                                    color: Color.red,
                                                    image: Image(systemName: "trash")
                                                ) {
                                                    store.send(.view(.deleteNotification(item)))
                                                    presentDeleteNotificationToast(item.id)
                                                }
                                            }
                                            .clipShape(.rect(cornerRadius: 16))
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
            .padding(.horizontal, 16)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                Text(String(localized: "nav_push_notifications", bundle: PresentationResources.bundle))
                    .font(.largeTitle.bold())
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
            .padding(.bottom, 8)
            .background(Color.appBackground)
            .toolbarBackground(Color.appBackground)
        }
        .scrollDisabled(notifications.isEmpty || store.isLoading)
    }

    private func presentDeleteNotificationToast(_ notificationId: String) {
        ToastPresenter.present(
            duration: 5,
            action: {
                store.send(.view(.undoDelete))
            },
            onDismiss: {
                store.send(.view(.finishDeleteToast(notificationId)))
            }
        ) {
            ToastLabel()
        }
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
        LazyHStack(spacing: 8) {
            Button {
                if 0 < store.appliedFilterCount {
                    store.send(.view(.resetFilters))
                }
            } label: {
                HStack(spacing: 6) {
                    Text(String(localized: "push_timefilter_all", bundle: PresentationResources.bundle))
                    if 0 < store.appliedFilterCount {
                        filterBadge
                    }
                }
                .font(.callout)
                .foregroundStyle(store.appliedFilterCount == 0 ? Color.onPrimaryContainer : .onControlBackground)
                .adaptiveButtonStyle(
                    color: store.appliedFilterCount == 0 ? .primaryContainer : .controlBackground
                )
            }

            Button {
                DispatchQueue.main.async {
                    store.send(.view(.toggleSortOption))
                }
            } label: {
                let condition = store.query.sortOrder == .oldest
                Text(
                    String.localizedStringWithFormat(
                        String(localized: "push_sort_format", bundle: PresentationResources.bundle),
                        store.query.sortOrder.title
                    )
                )
                .font(.callout)
                .foregroundStyle(condition ? Color.onPrimaryContainer : .onControlBackground)
                .adaptiveButtonStyle(color: condition ? .primaryContainer : .controlBackground)
            }

            Menu {
                Picker(selection: $store.query.timeFilter) {
                    ForEach(PushNotificationQuery.TimeFilter.availableOptions, id: \.self) { option in
                        Text(option.title).tag(option)
                    }
                } label: {
                    Text(String(localized: "push_period", bundle: PresentationResources.bundle))
                }
            } label: {
                let condition = store.query.timeFilter == .none
                HStack {
                    Text(String(localized: "push_period", bundle: PresentationResources.bundle))
                    Image(systemName: "chevron.down")
                }
                .font(.callout)
                .foregroundStyle(condition ? Color.onControlBackground : .onPrimaryContainer)
                .adaptiveButtonStyle(color: condition ? .controlBackground : .primaryContainer)
            }

            Button {
                DispatchQueue.main.async {
                    store.send(.view(.toggleUnreadOnly))
                }
            } label: {
                let condition = store.query.unreadOnly
                Text(String(localized: "push_unread", bundle: PresentationResources.bundle))
                    .font(.callout)
                    .foregroundStyle(condition ? Color.onPrimaryContainer : .onControlBackground)
                    .adaptiveButtonStyle(color: condition ? .primaryContainer : .controlBackground)
            }
        }
    }

    private var filterBadge: some View {
        Text("\(store.appliedFilterCount)")
            .font(.caption2.weight(.bold))
            .foregroundStyle(Color.accent)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .frame(width: 20, height: 20)
            .background(Circle().fill(Color.accent.opacity(0.1)))
    }
}

struct ToastLabel: View {
    var body: some View {
        Label {
            Text(String(localized: "common_undo", bundle: PresentationResources.bundle))
                .font(.caption)
                .lineLimit(3)
                .foregroundStyle(.blue)
        } icon: {
            Image(systemName: "arrow.uturn.left.circle.fill")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.blue)
            }
    }
}