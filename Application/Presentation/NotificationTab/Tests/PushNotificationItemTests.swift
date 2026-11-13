//
//  PushNotificationItemTests.swift
//  NotificationTabTests
//
//  Created by opfic on 7/20/26.
//

import Foundation
import PresentationShared
import Testing
@testable import NotificationTab

struct PushNotificationItemTests {
    @Test("Todo 제목이 있는 알림의 목록 문구를 현지화한다")
    func Todo_제목이_있는_알림의_목록_문구를_현지화한다() {
        let notification = makePushNotification(
            id: "notification-1",
            number: 1,
            todoTitle: "테스트 작성"
        )
        let item = PushNotificationItem(from: notification)

        #expect(
            item.title
                == String(localized: "push_notification_todo_due_title", bundle: PresentationResources.bundle)
        )
        #expect(
            item.body == String.localizedStringWithFormat(
                String(localized: "push_notification_todo_due_tomorrow_format", bundle: PresentationResources.bundle),
                "테스트 작성"
            )
        )
    }

    @Test("제목 없는 Todo 알림의 목록 문구를 현지화한다")
    func 제목_없는_Todo_알림의_목록_문구를_현지화한다() {
        let notification = makePushNotification(id: "notification-1", number: 1)
        let item = PushNotificationItem(from: notification)

        #expect(
            item.title
                == String(localized: "push_notification_todo_due_title", bundle: PresentationResources.bundle)
        )
        #expect(
            item.body
                == String(
                    localized: "push_notification_todo_due_tomorrow_without_title",
                    bundle: PresentationResources.bundle
                )
        )
    }

    @Test("공백으로만 구성된 Todo 제목을 제목 없는 알림으로 표시한다")
    func 공백으로만_구성된_Todo_제목을_제목_없는_알림으로_표시한다() {
        let notification = makePushNotification(
            id: "notification-1",
            number: 1,
            todoTitle: " \n\t "
        )
        let item = PushNotificationItem(from: notification)

        #expect(
            item.body
                == String(
                    localized: "push_notification_todo_due_tomorrow_without_title",
                    bundle: PresentationResources.bundle
                )
        )
    }
}
