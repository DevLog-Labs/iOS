//
//  PushNotificationListTestAssertions.swift
//  NotificationTabTests
//
//  Created by opfic on 6/12/26.
//

import Testing
import Core
import Domain
import PresentationShared
import Foundation
@testable import NotificationTab

@MainActor
func waitUntilMainActor(
    timeout: Duration = .seconds(1),
    pollInterval: Duration = .milliseconds(20),
    _ condition: @escaping @MainActor () -> Bool
) async {
    let continuousClock = ContinuousClock()
    let deadline = continuousClock.now + timeout

    while !condition() && continuousClock.now < deadline {
        try? await Task.sleep(for: pollInterval)
    }
}

@MainActor
func verifyFetchNotifications<Adapter: PushNotificationListStateDriving>(
    adapter: Adapter,
    fetchUseCaseSpy: PushNotificationListFetchUseCaseSpy
) async throws {
    let expectedItems = fetchUseCaseSpy.pages[0].items.map(PushNotificationItem.init(from:))

    await adapter.fetchNotifications()

    await waitUntilMainActor {
        adapter.notifications.count == expectedItems.count
    }

    let notifications = adapter.notifications
    #expect(fetchUseCaseSpy.queries.map(\.pageSize) == [20])
    #expect(fetchUseCaseSpy.cursors.map { $0?.documentID } == [nil])
    #expect(notifications == expectedItems)
    #expect(adapter.nextCursor == fetchUseCaseSpy.pages[0].nextCursor)
}

@MainActor
func verifyLoadNextPage<Adapter: PushNotificationListStateDriving>(
    adapter: Adapter,
    fetchUseCaseSpy: PushNotificationListFetchUseCaseSpy,
    nextNotification: PushNotification
) async throws {
    await adapter.fetchNotifications()

    await waitUntilMainActor {
        adapter.notifications.count == 20
    }

    let nextCursorId = try #require(fetchUseCaseSpy.pages.first?.nextCursor?.documentID)

    await adapter.loadNextPage()

    await waitUntilMainActor {
        adapter.notifications.count == 21
    }

    let notifications = adapter.notifications
    #expect(fetchUseCaseSpy.cursors.map { $0?.documentID } == [nil, nextCursorId])
    #expect(notifications.last == PushNotificationItem(from: nextNotification))
    #expect(adapter.nextCursor == nil)
}

@MainActor
func verifyFilterStateTransitions<Adapter: PushNotificationListStateDriving>(
    adapter: Adapter,
    updateQueryUseCaseSpy: UpdatePushNotificationQueryUseCaseSpy,
    referenceDate: Date
) async throws {
    await adapter.toggleSortOption()
    await adapter.setTimeFilter(.hours(24))
    await adapter.toggleUnreadOnly()

    let query = adapter.query
    let appliedFilterCount = adapter.appliedFilterCount
    #expect(query.sortOrder == .oldest)
    #expect(query.timeFilter == .hours(24))
    #expect(query.unreadOnly)
    #expect(appliedFilterCount == 3)
    #expect(updateQueryUseCaseSpy.queries == [
        PushNotificationQuery(
            sortOrder: .oldest,
            timeFilter: .none,
            unreadOnly: false,
            pageSize: 20,
            referenceDate: referenceDate
        ),
        PushNotificationQuery(
            sortOrder: .oldest,
            timeFilter: .hours(24),
            unreadOnly: false,
            pageSize: 20,
            referenceDate: referenceDate
        ),
        PushNotificationQuery(
            sortOrder: .oldest,
            timeFilter: .hours(24),
            unreadOnly: true,
            pageSize: 20,
            referenceDate: referenceDate
        )
    ])

    await adapter.resetFilters()

    let resetQuery = adapter.query
    let resetAppliedFilterCount = adapter.appliedFilterCount
    #expect(resetQuery.sortOrder == .latest)
    #expect(resetQuery.timeFilter == .none)
    #expect(!resetQuery.unreadOnly)
    #expect(resetQuery.pageSize == 20)
    #expect(resetQuery.referenceDate == referenceDate)
    #expect(resetAppliedFilterCount == 0)
    #expect(updateQueryUseCaseSpy.queries.last == resetQuery)
}

@MainActor
func verifySelectNotification<Adapter: PushNotificationListStateDriving>(
    adapter: Adapter,
    toggleReadUseCaseSpy: TogglePushNotificationReadUseCaseSpy
) async throws {
    await adapter.fetchNotifications()

    await waitUntilMainActor {
        adapter.notifications.count == 1
    }

    await adapter.selectNotification("notification-1")

    let selectedNotificationId = adapter.selectedNotificationId
    let detailTodoId = adapter.detailTodoId
    let notifications = adapter.notifications
    #expect(selectedNotificationId == "notification-1")
    #expect(detailTodoId == "todo-1")
    #expect(notifications.first?.isRead == true)

    await waitUntilMainActor {
        toggleReadUseCaseSpy.calledTodoIds == ["todo-1"]
    }

    await adapter.selectNotification(nil)

    let resetSelectedNotificationId = adapter.selectedNotificationId
    let resetDetailTodoId = adapter.detailTodoId
    #expect(resetSelectedNotificationId == nil)
    #expect(resetDetailTodoId == nil)
}

@MainActor
func verifyToggleRead<Adapter: PushNotificationListStateDriving>(
    adapter: Adapter,
    toggleReadUseCaseSpy: TogglePushNotificationReadUseCaseSpy
) async throws {
    await adapter.fetchNotifications()

    await waitUntilMainActor {
        adapter.notifications.count == 1
    }

    let initialNotifications = adapter.notifications
    let item = try #require(initialNotifications.first)

    await adapter.toggleRead(item)

    let notifications = adapter.notifications
    #expect(notifications.first?.isRead == false)

    await waitUntilMainActor {
        toggleReadUseCaseSpy.calledTodoIds == ["todo-1"]
    }
}

@MainActor
func verifyDeleteUndoAndFinishToast<Adapter: PushNotificationListStateDriving>(
    adapter: Adapter,
    deleteUseCaseSpy: DeletePushNotificationUseCaseSpy,
    undoDeleteUseCaseSpy: UndoDeletePushNotificationUseCaseSpy
) async throws {
    ToastPresenter.reset()
    defer { ToastPresenter.reset() }

    await adapter.fetchNotifications()

    await waitUntilMainActor {
        adapter.notifications.count == 1
    }

    let initialNotifications = adapter.notifications
    let item = try #require(initialNotifications.first)

    await adapter.deleteNotification(item)

    let deletedNotifications = adapter.notifications
    let toast = try #require(ToastPresenter.item)
    let undo = try #require(toast.action)
    #expect(deletedNotifications.first?.isHidden == true)
    #expect(toast.duration == 5)
    #expect(toast.onDismiss != nil)

    await waitUntilMainActor {
        deleteUseCaseSpy.calledNotificationIds == ["notification-1"]
    }

    undo()

    await waitUntilMainActor {
        adapter.notifications.first?.isHidden == false
    }

    let restoredNotifications = adapter.notifications
    #expect(restoredNotifications.first?.isHidden == false)

    await waitUntilMainActor {
        undoDeleteUseCaseSpy.calledNotificationIds == ["notification-1"]
    }

    await adapter.deleteNotification(item)
    let finish = try #require(ToastPresenter.item?.onDismiss)
    finish()

    await waitUntilMainActor {
        adapter.notifications.isEmpty
    }

    let finalNotifications = adapter.notifications
    #expect(finalNotifications.isEmpty)
}
