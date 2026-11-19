//
//  HeatmapView.swift
//  ProfileTab
//
//  Created by 최윤진 on 3/2/26.
//

import SwiftUI
import Core
import PresentationShared

struct HeatmapView: View {
    let quarter: HeatmapQuarter
    let selectedActivityKinds: Set<ActivityKind>
    let selectedDay: HeatmapDay?
    let onSelectDay: (HeatmapDay) -> Void

    var body: some View {
        let layout = HeatmapLayout()

        HStack(alignment: .top, spacing: layout.monthSpacing) {
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
        .frame(maxWidth: .infinity, alignment: .leading)
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
}

// 보드 크기 그대로 둔 잔디 칸
private struct HeatmapLayout {
    let cellSize = 11 * AdaptiveSize.boardScale
    let cellSpacing = 3 * AdaptiveSize.boardScale
    let monthSpacing = 12 * AdaptiveSize.boardScale
    let monthTitleSpacing = 4 * AdaptiveSize.boardScale
    let cellCornerRadius = 2 * AdaptiveSize.boardScale

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
                .font(.adaptive(.caption))
                .foregroundStyle(Color.secondaryLabel)

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
        if isSelected(day) {
            return .white
        }
        guard let day, day.isVisible else { return .clear }
        // 칸의 옅은 테두리
        return Calendar.current.startOfDay(for: .now) < day.date ? .heatmapFutureBorder : .heatmapBorder
    }

    private func selectionOuterBorderColor(for day: HeatmapDay?) -> Color {
        if isSelected(day) && colorScheme == .light {
            return Color.gray
        }
        return .clear
    }

    private func fillColor(for day: HeatmapDay?, with maxCount: Int) -> Color {
        guard let day, day.isVisible else { return .clear }
        // 오늘 이후 칸은 별도 색
        if Calendar.current.startOfDay(for: .now) < day.date {
            return .heatmapFuture
        }
        let count = dayCount(for: day)
        // 빈 칸과 3단계 색
        let colors = [Color.heatmapEmpty, .heatmapLevel1, .heatmapLevel2, .accent]
        return colors[count == 0 ? 0 : (count * 3 + maxCount - 1) / maxCount]
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
}
