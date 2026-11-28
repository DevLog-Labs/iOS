//
//  PushNotificationListFeature.swift
//  NotificationTab
//
//  Created by opfic on 6/12/26.
//

import Combine
import Core
import Domain
import Foundation
import PresentationShared

@Reducer
struct PushNotificationListFeature {
    @ObservableState
    struct State: Equatable {
        @Presents var alert: AlertState<Never>?
        // 고른 알림의 Todo 상세, 좁은 창은 시트로 띄우고 사이드바가 있는 창은 상세 판이나 오른쪽 칸에 표시
        @Presents var detail: TodoDetailFeature.State?
        var notifications: [PushNotificationItem] = []
        var nextCursor: PushNotificationCursor?
        var query: PushNotificationQuery
        var selectedNotificationId: String?
        // 사이드바가 있는 창에서 목록 오른쪽 칸을 연 상태, 닫혀 있으면 고른 Todo를 상세 판으로 표시
        var showsDetailInPane = false
        var loading = LoadingFeature.State()
        var undoNotificationId: String?

        init(query: PushNotificationQuery = .default) {
            self.query = query
        }

        var isLoading: Bool {
            loading.isLoading
        }

        var appliedFilterCount: Int {
            var count = 0
            if query.sortOrder != .latest { count += 1 }
            if query.timeFilter != .none { count += 1 }
            if query.unreadOnly { count += 1 }
            return count
        }
    }

    enum Action: BindableAction {
        case alert(PresentationAction<Never>)
        case detail(PresentationAction<TodoDetailFeature.Action>)
        case binding(BindingAction<State>)
        case view(ViewAction)
        case store(StoreAction)
        case loading(LoadingFeature.Action)

        enum ViewAction: Equatable {
            case stopObserving
            case startObserving
            case refresh
            case fetchNotifications
            case loadNextPage
            case deleteNotification(PushNotificationItem)
            case toggleRead(PushNotificationItem)
            case undoDelete
            case finishDeleteToast(String)
            case toggleSortOption
            case toggleUnreadOnly
            case resetFilters
            case selectNotification(String?)
        }

        enum StoreAction: Equatable {
            case setAlert
            case appendNotifications([PushNotificationItem], nextCursor: PushNotificationCursor?)
            case replaceNotifications([PushNotificationItem], nextCursor: PushNotificationCursor?)
            case setNotificationHidden(String, Bool)
            case setNotificationRead(String, Bool)
        }
    }

    enum CancelID: Hashable {
        case fetchNotifications
        case fetchNotificationsAndObserve
        case observeNotifications
        case toggleRead
    }

    @Dependency(\.fetchPushNotificationsUseCase) var fetchPushNotificationsUseCase
    @Dependency(\.deletePushNotificationUseCase) var deletePushNotificationUseCase
    @Dependency(\.undoDeletePushNotificationUseCase) var undoDeletePushNotificationUseCase
    @Dependency(\.togglePushNotificationReadUseCase) var togglePushNotificationReadUseCase
    @Dependency(\.updatePushNotificationQueryUseCase) var updatePushNotificationQueryUseCase
    @Dependency(\.date.now) var now

    var body: some ReducerOf<Self> {
        Scope(state: \.loading, action: \.loading) {
            LoadingFeature()
        }
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .alert:
                break
            case .detail(.dismiss):
                state.selectedNotificationId = nil
                // 오른쪽 칸에서 연 알림을 좁은 창의 시트로 닫으면 다시 넓혀도 빈 오른쪽 칸을 열지 않음
                state.showsDetailInPane = false
            case .detail:
                break
            case .binding(\.query.timeFilter):
                state.nextCursor = nil
                state.query.referenceDate = now
                return refreshForQueryChangeEffect(query: state.query)
            case .binding:
                break
            case .view(let action):
                return reduce(action, state: &state)
            case .store(let action):
                return reduce(action, state: &state)
            case .loading:
                break
            }

            return .none
        }
        .ifLet(\.$alert, action: \.alert)
        .ifLet(\.$detail, action: \.detail) {
            TodoDetailFeature()
        }
    }
}

private extension PushNotificationListFeature {
    func reduce(
        _ action: Action.ViewAction,
        state: inout State
    ) -> Effect<Action> {
        switch action {
        case .stopObserving:
            return .cancel(id: CancelID.observeNotifications)
        case .startObserving:
            return observeNotificationsEffect(
                query: state.query,
                limit: state.query.pageSize
            )
        case .refresh:
            state.nextCursor = nil
            state.query.referenceDate = now
            return .concatenate(
                .cancel(id: CancelID.observeNotifications),
                fetchNotificationsPageEffect(
                    query: state.query,
                    cursor: nil,
                    showsIndicator: false
                )
            )
        case .fetchNotifications:
            state.nextCursor = nil
            return .concatenate(
                .cancel(id: CancelID.observeNotifications),
                fetchNotificationsPageEffect(query: state.query, cursor: nil),
                .send(.view(.startObserving))
            )
            .cancellable(id: CancelID.fetchNotificationsAndObserve, cancelInFlight: true)
        case .loadNextPage:
            guard state.nextCursor != nil, !state.isLoading else { return .none }
            return fetchNotificationsPageEffect(
                query: state.query,
                cursor: state.nextCursor
            )
        case .deleteNotification(let item):
            guard state.notifications.contains(where: { $0.id == item.id }) else { return .none }
            state.undoNotificationId = item.id
            Self.setNotificationHidden(&state, notificationId: item.id, isHidden: true)
            return deleteNotificationEffect(item)
        case .toggleRead(let item):
            guard let index = state.notifications.firstIndex(where: { $0.id == item.id }) else {
                return .none
            }
            let isRead = !state.notifications[index].isRead
            state.notifications[index].isRead = isRead
            return toggleReadEffect(notificationId: item.id, todoId: item.todoId, rollbackRead: !isRead)
        case .undoDelete:
            guard let undoNotificationId = state.undoNotificationId else { return .none }
            Self.setNotificationHidden(&state, notificationId: undoNotificationId, isHidden: false)
            state.undoNotificationId = nil
            return undoDeleteEffect(undoNotificationId)
        case .finishDeleteToast(let notificationId):
            state.notifications.removeAll { $0.id == notificationId && $0.isHidden }
            if state.undoNotificationId == notificationId {
                state.undoNotificationId = nil
            }
        case .toggleSortOption:
            state.query.sortOrder = state.query.sortOrder == .latest ? .oldest : .latest
            state.query.referenceDate = now
            state.nextCursor = nil
            return refreshForQueryChangeEffect(query: state.query)
        case .toggleUnreadOnly:
            state.query.unreadOnly.toggle()
            state.query.referenceDate = now
            state.nextCursor = nil
            return refreshForQueryChangeEffect(query: state.query)
        case .resetFilters:
            state.query = .default
            state.query.referenceDate = now
            state.nextCursor = nil
            return refreshForQueryChangeEffect(query: state.query)
        case .selectNotification(let notificationId):
            state.selectedNotificationId = notificationId
            guard let notificationId,
                  let index = state.notifications.firstIndex(where: { $0.id == notificationId }) else {
                state.detail = nil
                return .none
            }
            let item = state.notifications[index]
            // 같은 Todo의 알림은 불러온 상세와 열어 둔 시트를 그대로 둠
            if state.detail?.todoId != item.todoId {
                state.detail = TodoDetailFeature.State(todoId: item.todoId, showEditButton: false)
            }
            guard !item.isRead else { return .none }
            state.notifications[index].isRead = true
            return toggleReadEffect(notificationId: item.id, todoId: item.todoId, rollbackRead: false)
        }

        return .none
    }

    func reduce(
        _ action: Action.StoreAction,
        state: inout State
    ) -> Effect<Action> {
        switch action {
        case .setAlert:
            state.alert = Self.alertState()
        case .appendNotifications(let notifications, let nextCursor):
            state.notifications.append(contentsOf: Self.mergedHiddenNotifications(
                currentNotifications: state.notifications,
                incomingNotifications: notifications
            ))
            state.nextCursor = nextCursor
        case .replaceNotifications(let notifications, let nextCursor):
            state.notifications = Self.mergedHiddenNotifications(
                currentNotifications: state.notifications,
                incomingNotifications: notifications
            )
            state.nextCursor = nextCursor
        case .setNotificationHidden(let notificationId, let isHidden):
            Self.setNotificationHidden(&state, notificationId: notificationId, isHidden: isHidden)
        case .setNotificationRead(let notificationId, let isRead):
            if let index = state.notifications.firstIndex(where: { $0.id == notificationId }) {
                state.notifications[index].isRead = isRead
            }
        }

        return .none
    }

    func refreshForQueryChangeEffect(query: PushNotificationQuery) -> Effect<Action> {
        .merge(
            updateQueryEffect(query: query),
            .concatenate(
                .send(.view(.stopObserving)),
                fetchNotificationsPageEffect(query: query, cursor: nil),
                .send(.view(.startObserving))
            )
            .cancellable(id: CancelID.fetchNotificationsAndObserve, cancelInFlight: true)
        )
    }

    func fetchNotificationsPageEffect(
        query: PushNotificationQuery,
        cursor: PushNotificationCursor?,
        showsIndicator: Bool = true
    ) -> Effect<Action> {
        .run { [fetchPushNotificationsUseCase] send in
            if showsIndicator {
                await send(.loading(.begin(target: .default, mode: .delayed)))
            }
            do {
                let page = try await fetchPushNotificationsUseCase.execute(query, cursor: cursor)
                let notifications = page.items.map(PushNotificationItem.init(from:))
                if cursor == nil {
                    await send(
                        .store(.replaceNotifications(
                            notifications,
                            nextCursor: page.nextCursor
                        ))
                    )
                } else {
                    await send(
                        .store(.appendNotifications(
                            notifications,
                            nextCursor: page.nextCursor
                        ))
                    )
                }
                if showsIndicator {
                    await send(.loading(.end(target: .default, mode: .delayed)))
                }
            } catch {
                if showsIndicator {
                    await send(.loading(.end(target: .default, mode: .delayed)))
                }
                await send(.store(.setAlert))
            }
        }
        .cancellable(id: CancelID.fetchNotifications, cancelInFlight: true)
    }

    func observeNotificationsEffect(
        query: PushNotificationQuery,
        limit: Int
    ) -> Effect<Action> {
        .run { [fetchPushNotificationsUseCase] send in
            do {
                let publisher = try fetchPushNotificationsUseCase.observe(query, limit: limit)
                for try await page in publisher.values {
                    let items = page.items.map(PushNotificationItem.init(from:))
                    await send(.store(.replaceNotifications(items, nextCursor: page.nextCursor)))
                }
            } catch is CancellationError {
            } catch {
                await send(.store(.setAlert))
            }
        }
        .cancellable(id: CancelID.observeNotifications, cancelInFlight: true)
    }

    func deleteNotificationEffect(_ item: PushNotificationItem) -> Effect<Action> {
        .run { [deletePushNotificationUseCase] send in
            do {
                try await deletePushNotificationUseCase.execute(item.id)
            } catch {
                await send(.store(.setNotificationHidden(item.id, false)))
                await send(.store(.setAlert))
            }
        }
    }

    func undoDeleteEffect(_ notificationId: String) -> Effect<Action> {
        .run { [undoDeletePushNotificationUseCase] send in
            do {
                try await undoDeletePushNotificationUseCase.execute(notificationId)
            } catch {
                await send(.store(.setNotificationHidden(notificationId, true)))
                await send(.store(.setAlert))
            }
        }
    }

    func toggleReadEffect(
        notificationId: String,
        todoId: String,
        rollbackRead: Bool
    ) -> Effect<Action> {
        .run { [togglePushNotificationReadUseCase] send in
            await send(.loading(.begin(target: .default, mode: .delayed)))
            do {
                try await togglePushNotificationReadUseCase.execute(todoId)
                await send(.loading(.end(target: .default, mode: .delayed)))
            } catch {
                await send(.store(.setNotificationRead(notificationId, rollbackRead)))
                await send(.loading(.end(target: .default, mode: .delayed)))
                await send(.store(.setAlert))
            }
        }
        .cancellable(id: CancelID.toggleRead, cancelInFlight: true)
    }

    func updateQueryEffect(query: PushNotificationQuery) -> Effect<Action> {
        .run { [updatePushNotificationQueryUseCase] _ in
            updatePushNotificationQueryUseCase.execute(query)
        }
    }

    static func alertState() -> AlertState<Never> {
        AlertState {
            TextState(String(localized: "common_error_title", bundle: PresentationResources.bundle))
        } actions: {
            ButtonState(role: .cancel) {
                TextState(String(localized: "common_close", bundle: PresentationResources.bundle))
            }
        } message: {
            TextState(String(localized: "common_error_message", bundle: PresentationResources.bundle))
        }
    }

    static func setNotificationHidden(
        _ state: inout State,
        notificationId: String,
        isHidden: Bool
    ) {
        if let index = state.notifications.firstIndex(where: { $0.id == notificationId }) {
            state.notifications[index].isHidden = isHidden
        }
    }

    static func mergedHiddenNotifications(
        currentNotifications: [PushNotificationItem],
        incomingNotifications: [PushNotificationItem]
    ) -> [PushNotificationItem] {
        let hiddenNotificationIds = Set(currentNotifications.filter(\.isHidden).map(\.id))

        return incomingNotifications.map { notification in
            guard hiddenNotificationIds.contains(notification.id) else {
                return notification
            }

            var hiddenNotification = notification
            hiddenNotification.isHidden = true
            return hiddenNotification
        }
    }
}
