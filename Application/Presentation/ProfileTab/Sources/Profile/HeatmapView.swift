//
//  HeatmapView.swift
//  ProfileTab
//
//  Created by 최윤진 on 3/2/26.
//

import SwiftUI
import Core

struct HeatmapView: View {
    @State private var availableWidth = CGFloat.zero
    let quarter: HeatmapQuarter
    let selectedActivityKinds: Set<ActivityKind>
    let selectedDay: HeatmapDay?
    let onSelectDay: (HeatmapDay) -> Void

    var body: some View {
        let layout = HeatmapLayout(
            availableWidth: availableWidth,
            weekCounts: quarter.months.map(\.weeks.count)
        )

        ScrollView(.horizontal) {
            LazyHStack(alignment: .top, spacing: layout.monthSpacing) {
                ForEach(quarter.months) { month in
                    MonthCompactHeatmapView(
                        month: month,
                        maxCount: maxCount,
                        layout: layout,
                        selectedActivityKinds: selectedActivityKinds,
                        selectedDay: selectedDay,
                        onSelectDay: onSelectDay
                    )
                }
            }
            .padding(.vertical, 2)
            .frame(width: layout.contentWidth, alignment: .leading)
            .frame(minWidth: availableWidth)
        }
        .scrollIndicators(.hidden)
        .scrollDisabled(true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            GeometryReader { geometry in
                Color.clear
                    .onAppear { updateAvailableWidth(geometry.size.width) }
                    .onChange(of: geometry.size.width) { updateAvailableWidth($1) }
            }
        }
    }

    private var maxCount: Int {
        quarter.months
            .flatMap(\.weeks)
            .flatMap { $0 }
            .filter(\.isVisible)
            .map(dayCount(for:))
            .max() ?? 0
    }

    private func dayCount(for day: HeatmapDay) -> Int {
        var value = 0
        if selectedActivityKinds.contains(.created) {
            value += day.createdCount
        }
        if selectedActivityKinds.contains(.completed) {
            value += day.completedCount
        }
        if selectedActivityKinds.contains(.deleted) {
            value += day.deletedCount
        }
        return value
    }

    private func updateAvailableWidth(_ width: CGFloat) {
        if availableWidth != width {
            availableWidth = width
        }
    }
}

private struct HeatmapLayout {
    private static let minimumCellSize: CGFloat = 8
    private static let maximumCellSize: CGFloat = 22
    let cellSize: CGFloat
    let cellSpacing: CGFloat = 4
    let monthSpacing: CGFloat = 12
    let monthTitleSpacing: CGFloat = 6
    let contentWidth: CGFloat

    init(availableWidth: CGFloat, weekCounts: [Int]) {
        let totalColumns = max(weekCounts.reduce(0, +), 1)
        let totalColumnSpacings = weekCounts.reduce(0) { partialResult, count in
            partialResult + max(count - 1, 0)
        }
        let fixedWidth = monthSpacing * CGFloat(max(weekCounts.count - 1, 0))
            + cellSpacing * CGFloat(totalColumnSpacings)
        let fittingCellSize = max(0, availableWidth - fixedWidth) / CGFloat(totalColumns)
        cellSize = min(max(fittingCellSize, Self.minimumCellSize), Self.maximumCellSize)
        contentWidth = cellSize * CGFloat(totalColumns) + fixedWidth
    }

    var cellCornerRadius: CGFloat {
        max(2, cellSize * 0.2)
    }

    var innerSelectionLineWidth: CGFloat {
        max(1.2, cellSize * 0.12)
    }
}

private struct MonthCompactHeatmapView: View {
    @Environment(\.colorScheme) private var colorScheme
    let month: HeatmapMonth
    let maxCount: Int
    let layout: HeatmapLayout
    let selectedActivityKinds: Set<ActivityKind>
    let selectedDay: HeatmapDay?
    let onSelectDay: (HeatmapDay) -> Void
    private let orderedWeekdays = Array(1...7)

    var body: some View {
        VStack(alignment: .leading, spacing: layout.monthTitleSpacing) {
            Text(month.monthStart.formatted(.dateTime.month(.abbreviated)))
                .frame(height: layout.cellSize)
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: layout.cellSpacing) {
                ForEach(orderedWeekdays, id: \.self) { weekday in
                    HStack(spacing: layout.cellSpacing) {
                        ForEach(month.weeks.indices, id: \.self) { weekIndex in
                            let day = month.weeks[weekIndex].first {
                                Calendar.current.component(.weekday, from: $0.date) == weekday
                            }

                            RoundedRectangle(cornerRadius: layout.cellCornerRadius)
                                .fill(fillColor(for: day, with: maxCount))
                                .stroke(
                                    selectionInnerBorderColor(for: day),
                                    lineWidth: layout.innerSelectionLineWidth
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: layout.cellCornerRadius + 1)
                                        .stroke(selectionOuterBorderColor(for: day), lineWidth: 0.8)
                                        .padding(-1)
                                )
                                .frame(width: layout.cellSize, height: layout.cellSize)
                                .onTapGesture {
                                    if let day, day.isVisible {
                                        onSelectDay(day)
                                    }
                                }
                        }
                    }
                }
            }
        }
    }

    private func isSelected(_ day: HeatmapDay?) -> Bool {
        guard let day, let selectedDay, day.isVisible else { return false }
        return Calendar.current.isDate(day.date, inSameDayAs: selectedDay.date)
    }

    private func selectionInnerBorderColor(for day: HeatmapDay?) -> Color {
        isSelected(day) ? .white : .clear
    }

    private func selectionOuterBorderColor(for day: HeatmapDay?) -> Color {
        if isSelected(day) && colorScheme == .light {
            return Color.gray
        }
        return .clear
    }

    private func fillColor(for day: HeatmapDay?, with maxCount: Int) -> Color {
        guard let day, day.isVisible else { return .clear }
        let count = dayCount(for: day)
        if count == 0 {
            return Color(.systemGray5)
        }
        return Color.accent.opacity(opacity(for: count, max: maxCount))
    }

    private func dayCount(for day: HeatmapDay) -> Int {
        var value = 0
        if selectedActivityKinds.contains(.created) {
            value += day.createdCount
        }
        if selectedActivityKinds.contains(.completed) {
            value += day.completedCount
        }
        if selectedActivityKinds.contains(.deleted) {
            value += day.deletedCount
        }
        return value
    }

    private func opacity(for count: Int, max: Int) -> Double {
        guard 0 < count && 0 < max else { return 0 }
        let ratio = Double(count) / Double(max)
        return ceil(ratio * 10) / 10
    }
}
