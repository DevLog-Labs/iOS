//
//  PushNotificationListFeatureTests.swift
//  NotificationTabTests
//
//  Created by opfic on 6/12/26.
//

import Combine
import Foundation
import Testing
import Core
import Domain
@testable import NotificationTab

@MainActor
struct PushNotificationListFeatureTests {
    @Test("시간 필터는 query 기준 Date로 threshold를 계산한다")
    func 시간_필터는_query_기준_Date로_threshold를_계산한다() {
        let referenceDate = Date(timeIntervalSince1970: 100_000)

        #expect(
            PushNotificationQuery.TimeFilter.hours(24)
                .thresholdDate(relativeTo: referenceDate)
                == referenceDate.addingTimeInterval(-86_400)
        )
    }

    @Test("refresh는 기준 Date를 갱신한 query로 첫 페이지를 조회한다")
    func refresh는_기준_Date를_갱신한_query로_첫_페이지를_조회한다() async {
        let referenceDate = Date(timeIntervalSince1970: 1_000)
        let now = Date(timeIntervalSince1970: 2_000)
        let query = PushNotificationQuery(
            sortOrder: .latest,
            timeFilter: .hours(24),
            unreadOnly: false,
            pageSize: 20,
            referenceDate: referenceDate
        )
        let querySpy = FetchPushNotificationQueryUseCaseSpy()
        querySpy.pushNotificationQuery = query
        let fetchSpy = PushNotificationListFetchUseCaseSpy(pages: [
            PushNotificationPage(items: [], nextCursor: nil)
        ])
        let adapter = PushNotificationListStoreTestAdapter(
            fetchUseCase: fetchSpy,
            fetchQueryUseCase: querySpy,
            now: now
        )

        await adapter.refresh()

        let refreshedQuery = adapter.query
        #expect(refreshedQuery.referenceDate == now)
        #expect(fetchSpy.queries == [refreshedQuery])
        #expect(fetchSpy.cursors == [nil])
    }

    @Test("refresh 후 listener는 조회와 같은 기준 Date를 사용한다")
    func refresh_후_listener는_조회와_같은_기준_Date를_사용한다() async {
        let subject = PassthroughSubject<PushNotificationPage, Error>()
        let referenceDate = Date(timeIntervalSince1970: 1_000)
        let now = Date(timeIntervalSince1970: 2_000)
        let query = PushNotificationQuery(
            sortOrder: .latest,
            timeFilter: .hours(24),
            unreadOnly: false,
            pageSize: 20,
            referenceDate: referenceDate
        )
        let querySpy = FetchPushNotificationQueryUseCaseSpy()
        querySpy.pushNotificationQuery = query
        let fetchSpy = PushNotificationListFetchUseCaseSpy(
            pages: [PushNotificationPage(items: [], nextCursor: nil)],
            observePublisher: subject.eraseToAnyPublisher()
        )
        let adapter = PushNotificationListStoreTestAdapter(
            fetchUseCase: fetchSpy,
            fetchQueryUseCase: querySpy,
            now: now
        )

        await adapter.refresh()
        await adapter.startObserving()

        let refreshedQuery = adapter.query
        #expect(fetchSpy.queries == [refreshedQuery])
        #expect(fetchSpy.observedQueries == [refreshedQuery])
        #expect(fetchSpy.observedLimits == [refreshedQuery.pageSize])

        subject.send(completion: .finished)
        await adapter.finishEffects()
    }

    @Test("refresh 실패와 관계없이 기준 Date를 갱신한다")
    func refresh_실패와_관계없이_기준_Date를_갱신한다() async {
        struct DummyError: Error {}

        let referenceDate = Date(timeIntervalSince1970: 1_000)
        let now = Date(timeIntervalSince1970: 2_000)
        let query = PushNotificationQuery(
            sortOrder: .latest,
            timeFilter: .hours(24),
            unreadOnly: false,
            pageSize: 20,
            referenceDate: referenceDate
        )
        let querySpy = FetchPushNotificationQueryUseCaseSpy()
        querySpy.pushNotificationQuery = query
        let fetchSpy = PushNotificationListFetchUseCaseSpy()
        fetchSpy.error = DummyError()
        let adapter = PushNotificationListStoreTestAdapter(
            fetchUseCase: fetchSpy,
            fetchQueryUseCase: querySpy,
            now: now
        )

        await adapter.refresh()

        #expect(adapter.query.referenceDate == now)
    }

    @Test("refresh는 listener를 중단하고 조회 완료 후 재구독한 결과를 반영한다")
    func refresh는_listener를_중단하고_조회_완료_후_재구독한_결과를_반영한다() async {
        let subject = PassthroughSubject<PushNotificationPage, Error>()
        let cancellationSpy = ObservationCancellationSpy()
        let initialNotification = makePushNotification(id: "initial", number: 0)
        let refreshingNotification = makePushNotification(id: "refreshing", number: 1)
        let fetchedNotification = makePushNotification(id: "fetched", number: 2)
        let observedNotification = makePushNotification(id: "observed", number: 3)
        let now = Date(timeIntervalSince1970: 2_000)
        let fetchSpy = PushNotificationListFetchUseCaseSpy(
            pages: [
                PushNotificationPage(items: [fetchedNotification], nextCursor: nil)
            ],
            observePublisher: subject
                .handleEvents(receiveCancel: cancellationSpy.call)
                .eraseToAnyPublisher()
        )
        fetchSpy.shouldSuspend = true
        let adapter = PushNotificationListStoreTestAdapter(
            fetchUseCase: fetchSpy,
            now: now
        )

        await adapter.startObserving()
        subject.send(PushNotificationPage(items: [initialNotification], nextCursor: nil))
        await adapter.waitForNotifications([initialNotification.id])

        let task = Task { await adapter.refresh() }
        await waitUntilMainActor {
            fetchSpy.queries.count == 1
        }

        #expect(cancellationSpy.callCount == 1)

        subject.send(PushNotificationPage(items: [refreshingNotification], nextCursor: nil))
        try? await Task.sleep(for: .milliseconds(50))
        #expect(adapter.notifications.map(\.id) == [initialNotification.id])

        fetchSpy.resume()
        await task.value

        #expect(adapter.notifications.map(\.id) == [fetchedNotification.id])

        await adapter.startObserving()
        subject.send(PushNotificationPage(items: [observedNotification], nextCursor: nil))
        await adapter.waitForNotifications([observedNotification.id])

        #expect(adapter.notifications.map(\.id) == [observedNotification.id])

        subject.send(completion: .finished)
        await adapter.finishEffects()
    }

    @Test("fetchNotifications는 첫 페이지를 조회하고 목록과 nextCursor 상태를 갱신한다")
    func fetchNotifications는_첫_페이지를_조회하고_목록과_nextCursor_상태를_갱신한다() async throws {
        let cursor = makePushNotificationCursor(documentID: "cursor-1")
        let notifications = (0..<20).map {
            makePushNotification(id: "notification-\($0)", number: $0, isRead: $0.isMultiple(of: 2))
        }
        let fetchSpy = PushNotificationListFetchUseCaseSpy(pages: [
            PushNotificationPage(items: notifications, nextCursor: cursor)
        ])
        let adapter = PushNotificationListStoreTestAdapter(fetchUseCase: fetchSpy)

        try await verifyFetchNotifications(adapter: adapter, fetchUseCaseSpy: fetchSpy)
    }

    @Test("loadNextPage는 다음 커서로 조회한 알림을 기존 목록 뒤에 추가한다")
    func loadNextPage는_다음_커서로_조회한_알림을_기존_목록_뒤에_추가한다() async throws {
        let cursor = makePushNotificationCursor(documentID: "cursor-1")
        let firstPage = (0..<20).map {
            makePushNotification(id: "notification-\($0)", number: $0)
        }
        let nextNotification = makePushNotification(id: "notification-next", number: 20)
        let fetchSpy = PushNotificationListFetchUseCaseSpy(pages: [
            PushNotificationPage(items: firstPage, nextCursor: cursor),
            PushNotificationPage(items: [nextNotification], nextCursor: nil)
        ])
        let adapter = PushNotificationListStoreTestAdapter(fetchUseCase: fetchSpy)

        try await verifyLoadNextPage(
            adapter: adapter,
            fetchUseCaseSpy: fetchSpy,
            nextNotification: nextNotification
        )
    }

    @Test("nextCursor가 없으면 페이지 크기만큼 조회해도 다음 페이지를 요청하지 않는다")
    func nextCursor가_없으면_페이지_크기만큼_조회해도_다음_페이지를_요청하지_않는다() async {
        let notifications = (0..<20).map {
            makePushNotification(id: "notification-\($0)", number: $0)
        }
        let fetchSpy = PushNotificationListFetchUseCaseSpy(pages: [
            PushNotificationPage(items: notifications, nextCursor: nil)
        ])
        let adapter = PushNotificationListStoreTestAdapter(fetchUseCase: fetchSpy)

        await adapter.fetchNotifications()
        await adapter.loadNextPage()

        #expect(fetchSpy.cursors.count == 1)
    }

    @Test("필터 액션은 query와 적용 필터 수를 갱신한다")
    func 필터_액션은_query와_적용_필터_수를_갱신한다() async throws {
        let now = Date(timeIntervalSince1970: 2_000)
        let updateSpy = UpdatePushNotificationQueryUseCaseSpy()
        let adapter = PushNotificationListStoreTestAdapter(
            updateQueryUseCase: updateSpy,
            now: now
        )

        try await verifyFilterStateTransitions(
            adapter: adapter,
            updateQueryUseCaseSpy: updateSpy,
            referenceDate: now
        )
    }

    @Test("selectNotification은 선택 상태를 바꾸고 읽지 않은 알림을 읽음 처리한다")
    func selectNotification은_선택_상태를_바꾸고_읽지_않은_알림을_읽음_처리한다() async throws {
        let fetchSpy = PushNotificationListFetchUseCaseSpy(pages: [
            PushNotificationPage(
                items: [
                    makePushNotification(id: "notification-1", number: 1, isRead: false)
                ],
                nextCursor: nil
            )
        ])
        let toggleSpy = TogglePushNotificationReadUseCaseSpy()
        let adapter = PushNotificationListStoreTestAdapter(
            fetchUseCase: fetchSpy,
            toggleReadUseCase: toggleSpy
        )

        try await verifySelectNotification(
            adapter: adapter,
            toggleReadUseCaseSpy: toggleSpy
        )
    }

    @Test("toggleRead는 알림 읽음 상태를 토글하고 유스케이스를 호출한다")
    func toggleRead는_알림_읽음_상태를_토글하고_유스케이스를_호출한다() async throws {
        let fetchSpy = PushNotificationListFetchUseCaseSpy(pages: [
            PushNotificationPage(
                items: [
                    makePushNotification(id: "notification-1", number: 1, isRead: true)
                ],
                nextCursor: nil
            )
        ])
        let toggleSpy = TogglePushNotificationReadUseCaseSpy()
        let adapter = PushNotificationListStoreTestAdapter(
            fetchUseCase: fetchSpy,
            toggleReadUseCase: toggleSpy
        )

        try await verifyToggleRead(
            adapter: adapter,
            toggleReadUseCaseSpy: toggleSpy
        )
    }

    @Test("toggleRead 실패 시 읽음 상태를 원래 값으로 롤백한다")
    func toggleRead_실패_시_읽음_상태를_원래_값으로_롤백한다() async throws {
        struct DummyError: Error {}

        let fetchSpy = PushNotificationListFetchUseCaseSpy(pages: [
            PushNotificationPage(
                items: [
                    makePushNotification(id: "notification-1", number: 1, isRead: true)
                ],
                nextCursor: nil
            )
        ])
        let toggleSpy = TogglePushNotificationReadUseCaseSpy()
        toggleSpy.error = DummyError()
        let adapter = PushNotificationListStoreTestAdapter(
            fetchUseCase: fetchSpy,
            toggleReadUseCase: toggleSpy
        )

        await adapter.fetchNotifications()
        let item = try #require(adapter.notifications.first)

        await adapter.toggleRead(item)

        #expect(adapter.notifications.first?.isRead == true)
    }

    @Test("syncSheetPresentation은 선택한 Todo를 시트로 표시한다")
    func syncSheetPresentation은_선택한_Todo를_시트로_표시한다() async throws {
        let fetchSpy = PushNotificationListFetchUseCaseSpy(pages: [
            PushNotificationPage(
                items: [
                    makePushNotification(id: "notification-1", number: 1, isRead: true)
                ],
                nextCursor: nil
            )
        ])
        let adapter = PushNotificationListStoreTestAdapter(fetchUseCase: fetchSpy)

        await adapter.fetchNotifications()
        await adapter.selectNotification("notification-1")

        await adapter.syncSheetPresentation()

        #expect(adapter.sheetTodoId == "todo-1")

        await adapter.dismissSheet()

        #expect(adapter.sheetTodoId == nil)
        #expect(adapter.selectedNotificationId == nil)
        #expect(adapter.selectedTodoId == nil)
    }

    @Test("delete와 undoDelete는 숨김 상태와 최종 제거 상태를 제어한다")
    func delete와_undoDelete는_숨김_상태와_최종_제거_상태를_제어한다() async throws {
        let fetchSpy = PushNotificationListFetchUseCaseSpy(pages: [
            PushNotificationPage(
                items: [makePushNotification(id: "notification-1", number: 1)],
                nextCursor: nil
            )
        ])
        let deleteSpy = DeletePushNotificationUseCaseSpy()
        let undoSpy = UndoDeletePushNotificationUseCaseSpy()
        let adapter = PushNotificationListStoreTestAdapter(
            fetchUseCase: fetchSpy,
            deleteUseCase: deleteSpy,
            undoDeleteUseCase: undoSpy
        )

        try await verifyDeleteUndoAndFinishToast(
            adapter: adapter,
            deleteUseCaseSpy: deleteSpy,
            undoDeleteUseCaseSpy: undoSpy
        )
    }
}
