//
//  TodayFeature+State.swift
//  TodayTab
//
//  Created by opfic on 6/14/26.
//

import Foundation
import PresentationShared

extension TodayFeature {
    struct TodayAchievement: Equatable {
        enum Status: Equatable {
            case empty
            case inProgress
            case completed
        }

        let completedCount: Int
        let totalCount: Int

        var progress: Double {
            guard totalCount != 0 else { return 0 }
            return Double(completedCount) / Double(totalCount)
        }

        var status: Status {
            guard totalCount != 0 else { return .empty }
            return completedCount == totalCount ? .completed : .inProgress
        }
    }

    @ObservableState
    struct State: Equatable {
        @Presents var alert: AlertState<Never>?
        var todos = [TodayTodoItem]()
        var completedTodayTodos = [TodayTodoItem]()
        var categories = [TodoCategoryItem]()
        var selectedTodoScope = TodoScope.remaining
        var selectedCategoryID: String?
        var isCategoryFilterPresented = false
        var isTodoInspectorPresented = false
        var selectedTodoId: String?
        var todoEditor: TodoEditorFeature.State?
        var dismissesTodoInspectorAfterSaving = false
        var loading = LoadingFeature.State()
        var todayInterval: DateInterval
        var isIncompleteDataLoaded = false
        var isCompletedTodayDataLoaded = false

        init(now: Date = Date()) {
            self.todayInterval = TodayFeature.dayInterval(containing: now)
        }

        var isLoading: Bool {
            loading.isLoading
        }

        var isTodayDataLoaded: Bool {
            isIncompleteDataLoaded && isCompletedTodayDataLoaded
        }

        var visibleCategories: [TodoCategoryItem] {
            categories.filter(\.isVisible)
        }

        var selectedCategory: TodoCategoryItem? {
            visibleCategories.first { $0.id == selectedCategoryID }
        }

        var hasActiveFilters: Bool {
            selectedTodoScope == .important || selectedCategoryID != nil
        }

        var todayTodos: [TodayTodoItem] {
            guard isTodayDataLoaded else { return [] }
            return TodayFeature.todayTodos(
                incompleteTodos: todos,
                completedTodos: completedTodayTodos,
                interval: todayInterval
            )
        }

        var todayAchievement: TodayAchievement? {
            guard isTodayDataLoaded else { return nil }
            return TodayFeature.achievement(
                incompleteTodos: todos,
                completedTodos: completedTodayTodos,
                interval: todayInterval
            )
        }

        var filteredTodos: [TodayTodoItem] {
            TodayFeature.filteredTodos(
                todos,
                scope: selectedTodoScope,
                categoryID: selectedCategoryID
            )
        }

        var filteredCompletedTodayTodos: [TodayTodoItem] {
            TodayFeature.filteredTodos(
                completedTodayTodos,
                scope: selectedTodoScope,
                categoryID: selectedCategoryID
            )
        }

        var sections: [SectionContent] {
            var collection = TodayFeature.groupedSectionItems(
                from: filteredTodos,
                interval: todayInterval
            )
            collection.today.append(contentsOf: filteredCompletedTodayTodos)

            return
                TodayFeature.makeSection(
                    category: .overdue,
                    title: String(localized: "today_section_overdue", bundle: PresentationResources.bundle),
                    items: collection.overdue
                )
                + TodayFeature.makeSection(
                    category: .today,
                    title: String(localized: "today_section_today", bundle: PresentationResources.bundle),
                    items: collection.today
                )
                + TodayFeature.makeSection(
                    category: .upcoming,
                    title: String(localized: "today_section_upcoming", bundle: PresentationResources.bundle),
                    items: collection.upcoming
                )
                + TodayFeature.makeSection(
                    category: .later,
                    title: String(localized: "today_section_later", bundle: PresentationResources.bundle),
                    items: collection.later
                )
                + TodayFeature.makeSection(
                    category: .unscheduled,
                    title: String(localized: "today_section_unscheduled", bundle: PresentationResources.bundle),
                    items: collection.unscheduled
                )
        }

        var summaryCounts: [TodoScope: Int] {
            let todos = TodayFeature.filteredTodos(
                todos,
                scope: .remaining,
                categoryID: selectedCategoryID
            )
            return [
                .remaining: todos.count,
                .important: todos.filter(\.isPinned).count
            ]
        }
    }

    static func dayInterval(
        containing date: Date,
        calendar: Calendar = .autoupdatingCurrent
    ) -> DateInterval {
        calendar.dateInterval(of: .day, for: date) ?? DateInterval(start: date, duration: 0)
    }

    static func isDue(_ item: TodayTodoItem, in interval: DateInterval) -> Bool {
        guard let dueDate = item.dueDate else { return false }
        return interval.start <= dueDate && dueDate < interval.end
    }

    static func todayTodos(
        incompleteTodos: [TodayTodoItem],
        completedTodos: [TodayTodoItem],
        interval: DateInterval
    ) -> [TodayTodoItem] {
        incompleteTodos.filter { isDue($0, in: interval) }
            + completedTodos.filter { isDue($0, in: interval) }
    }

    static func achievement(
        incompleteTodos: [TodayTodoItem],
        completedTodos: [TodayTodoItem],
        interval: DateInterval
    ) -> TodayAchievement {
        let todos = todayTodos(
            incompleteTodos: incompleteTodos,
            completedTodos: completedTodos,
            interval: interval
        )
        return TodayAchievement(
            completedCount: todos.filter(\.isCompleted).count,
            totalCount: todos.count
        )
    }

    static func filteredTodos(
        _ todos: [TodayTodoItem],
        scope: TodoScope,
        categoryID: String?
    ) -> [TodayTodoItem] {
        todos.filter { item in
            if scope == .important, !item.isPinned { return false }
            if let categoryID, item.category.storageValue != categoryID { return false }
            return true
        }
    }

    static func groupedSectionItems(
        from items: [TodayTodoItem],
        interval: DateInterval,
        calendar: Calendar = .autoupdatingCurrent
    ) -> SectionCollection {
        guard let upcomingEnd = calendar.date(
            byAdding: .day,
            value: upcomingWindowDays,
            to: interval.end
        ) else {
            return SectionCollection(unscheduled: pinnedFirst(items.filter { $0.dueDate == nil }))
        }

        var collection = SectionCollection()

        for item in items {
            guard let dueDate = item.dueDate else {
                collection.unscheduled.append(item)
                continue
            }

            if dueDate < interval.start {
                collection.overdue.append(item)
            } else if dueDate < interval.end {
                collection.today.append(item)
            } else if dueDate < upcomingEnd {
                collection.upcoming.append(item)
            } else {
                collection.later.append(item)
            }
        }

        collection.overdue = pinnedFirst(collection.overdue)
        collection.today = pinnedFirst(collection.today)
        collection.upcoming = pinnedFirst(collection.upcoming)
        collection.later = pinnedFirst(collection.later)
        collection.unscheduled = pinnedFirst(collection.unscheduled)
        return collection
    }

    static func makeSection(
        category: SectionCategory,
        title: String,
        items: [TodayTodoItem]
    ) -> [SectionContent] {
        guard !items.isEmpty else { return [] }
        return [SectionContent(category: category, title: title, items: items)]
    }

    private static func pinnedFirst(_ items: [TodayTodoItem]) -> [TodayTodoItem] {
        items.filter(\.isPinned) + items.filter { !$0.isPinned }
    }
}
