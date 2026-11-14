//
//  SystemTodoCategoryItem.swift
//  PresentationShared
//
//  Created by opfic on 3/30/26.
//

import SwiftUI
import Domain

public struct SystemTodoCategoryItem: Identifiable, Hashable {
    public let systemTodoCategory: SystemTodoCategory

    public init(from systemTodoCategory: SystemTodoCategory) {
        self.systemTodoCategory = systemTodoCategory
    }

    public var id: String { systemTodoCategory.rawValue }

    public var symbolName: String {
        switch systemTodoCategory {
        case .issue: return "exclamationmark.triangle"
        case .feature: return "sparkles"
        case .improvement: return "arrow.triangle.2.circlepath"
        case .review: return "eye"
        case .test: return "checkmark.shield"
        case .doc: return "doc.text"
        case .research: return "magnifyingglass"
        case .etc: return "ellipsis"
        }
    }

    public var localizedName: String {
        switch systemTodoCategory {
        case .issue: return String(localized: "todo_category_issue", bundle: PresentationResources.bundle)
        case .feature: return String(localized: "todo_category_feature", bundle: PresentationResources.bundle)
        case .improvement: return String(localized: "todo_category_improvement", bundle: PresentationResources.bundle)
        case .review: return String(localized: "todo_category_review", bundle: PresentationResources.bundle)
        case .test: return String(localized: "todo_category_test", bundle: PresentationResources.bundle)
        case .doc: return String(localized: "todo_category_doc", bundle: PresentationResources.bundle)
        case .research: return String(localized: "todo_category_research", bundle: PresentationResources.bundle)
        case .etc: return String(localized: "todo_category_etc", bundle: PresentationResources.bundle)
        }
    }

    public var color: Color {
        switch systemTodoCategory {
        case .issue: return .danger
        case .feature: return .categoryFeature
        case .improvement: return .categoryImprovement
        case .review: return .categoryReview
        case .test: return .categoryTest
        case .doc: return .categoryDoc
        case .research: return .categoryResearch
        case .etc: return .categoryEtc
        }
    }
}
