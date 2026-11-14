//
//  PushNotificationMapperTests.swift
//  InfraTests
//
//  Created by opfic on 7/20/26.
//

import FirebaseFirestore
import Foundation
import Testing
@testable import Infra

struct PushNotificationMapperTests {
    @Test("Todo 제목 문서를 신규 응답으로 변환한다")
    func Todo_제목_문서를_신규_응답으로_변환한다() throws {
        var data = makeData()
        data[PushNotificationFieldKey.todoTitle.rawValue] = "테스트 작성"

        let response = try #require(
            PushNotificationMapper().map(documentID: "notification-1", data: data)
        )

        #expect(response.todoTitle == "테스트 작성")
    }

    private func makeData() -> [String: Any] {
        [
            PushNotificationFieldKey.receivedAt.rawValue: Timestamp(
                date: Date(timeIntervalSince1970: 1)
            ),
            PushNotificationFieldKey.isRead.rawValue: false,
            PushNotificationFieldKey.todoId.rawValue: "todo-1",
            PushNotificationFieldKey.todoCategory.rawValue: "feature",
            PushNotificationFieldKey.isDeleted.rawValue: false
        ]
    }
}
