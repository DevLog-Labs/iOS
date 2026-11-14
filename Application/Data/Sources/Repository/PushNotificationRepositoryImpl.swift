//
//  PushNotificationRepositoryImpl.swift
//  Data
//
//  Created by 최윤진 on 1/18/26.
//

import Foundation
import Combine
import Core
import Domain

final class PushNotificationRepositoryImpl: PushNotificationRepository {
    private enum Key {
        static let preferences = "TodoCategory.preferences"
    }

    private let pushNotificationService: PushNotificationService
    private let todoCategoryService: TodoCategoryService
    private let store: MemoryCacheStore

    init(
        pushNotificationService: PushNotificationService,
        todoCategoryService: TodoCategoryService,
        store: MemoryCacheStore
    ) {
        self.pushNotificationService = pushNotificationService
        self.todoCategoryService = todoCategoryService
        self.store = store
    }

    /// 푸시 알림 On/Off 설정
    func fetchPushNotificationEnabled() async throws -> Bool {
        do {
            return try await pushNotificationService.fetchPushNotificationEnabled()
        } catch {
            throw error.toDomain()
        }
    }

    /// 푸시 알림 시간 설정
    func fetchPushNotificationTime() async throws -> DateComponents {
        do {
            return try await pushNotificationService.fetchPushNotificationTime()
        } catch {
            throw error.toDomain()
        }
    }

    /// 푸시 알림 설정 업데이트
    func updatePushNotificationSettings(_ settings: PushNotificationSettings) async throws {
        do {
            try await pushNotificationService.updatePushNotificationSettings(
                isEnabled: settings.isEnabled, components: settings.scheduledTime
            )
        } catch {
            throw error.toDomain()
        }
    }

    /// 푸시 알림 기록 요청
    func requestNotifications(
        _ query: PushNotificationQuery,
        cursor: PushNotificationCursor?
    ) async throws -> PushNotificationPage {
        do {
            let cursorDTO = cursor.map { PushNotificationCursorDTO.fromDomain($0) }
            async let responseTask = pushNotificationService.requestNotifications(query, cursor: cursorDTO)
            async let preferencesTask = todoCategoryPreferenceResponses()

            let (response, preferenceResponses) = try await (responseTask, preferencesTask)
            return try resolvePage(from: response, with: preferenceResponses.toDomain())
        } catch {
            throw error.toDomain()
        }
    }

    func observeNotifications(
        _ query: PushNotificationQuery,
        limit: Int
    ) throws -> AnyPublisher<PushNotificationPage, Error> {
        let subject = PassthroughSubject<PushNotificationPage, Error>()
        var cancellable: AnyCancellable?

        do {
            cancellable = try pushNotificationService.observeNotifications(query, limit: limit)
                .sink(
                    receiveCompletion: { completion in
                        switch completion {
                        case .finished:
                            subject.send(completion: .finished)
                        case .failure(let error):
                            subject.send(completion: .failure(error.toDomain()))
                        }
                    },
                    receiveValue: { [weak self] response in
                        guard let self else { return }

                        Task {
                            do {
                                let preferences = try await self.todoCategoryPreferenceResponses()
                                    .toDomain()
                                let page = try self.resolvePage(from: response, with: preferences)
                                subject.send(page)
                            } catch {
                                subject.send(completion: .failure(error.toDomain()))
                            }
                        }
                    }
                )
        } catch {
            throw error.toDomain()
        }

        return subject
            .handleEvents(receiveCancel: { cancellable?.cancel() })
            .eraseToAnyPublisher()
    }

    func observeUnreadPushCount() throws -> AnyPublisher<Int, Error> {
        do {
            return try pushNotificationService.observeUnreadPushCount()
                .mapError { $0.toDomain() }
                .eraseToAnyPublisher()
        } catch {
            throw error.toDomain()
        }
    }

    // 푸시 알림 기록 삭제
    func deleteNotification(_ notificationID: String) async throws {
        do {
            try await pushNotificationService.deleteNotification(notificationID)
        } catch {
            throw error.toDomain()
        }
    }

    func undoDeleteNotification(_ notificationID: String) async throws {
        do {
            try await pushNotificationService.undoDeleteNotification(notificationID)
        } catch {
            throw error.toDomain()
        }
    }

    // 푸시 알림 읽음/안읽음 토글
    func toggleNotificationRead(_ todoId: String) async throws {
        do {
            try await pushNotificationService.toggleNotificationRead(todoId)
        } catch {
            throw error.toDomain()
        }
    }
}

private extension PushNotificationRepositoryImpl {
    func todoCategoryPreferenceResponses() async throws -> [TodoCategoryPreferenceResponse] {
        if let preferences: [TodoCategoryPreferenceResponse] = store.value(forKey: Key.preferences) {
            return preferences
        }

        let preferences = try await todoCategoryService.fetchCategoryPreferences()
        store.setValue(preferences, forKey: Key.preferences)
        return preferences
    }

    func resolvePage(
        from response: PushNotificationPageResponse,
        with preferences: [TodoCategoryPreference]
    ) throws -> PushNotificationPage {
        let userTodoCategories: [UserTodoCategory] = preferences.compactMap { preference in
            guard case .user(let userTodoCategory) = preference.category else {
                return nil
            }

            return userTodoCategory
        }

        let responses = try response.items.map {
            try resolve($0, userTodoCategories: userTodoCategories)
        }

        return try PushNotificationPageResponse(
            items: responses,
            nextCursor: response.nextCursor
        ).toDomain()
    }

    // resolvePage() 메서드에서만 사용됨
    private func resolve(
        _ response: PushNotificationResponse,
        userTodoCategories: [UserTodoCategory]
    ) throws -> PushNotificationResponse {
        let id: String
        switch response.todoCategory {
        case .raw(let rawValue):
            id = rawValue
        case .decoded:
            return response
        }

        let todoCategory: TodoCategory
        if let systemTodoCategory = SystemTodoCategory(rawValue: id) {
            todoCategory = .system(systemTodoCategory)
        } else if let userTodoCategory = userTodoCategories.first(where: {
            $0.id == id
        }) {
            todoCategory = .user(userTodoCategory)
        } else {
            throw DataLayerError.invalidData("PushNotificationResponse.todoCategory is invalid: \(id)")
        }

        return PushNotificationResponse(
            id: response.id,
            todoTitle: response.todoTitle,
            receivedAt: response.receivedAt,
            isRead: response.isRead,
            todoId: response.todoId,
            todoCategory: .decoded(todoCategory)
        )
    }
}
