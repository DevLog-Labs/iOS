//
//  PushNotificationItem.swift
//  NotificationTab
//
//  Created by 최윤진 on 2/27/26.
//

import Foundation
import Domain
import PresentationShared

public struct PushNotificationItem: Identifiable, Hashable {
    public let id: String
    public var isHidden = false
    public let receivedAt: Date
    public var isRead: Bool
    public let todoId: String
    public let todoCategory: TodoCategory

    private let todoTitle: String?

    public var title: String {
        return String(localized: "push_notification_todo_due_title", bundle: PresentationResources.bundle)
    }

    public var body: String {
        guard let todoTitle,
              !todoTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return String(
                localized: "push_notification_todo_due_tomorrow_without_title",
                bundle: PresentationResources.bundle
            )
        }
        return String.localizedStringWithFormat(
            String(localized: "push_notification_todo_due_tomorrow_format", bundle: PresentationResources.bundle),
            todoTitle
        )
    }

    public init(from notification: PushNotification) {
        self.id = notification.id
        self.receivedAt = notification.receivedAt
        self.isRead = notification.isRead
        self.todoId = notification.todoId
        self.todoCategory = notification.todoCategory
        self.todoTitle = notification.todoTitle
    }
}
