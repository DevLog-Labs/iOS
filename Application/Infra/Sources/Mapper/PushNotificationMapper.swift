//
//  PushNotificationMapper.swift
//  Infra
//
//  Created by opfic on 7/20/26.
//

import Data
import FirebaseFirestore

struct PushNotificationMapper {
    func map(documentID: String, data: [String: Any]) -> PushNotificationResponse? {
        if (data[PushNotificationFieldKey.isDeleted.rawValue] as? Bool) == true {
            return nil
        }
        guard
            let receivedAt = data[PushNotificationFieldKey.receivedAt.rawValue] as? Timestamp,
            let isRead = data[PushNotificationFieldKey.isRead.rawValue] as? Bool,
            let todoId = data[PushNotificationFieldKey.todoId.rawValue] as? String,
            let todoCategory = data[PushNotificationFieldKey.todoCategory.rawValue] as? String else {
            return nil
        }

        if let todoTitle = data[PushNotificationFieldKey.todoTitle.rawValue] as? String {
            return PushNotificationResponse(
                id: documentID,
                todoTitle: todoTitle,
                receivedAt: receivedAt.dateValue(),
                isRead: isRead,
                todoId: todoId,
                todoCategory: .raw(todoCategory)
            )
        }

        return PushNotificationResponse(
            id: documentID,
            todoTitle: nil,
            receivedAt: receivedAt.dateValue(),
            isRead: isRead,
            todoId: todoId,
            todoCategory: .raw(todoCategory)
        )
    }
}

enum PushNotificationFieldKey: String {
    case todoTitle
    case receivedAt
    case isRead
    case todoId
    case todoCategory
    case isDeleted  // 삭제 요청으로 서버에서 soft deletion이 된 상태
}
