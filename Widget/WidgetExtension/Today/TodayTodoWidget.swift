//
//  TodayTodoWidget.swift
//  WidgetExtension
//
//  Created by opfic on 4/15/26.
//

import SwiftUI
import AppIntents
import WidgetKit
import WidgetCore

struct TodayTodoWidget: Widget {
    let kind = WidgetKind.todayTodo

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: TodayTodoWidgetConfigurationIntent.self,
            provider: TodayTodoWidgetProvider()
        ) { entry in
            TodayTodoWidgetEntryView(entry: entry)
                .containerBackground(Color.secondaryBackground, for: .widget)
                .widgetURL(WidgetDeepLink.todayTodoURL)
        }
        .description("widget_today_description")
        .configurationDisplayName(LocalizedStringResource("widget_today_title"))
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}
