//
//  PushNotificationResponse.swift
//  Data
//
//  Created by 최윤진 on 2/10/26.
//

import Foundation
import Domain

public struct PushNotificationResponse {
    public let id: String
    public let todoTitle: String?
    public let receivedAt: Date
    public let isRead: Bool
    public let todoId: String
    public let todoCategory: TodoCategoryResponse

    public init(
        id: String,
        todoTitle: String?,
        receivedAt: Date,
        isRead: Bool,
        todoId: String,
        todoCategory: TodoCategoryResponse
    ) {
        self.id = id
        self.todoTitle = todoTitle
        self.receivedAt = receivedAt
        self.isRead = isRead
        self.todoId = todoId
        self.todoCategory = todoCategory
    }
}
