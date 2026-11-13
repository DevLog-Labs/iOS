//
//  PushNotificationMappingTests.swift
//  DataTests
//
//  Created by opfic on 7/20/26.
//

import Foundation
import Testing
import Domain
@testable import Data

struct PushNotificationMappingTests {
    @Test("Todo 제목을 알림 도메인 모델에 전달한다")
    func Todo_제목을_알림_도메인_모델에_전달한다() throws {
        let response = PushNotificationResponse(
            id: "notification-1",
            todoTitle: "테스트 작성",
            receivedAt: Date(timeIntervalSince1970: 1),
            isRead: false,
            todoId: "todo-1",
            todoCategory: .decoded(.system(.feature))
        )

        let notification = try response.toDomain()

        #expect(notification.todoTitle == "테스트 작성")
    }
}
