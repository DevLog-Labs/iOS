//
//  PushNotificationListTestSupport.swift
//  NotificationTabTests
//
//  Created by opfic on 6/12/26.
//

import Testing
import Combine
import Core
import Domain
import PresentationShared
import Foundation
@testable import NotificationTab

@MainActor
protocol PushNotificationListStateDriving {
    var notifications: [PushNotificationItem] { get }
    var query: PushNotificationQuery { get }
    var nextCursor: PushNotificationCursor? { get }
    var selectedNotificationId: String? { get }
    var selectedTodoId: TodoIdItem? { get }
    var appliedFilterCount: Int { get }

    func startObserving() async
    func refresh() async
    func fetchNotifications() async
    func loadNextPage() async
    func toggleSortOption() async
    func setTimeFilter(_ filter: PushNotificationQuery.TimeFilter) async
    func toggleUnreadOnly() async
    func resetFilters() async
    func selectNotification(_ notificationId: String?) async
    func toggleRead(_ item: PushNotificationItem) async
    func deleteNotification(_ item: PushNotificationItem) async
    func undoDelete() async
    func finishDeleteToast(_ notificationId: String) async
}

@MainActor
struct PushNotificationListStoreTestAdapter: PushNotificationListStateDriving {
    private let store: TestStoreOf<PushNotificationListFeature>

    var notifications: [PushNotificationItem] { store.state.notifications }
    var query: PushNotificationQuery { store.state.query }
    var nextCursor: PushNotificationCursor? { store.state.nextCursor }
    var selectedNotificationId: String? { store.state.selectedNotificationId }
    var selectedTodoId: TodoIdItem? { store.state.selectedTodoId }
    var appliedFilterCount: Int { store.state.appliedFilterCount }
    var sheetTodoId: String? { store.state.sheet?.todoId }

    init(
        fetchUseCase: FetchPushNotificationsUseCase = PushNotificationListFetchUseCaseSpy(),
        deleteUseCase: DeletePushNotificationUseCase = DeletePushNotificationUseCaseSpy(),
        undoDeleteUseCase: UndoDeletePushNotificationUseCase = UndoDeletePushNotificationUseCaseSpy(),
        toggleReadUseCase: TogglePushNotificationReadUseCase = TogglePushNotificationReadUseCaseSpy(),
        fetchQueryUseCase: FetchPushNotificationQueryUseCase = FetchPushNotificationQueryUseCaseSpy(),
        updateQueryUseCase: UpdatePushNotificationQueryUseCase = UpdatePushNotificationQueryUseCaseSpy(),
        now: Date? = nil,
        configureDependencies: ((inout DependencyValues) -> Void)? = nil
    ) {
        store = TestStore(
            initialState: PushNotificationListFeature.State(
                query: fetchQueryUseCase.execute()
            )
        ) {
            PushNotificationListFeature()
        } withDependencies: {
            $0.fetchPushNotificationsUseCase = fetchUseCase
            $0.deletePushNotificationUseCase = deleteUseCase
            $0.undoDeletePushNotificationUseCase = undoDeleteUseCase
            $0.togglePushNotificationReadUseCase = toggleReadUseCase
            $0.updatePushNotificationQueryUseCase = updateQueryUseCase
            $0.continuousClock = ContinuousClock()
            if let now {
                $0.date.now = now
            }
            configureDependencies?(&$0)
        }
        store.exhaustivity = .off(showSkippedAssertions: false)
    }

    func startObserving() async {
        await store.send(.view(.startObserving))
        await drainReceivedActions()
    }

    func refresh() async {
        let task = await store.send(.view(.refresh))
        await drainReceivedActions()
        await task.finish()
        await drainReceivedActions()
    }

    func fetchNotifications() async {
        await store.send(.view(.fetchNotifications))
        await drainReceivedActions()
    }

    func loadNextPage() async {
        await store.send(.view(.loadNextPage))
        await drainReceivedActions()
    }

    func toggleSortOption() async {
        await store.send(.view(.toggleSortOption))
        await drainReceivedActions()
    }

    func setTimeFilter(_ filter: PushNotificationQuery.TimeFilter) async {
        await store.send(.binding(.set(\.query.timeFilter, filter)))
        await drainReceivedActions()
    }

    func toggleUnreadOnly() async {
        await store.send(.view(.toggleUnreadOnly))
        await drainReceivedActions()
    }

    func resetFilters() async {
        await store.send(.view(.resetFilters))
        await drainReceivedActions()
    }

    func selectNotification(_ notificationId: String?) async {
        await store.send(.view(.selectNotification(notificationId)))
        await drainReceivedActions()
    }

    func toggleRead(_ item: PushNotificationItem) async {
        await store.send(.view(.toggleRead(item)))
        await drainReceivedActions()
    }

    func deleteNotification(_ item: PushNotificationItem) async {
        await store.send(.view(.deleteNotification(item)))
        presentDeleteNotificationToast(item.id)
        await drainReceivedActions()
    }

    func undoDelete() async {
        await store.send(.view(.undoDelete))
        await drainReceivedActions()
    }

    func finishDeleteToast(_ notificationId: String) async {
        await store.send(.view(.finishDeleteToast(notificationId)))
    }

    func syncSheetPresentation() async {
        await store.send(.view(.syncSheetPresentation))
    }

    func dismissSheet() async {
        await store.send(.sheet(.dismiss))
    }

    func finishEffects() async {
        await drainReceivedActions()
        await store.finish()
    }

    // TestStore는 effect가 보낸 액션을 받음 처리해야 state에 반영하므로 대기 중에도 받은 액션을 처리
    func waitForNotifications(_ ids: [String]) async {
        let continuousClock = ContinuousClock()
        let deadline = continuousClock.now + .seconds(1)

        while notifications.map(\.id) != ids && continuousClock.now < deadline {
            await drainReceivedActions()
            try? await Task.sleep(for: .milliseconds(20))
        }
    }

    private func presentDeleteNotificationToast(_ notificationId: String) {
        ToastPresenter.present(
            duration: 5,
            action: {
                Task { @MainActor in
                    await undoDelete()
                }
            },
            onDismiss: {
                Task { @MainActor in
                    await finishDeleteToast(notificationId)
                }
            }
        ) {
            ToastLabel()
        }
    }

    private func drainReceivedActions() async {
        for _ in 0..<8 {
            await store.skipReceivedActions(strict: false)
        }
    }
}

final class PushNotificationListFetchUseCaseSpy: FetchPushNotificationsUseCase {
    var pages: [PushNotificationPage]
    var error: Error?
    var observePublisher: AnyPublisher<PushNotificationPage, Error>
    var shouldSuspend = false
    private(set) var queries = [PushNotificationQuery]()
    private(set) var cursors = [PushNotificationCursor?]()
    private(set) var observedQueries = [PushNotificationQuery]()
    private(set) var observedLimits = [Int]()
    private var continuation: CheckedContinuation<Void, Never>?
    private var shouldResume = false

    init(
        pages: [PushNotificationPage] = [PushNotificationPage(items: [], nextCursor: nil)],
        observePublisher: AnyPublisher<PushNotificationPage, Error> = Empty().eraseToAnyPublisher()
    ) {
        self.pages = pages
        self.observePublisher = observePublisher
    }

    func execute(
        _ query: PushNotificationQuery,
        cursor: PushNotificationCursor?
    ) async throws -> PushNotificationPage {
        queries.append(query)
        cursors.append(cursor)

        if shouldSuspend {
            await withCheckedContinuation { continuation in
                if shouldResume {
                    shouldResume = false
                    continuation.resume()
                } else {
                    self.continuation = continuation
                }
            }
        }

        if let error {
            throw error
        }

        let index = queries.count - 1
        if pages.count <= index {
            return pages.last ?? PushNotificationPage(items: [], nextCursor: nil)
        }
        return pages[index]
    }

    func observe(
        _ query: PushNotificationQuery,
        limit: Int
    ) throws -> AnyPublisher<PushNotificationPage, Error> {
        observedQueries.append(query)
        observedLimits.append(limit)
        return observePublisher
    }

    func resume() {
        guard let continuation else {
            shouldResume = true
            return
        }

        self.continuation = nil
        continuation.resume()
    }
}

final class ObservationCancellationSpy {
    private(set) var callCount = 0

    func call() {
        callCount += 1
    }
}
