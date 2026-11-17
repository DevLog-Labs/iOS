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
        localizedName(in: PresentationResources.bundle)
    }

    // 앱 언어와 관계없이 지원하는 모든 언어의 표시 이름
    public var localizedNames: [String] {
        let bundle = PresentationResources.bundle
        return bundle.localizations.compactMap { language in
            bundle.path(forResource: language, ofType: "lproj")
                .flatMap(Bundle.init(path:))
                .map(localizedName(in:))
        }
    }

    public func localizedName(in bundle: Bundle) -> String {
        switch systemTodoCategory {
        case .issue: return String(localized: "todo_category_issue", bundle: bundle)
        case .feature: return String(localized: "todo_category_feature", bundle: bundle)
        case .improvement: return String(localized: "todo_category_improvement", bundle: bundle)
        case .review: return String(localized: "todo_category_review", bundle: bundle)
        case .test: return String(localized: "todo_category_test", bundle: bundle)
        case .doc: return String(localized: "todo_category_doc", bundle: bundle)
        case .research: return String(localized: "todo_category_research", bundle: bundle)
        case .etc: return String(localized: "todo_category_etc", bundle: bundle)
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
