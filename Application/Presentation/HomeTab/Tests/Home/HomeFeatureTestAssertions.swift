//
//  HomeFeatureTestAssertions.swift
//  HomeTabTests
//
//  Created by opfic on 6/14/26.
//

import Testing
import Foundation
import Domain
import PresentationShared
@testable import HomeTab

@MainActor
func verifyHomeFetchData(
    adapter: StoreTestAdapter
) async throws {
    await adapter.fetchData()

    await waitUntil {
        adapter.preferences.count == 2
    }

    #expect(adapter.preferences.map(\.id) == ["feature", "custom"])
}

@MainActor
func verifyHomeTapTodoCategory(
    adapter: StoreTestAdapter
) async throws {
    await adapter.setPresentation(.contentPicker, true)
    await adapter.tapTodoCategory(.system(.feature))

    #expect(!adapter.showContentPicker)
    #expect(adapter.showTodoEditor)
}

struct FetchDataContext {
    let fetchPreferencesUseCaseSpy: FetchTodoCategoryPreferencesUseCaseSpy
}

func makeDevelopmentGoal(
    id: String,
    createdAt: TimeInterval
) throws -> DevelopmentGoal {
    try DevelopmentGoal(
        id: id,
        title: "Goal \(id)",
        description: "Description",
        status: .inProgress,
        createdAt: Date(timeIntervalSinceReferenceDate: createdAt),
        updatedAt: Date(timeIntervalSinceReferenceDate: createdAt),
        completedAt: nil
    )
}

func makeDevelopmentRecordVersion(
    id: String,
    recordID: String,
    title: String,
    confirmedAt: TimeInterval
) throws -> DevelopmentRecord.Version {
    try DevelopmentRecord.Version(
        id: id,
        recordId: recordID,
        number: 1,
        title: title,
        markdownContent: "",
        kind: .initial,
        sourceVersionId: nil,
        confirmedAt: Date(timeIntervalSinceReferenceDate: confirmedAt)
    )
}

func makeHomeTodo(
    id: String,
    goalID: String?,
    isCompleted: Bool
) -> Todo {
    Todo(
        id: id,
        isPinned: false,
        isCompleted: isCompleted,
        isChecked: false,
        number: 1,
        title: "Todo \(id)",
        content: "",
        createdAt: .now,
        updatedAt: .now,
        completedAt: isCompleted ? .now : nil,
        deletedAt: nil,
        dueDate: nil,
        tags: [],
        category: .system(.feature),
        goalId: goalID
    )
}

func makeHomeFetchDataContext() -> FetchDataContext {
    let fetchPreferencesUseCaseSpy = FetchTodoCategoryPreferencesUseCaseSpy()
    fetchPreferencesUseCaseSpy.todoCategoryPreferences = [
        TodoCategoryPreference(category: .system(.feature), isVisible: true),
        TodoCategoryPreference(
            category: .user(
                UserTodoCategory(
                    id: "custom",
                    name: "Custom",
                    colorHex: "#111111"
                )
            ),
            isVisible: true
        )
    ]

    return FetchDataContext(
        fetchPreferencesUseCaseSpy: fetchPreferencesUseCaseSpy
    )
}
