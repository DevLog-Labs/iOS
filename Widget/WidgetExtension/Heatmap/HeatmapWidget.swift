//
//  HeatmapWidget.swift
//  WidgetExtension
//
//  Created by opfic on 4/15/26.
//

import SwiftUI
import AppIntents
import WidgetKit
import WidgetCore

struct HeatmapWidget: Widget {
    let kind = WidgetKind.heatmap

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: HeatmapWidgetConfigurationIntent.self,
            provider: HeatmapWidgetProvider()
        ) { entry in
            HeatmapWidgetEntryView(entry: entry)
                .containerBackground(Color.secondaryBackground, for: .widget)
                .widgetURL(WidgetDeepLink.heatmapURL)
        }
        .configurationDisplayName(LocalizedStringResource("widget_heatmap_title"))
        .description("widget_heatmap_description")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
