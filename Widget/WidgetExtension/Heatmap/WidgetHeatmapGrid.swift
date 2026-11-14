//
//  WidgetHeatmapGrid.swift
//  WidgetExtension
//
//  Created by opfic on 4/28/26.
//

import SwiftUI
import WidgetCore

struct WidgetHeatmapGrid: View {
    let months: [WidgetHeatmapMonthSnapshot]
    let selectedActivityKindRawValues: [String]
    let maxCount: Int
    let showsMonthTitles: Bool

    var body: some View {
        GeometryReader { proxy in
            let layout = WidgetHeatmapLayout(
                availableWidth: proxy.size.width,
                availableHeight: proxy.size.height,
                weekCounts: months.map(\.weeks.count),
                showsMonthTitles: showsMonthTitles
            )

            HStack(alignment: .top, spacing: layout.monthSpacing) {
                ForEach(months, id: \.monthStart) { month in
                    WidgetHeatmapMonthGrid(
                        month: month,
                        layout: layout,
                        selectedActivityKindRawValues: selectedActivityKindRawValues,
                        maxCount: maxCount,
                        showsMonthTitle: showsMonthTitles
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

struct WidgetHeatmapPlaceholderGrid: View {
    let months: [WidgetHeatmapPlaceholderMonthShape]
    let showsMonthTitles: Bool

    var body: some View {
        let weekCounts = months.map(\.weeks.count)

        GeometryReader { proxy in
            let layout = WidgetHeatmapLayout(
                availableWidth: proxy.size.width,
                availableHeight: proxy.size.height,
                weekCounts: weekCounts,
                showsMonthTitles: showsMonthTitles
            )

            HStack(alignment: .top, spacing: layout.monthSpacing) {
                ForEach(months) { month in
                    WidgetHeatmapPlaceholderMonthGrid(
                        month: month,
                        layout: layout,
                        showsMonthTitle: showsMonthTitles
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

private struct WidgetHeatmapMonthGrid: View {
    let month: WidgetHeatmapMonthSnapshot
    let layout: WidgetHeatmapLayout
    let selectedActivityKindRawValues: [String]
    let maxCount: Int
    let showsMonthTitle: Bool
    private let orderedWeekdays = Array(1...7)

    var body: some View {
        VStack(alignment: .leading, spacing: layout.monthTitleSpacing) {
            if showsMonthTitle {
                Text(month.monthStart.formatted(.dateTime.month(.abbreviated)))
                    .frame(height: layout.cellSize)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: layout.cellSpacing) {
                ForEach(orderedWeekdays, id: \.self) { weekday in
                    HStack(spacing: layout.cellSpacing) {
                        ForEach(month.weeks, id: \.id) { week in
                            let day = week.days.first {
                                Calendar.current.component(.weekday, from: $0.date) == weekday
                            }

                            RoundedRectangle(cornerRadius: layout.cellCornerRadius)
                                .fill(fillColor(for: day))
                                .frame(width: layout.cellSize, height: layout.cellSize)
                        }
                    }
                }
            }
        }
    }

    private func fillColor(for day: WidgetHeatmapDaySnapshot?) -> Color {
        guard let day, day.isVisible else { return .clear }

        let count = dayCount(for: day)
        if count == 0 {
            return Color.tertiaryBackground
        }

        return Color.accent.opacity(opacity(for: count, max: maxCount))
    }

    private func dayCount(for day: WidgetHeatmapDaySnapshot) -> Int {
        let selectedActivityKindRawValues = Set(selectedActivityKindRawValues)
        var value = 0

        if selectedActivityKindRawValues.contains(WidgetHeatmapActivityKind.created.rawValue) {
            value += day.createdCount
        }

        if selectedActivityKindRawValues.contains(WidgetHeatmapActivityKind.completed.rawValue) {
            value += day.completedCount
        }

        if selectedActivityKindRawValues.contains(WidgetHeatmapActivityKind.deleted.rawValue) {
            value += day.deletedCount
        }

        return value
    }

    private func opacity(for count: Int, max: Int) -> Double {
        guard 0 < count && 0 < max else { return 0 }
        let ratio = Double(count) / Double(max)
        let level = min(Int(ceil(ratio * 4)), 4)
        return 0.2 + 0.2 * Double(level)
    }
}

private enum WidgetHeatmapActivityKind: String {
    case created
    case completed
    case deleted
}

private struct WidgetHeatmapPlaceholderMonthGrid: View {
    let month: WidgetHeatmapPlaceholderMonthShape
    let layout: WidgetHeatmapLayout
    let showsMonthTitle: Bool
    private let orderedWeekdays = Array(1...7)

    var body: some View {
        VStack(alignment: .leading, spacing: layout.monthTitleSpacing) {
            if showsMonthTitle {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.secondary.opacity(0.18))
                    .frame(width: layout.cellSize * 3, height: 8)
                    .frame(height: layout.cellSize, alignment: .leading)
            }

            VStack(alignment: .leading, spacing: layout.cellSpacing) {
                ForEach(orderedWeekdays, id: \.self) { weekday in
                    HStack(spacing: layout.cellSpacing) {
                        ForEach(month.weeks) { week in
                            let day = week.days.first {
                                Calendar.current.component(.weekday, from: $0.date) == weekday
                            }

                            RoundedRectangle(cornerRadius: layout.cellCornerRadius)
                                .fill(fillColor(for: day))
                                .frame(width: layout.cellSize, height: layout.cellSize)
                        }
                    }
                }
            }
        }
    }

    private func fillColor(for day: WidgetHeatmapPlaceholderDayShape?) -> Color {
        guard let day, day.isVisible else { return .clear }
        return Color.secondary.opacity(opacity(for: day))
    }

    private func opacity(for day: WidgetHeatmapPlaceholderDayShape) -> Double {
        switch Calendar.current.component(.day, from: day.date) % 4 {
        case 0:
            return 1 / 8
        case 1:
            return 1 / 5
        case 2:
            return 1 / 4
        default:
            return 3 / 20
        }
    }
}
